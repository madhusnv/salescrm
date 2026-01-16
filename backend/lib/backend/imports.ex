defmodule Backend.Imports do
  import Ecto.Query, warn: false

  alias Backend.Assignments
  alias Backend.Imports.{CsvParser, ImportJob, ImportJobWorker, ImportRow}
  alias Backend.Leads
  alias Backend.Leads.LeadDedupeCandidate
  alias Backend.Repo

  def list_import_jobs(organization_id, filters \\ %{}, page \\ 1, page_size \\ 20) do
    offset = max(page - 1, 0) * page_size

    ImportJob
    |> where([j], j.organization_id == ^organization_id)
    |> apply_job_filters(filters)
    |> order_by([j], desc: j.inserted_at)
    |> limit(^page_size)
    |> offset(^offset)
    |> preload([:university, :created_by_user])
    |> Repo.all()
  end

  def count_import_jobs(organization_id, filters \\ %{}) do
    ImportJob
    |> where([j], j.organization_id == ^organization_id)
    |> apply_job_filters(filters)
    |> Repo.aggregate(:count, :id)
  end

  def get_import_job!(id) do
    ImportJob
    |> preload([:university, :created_by_user])
    |> Repo.get!(id)
  end

  def list_invalid_rows(import_job_id, limit \\ 50) do
    ImportRow
    |> where([r], r.import_job_id == ^import_job_id and r.status == :invalid)
    |> order_by([r], asc: r.row_number)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_assignment_failures(import_job_id, limit \\ 50) do
    ImportRow
    |> where([r], r.import_job_id == ^import_job_id and r.assignment_status == "failed")
    |> order_by([r], asc: r.row_number)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_unassigned_rows(import_job_id, limit \\ 50) do
    ImportRow
    |> where([r], r.import_job_id == ^import_job_id and r.status == :valid)
    |> where([r], r.dedupe_status in ["none", "soft"])
    |> where([r], r.assignment_status in ["pending", "failed"])
    |> order_by([r], asc: r.row_number)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_unassigned_rows(import_job_id) do
    ImportRow
    |> where([r], r.import_job_id == ^import_job_id and r.status == :valid)
    |> where([r], r.dedupe_status in ["none", "soft"])
    |> where([r], r.assignment_status in ["pending", "failed"])
    |> Repo.aggregate(:count, :id)
  end

  def create_import_job(attrs) do
    %ImportJob{}
    |> ImportJob.changeset(attrs)
    |> Repo.insert()
  end

  def enqueue_leads_import(attrs, csv_content) when is_binary(csv_content) do
    Repo.transaction(fn ->
      with {:ok, job} <- create_import_job(attrs),
           {:ok, _oban_job} <-
             Oban.insert(
               ImportJobWorker.new(%{"import_job_id" => job.id, "csv_content" => csv_content})
             ) do
        job
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def process_job(%ImportJob{} = job, csv_content) do
    Repo.transaction(fn ->
      job =
        job
        |> ImportJob.changeset(%{status: :processing, started_at: DateTime.utc_now(:second)})
        |> Repo.update!()

      case CsvParser.parse_leads_csv(csv_content) do
        {:ok, parsed_rows} ->
          {row_attrs, summary} = build_rows(job, parsed_rows)
          inserted_count = insert_rows(row_attrs)
          {dedupe_hard, dedupe_soft} = apply_dedupe(job)
          {assignment_failures, assignment_errors} = assign_rows(job)
          leads_created = create_leads_for_job(job)
          dedupe_candidates = create_dedupe_candidates(job)

          update_job(job, %{
            status: :completed,
            total_rows: summary.total_rows,
            valid_rows: summary.valid_rows,
            invalid_rows: summary.invalid_rows,
            inserted_rows: inserted_count,
            error_summary:
              summary.error_summary
              |> Map.put("assignment_failures", assignment_failures)
              |> Map.put("assignment_errors", assignment_errors)
              |> Map.put("leads_created", leads_created)
              |> Map.put("dedupe_hard", dedupe_hard)
              |> Map.put("dedupe_soft", dedupe_soft)
              |> Map.put("dedupe_candidates", dedupe_candidates),
            completed_at: DateTime.utc_now(:second)
          })

        {:error, reason} ->
          update_job(job, %{
            status: :failed,
            error_summary: %{error: inspect(reason)},
            completed_at: DateTime.utc_now(:second)
          })
      end
    end)
  end

  defp build_rows(job, parsed_rows) do
    rows =
      Enum.map(parsed_rows, fn {row_number, row_map} ->
        {status, errors, normalized_phone} = validate_row(row_map)
        normalized_name = Leads.normalize_name(row_map["student_name"])

        %{
          import_job_id: job.id,
          row_number: row_number,
          student_name: row_map["student_name"],
          phone_number: row_map["phone_number"],
          normalized_phone_number: normalized_phone,
          normalized_student_name: normalized_name,
          status: status,
          errors: errors,
          raw_data: row_map,
          inserted_at: DateTime.utc_now(:second),
          updated_at: DateTime.utc_now(:second)
        }
      end)

    summary = %{
      total_rows: length(rows),
      valid_rows: Enum.count(rows, &(&1.status == :valid)),
      invalid_rows: Enum.count(rows, &(&1.status == :invalid)),
      error_summary: summarize_errors(rows)
    }

    {rows, summary}
  end

  defp insert_rows([]), do: 0

  defp insert_rows(rows) do
    {_count, _} = Repo.insert_all(ImportRow, rows)
    length(rows)
  end

  defp update_job(job, attrs) do
    job
    |> ImportJob.changeset(attrs)
    |> Repo.update()
  end

  defp validate_row(row_map) do
    student_name = row_map["student_name"] |> to_string() |> String.trim()
    phone_number = row_map["phone_number"] |> to_string() |> String.trim()

    {normalized_phone, phone_errors} = normalize_phone(phone_number)

    errors =
      %{}
      |> put_error(is_blank(student_name), "student_name", "required")
      |> put_error(is_blank(phone_number), "phone_number", "required")
      |> Map.merge(phone_errors)

    status = if map_size(errors) == 0, do: :valid, else: :invalid

    {status, errors, normalized_phone}
  end

  defp normalize_phone(phone_number) do
    normalized = Leads.normalize_phone(phone_number)

    cond do
      normalized == "" -> {nil, %{"phone_number" => "required"}}
      byte_size(normalized) != 10 -> {normalized, %{"phone_number" => "invalid_length"}}
      true -> {normalized, %{}}
    end
  end

  defp is_blank(value), do: value == nil or String.trim(to_string(value)) == ""

  defp put_error(errors, true, key, message), do: Map.put(errors, key, message)
  defp put_error(errors, false, _key, _message), do: errors

  defp summarize_errors(rows) do
    rows
    |> Enum.flat_map(fn row -> Map.values(row.errors || %{}) end)
    |> Enum.frequencies()
  end

  defp assign_rows(job) do
    rows =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.status == :valid)
      |> where([r], r.dedupe_status in ["none", "soft"])
      |> order_by([r], asc: r.row_number)
      |> Repo.all()

    Enum.reduce(rows, {0, %{}}, fn row, {failures, error_counts} ->
      case Assignments.pick_counselor(job.organization_id, job.branch_id, job.university_id) do
        {:ok, counselor_id} ->
          Repo.update_all(
            from(r in ImportRow, where: r.id == ^row.id),
            set: [
              assigned_counselor_id: counselor_id,
              assignment_status: "assigned",
              assignment_error: nil
            ]
          )

          {failures, error_counts}

        {:error, reason} ->
          reason_text = to_string(reason)

          Repo.update_all(
            from(r in ImportRow, where: r.id == ^row.id),
            set: [
              assignment_status: "failed",
              assignment_error: %{error: reason_text}
            ]
          )

          {failures + 1, Map.update(error_counts, reason_text, 1, &(&1 + 1))}
      end
    end)
  end

  defp create_leads_for_job(job) do
    rows =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.assignment_status == "assigned")
      |> where([r], r.dedupe_status in ["none", "soft"])
      |> where([r], is_nil(r.lead_id))
      |> order_by([r], asc: r.row_number)
      |> Repo.all()

    Enum.reduce(rows, 0, fn row, count ->
      Leads.create_from_import_row(job, row)
      count + 1
    end)
  end

  def assign_rows_to_counselor(%ImportJob{} = job, counselor_id) do
    rows =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.status == :valid)
      |> where([r], r.dedupe_status in ["none", "soft"])
      |> where([r], r.assignment_status in ["pending", "failed"])
      |> order_by([r], asc: r.row_number)
      |> Repo.all()

    Repo.transaction(fn ->
      Enum.reduce(rows, 0, fn row, count ->
        Repo.update_all(
          from(r in ImportRow, where: r.id == ^row.id),
          set: [
            assigned_counselor_id: counselor_id,
            assignment_status: "assigned",
            assignment_error: nil
          ]
        )

        _lead =
          Leads.create_from_import_row(job, %{
            row
            | assigned_counselor_id: counselor_id
          })

        count + 1
      end)
    end)
  end

  defp apply_dedupe(job) do
    rows =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.status == :valid)
      |> order_by([r], asc: r.row_number)
      |> Repo.all()

    Enum.reduce(rows, {0, 0}, fn row, {hard_count, soft_count} ->
      match =
        find_existing_lead(
          job.organization_id,
          row.normalized_phone_number,
          row.normalized_student_name
        )

      case match do
        {:hard, lead_id} ->
          Repo.update_all(
            from(r in ImportRow, where: r.id == ^row.id),
            set: [
              dedupe_status: "hard",
              dedupe_reason: "phone_name_match",
              dedupe_matched_lead_id: lead_id,
              assignment_status: "skipped",
              assignment_error: %{error: "duplicate_lead"}
            ]
          )

          {hard_count + 1, soft_count}

        {:soft, lead_id} ->
          Repo.update_all(
            from(r in ImportRow, where: r.id == ^row.id),
            set: [
              dedupe_status: "soft",
              dedupe_reason: "phone_match",
              dedupe_matched_lead_id: lead_id
            ]
          )

          {hard_count, soft_count + 1}

        :none ->
          {hard_count, soft_count}
      end
    end)
  end

  defp find_existing_lead(organization_id, normalized_phone, normalized_name)
       when is_binary(normalized_phone) and normalized_phone != "" do
    base_query =
      from(l in Backend.Leads.Lead,
        where:
          l.organization_id == ^organization_id and
            l.normalized_phone_number == ^normalized_phone and
            is_nil(l.merged_into_lead_id)
      )

    case normalized_name do
      name when is_binary(name) and name != "" ->
        hard_match =
          base_query
          |> where([l], l.normalized_student_name == ^name)
          |> select([l], l.id)
          |> limit(1)
          |> Repo.one()

        if hard_match do
          {:hard, hard_match}
        else
          soft_match =
            base_query
            |> select([l], l.id)
            |> limit(1)
            |> Repo.one()

          if soft_match, do: {:soft, soft_match}, else: :none
        end

      _ ->
        soft_match =
          base_query
          |> select([l], l.id)
          |> limit(1)
          |> Repo.one()

        if soft_match, do: {:soft, soft_match}, else: :none
    end
  end

  defp find_existing_lead(_organization_id, _normalized_phone, _normalized_name), do: :none

  defp create_dedupe_candidates(job) do
    rows =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.dedupe_status == "soft")
      |> where([r], not is_nil(r.lead_id) and not is_nil(r.dedupe_matched_lead_id))
      |> Repo.all()

    entries =
      Enum.map(rows, fn row ->
        %{
          lead_id: row.lead_id,
          matched_lead_id: row.dedupe_matched_lead_id,
          import_row_id: row.id,
          match_type: "soft",
          status: "pending",
          inserted_at: DateTime.utc_now(:second),
          updated_at: DateTime.utc_now(:second)
        }
      end)

    case entries do
      [] ->
        0

      _ ->
        {count, _} =
          Repo.insert_all(LeadDedupeCandidate, entries,
            on_conflict: :nothing,
            conflict_target: [:lead_id, :matched_lead_id]
          )

        count
    end
  end

  defp apply_job_filters(query, filters) do
    query
    |> maybe_filter_status(filters)
    |> maybe_filter_date(filters)
    |> maybe_filter_search(filters)
  end

  defp maybe_filter_status(query, %{"status" => status}) do
    status_map = %{
      "pending" => :pending,
      "processing" => :processing,
      "completed" => :completed,
      "failed" => :failed
    }

    case Map.fetch(status_map, status) do
      {:ok, status_atom} -> where(query, [j], j.status == ^status_atom)
      :error -> query
    end
  end

  defp maybe_filter_status(query, %{status: status}) do
    maybe_filter_status(query, %{"status" => to_string(status)})
  end

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_date(query, filters) do
    query
    |> maybe_from_date(filters)
    |> maybe_to_date(filters)
  end

  defp maybe_from_date(query, %{"from" => from}) do
    case parse_date(from) do
      {:ok, date} ->
        from_dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        where(query, [j], j.inserted_at >= ^from_dt)

      :error ->
        query
    end
  end

  defp maybe_from_date(query, _), do: query

  defp maybe_to_date(query, %{"to" => to}) do
    case parse_date(to) do
      {:ok, date} ->
        to_dt = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
        where(query, [j], j.inserted_at <= ^to_dt)

      :error ->
        query
    end
  end

  defp maybe_to_date(query, _), do: query

  defp maybe_filter_search(query, %{"search" => search}) when is_binary(search) do
    trimmed = String.trim(search)

    if trimmed == "" do
      query
    else
      like = "%#{trimmed}%"

      query
      |> join(:left, [j], u in assoc(j, :university))
      |> where([j, u], ilike(j.original_filename, ^like) or ilike(u.name, ^like))
    end
  end

  defp maybe_filter_search(query, _), do: query

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end
end
