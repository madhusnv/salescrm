defmodule Backend.Imports do
  import Ecto.Query, warn: false

  alias Backend.Assignments
  alias Backend.Imports.{CsvParser, ImportJob, ImportJobWorker, ImportRow}
  alias Backend.Leads
  alias Backend.Leads.{Lead, LeadDedupeCandidate}
  alias Backend.Repo

  @batch_size 500

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
          inserted_at: NaiveDateTime.utc_now(:second),
          updated_at: NaiveDateTime.utc_now(:second)
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
    base_query =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.status == :valid)
      |> where([r], r.dedupe_status in ["none", "soft"])

    rules =
      Assignments.list_assignment_candidates(
        job.organization_id,
        job.branch_id,
        job.university_id
      )

    if rules == [] do
      {count, _} =
        Repo.update_all(
          base_query,
          set: [
            assignment_status: "failed",
            assignment_error: %{error: "no_assignment_rules"}
          ]
        )

      {count, %{"no_assignment_rules" => count}}
    else
      acc = %{rules: rules, failures: 0, errors: %{}}

      acc =
        reduce_in_batches(
          base_query |> select([r], %{id: r.id}),
          @batch_size,
          acc,
          fn rows, acc -> assign_rows_batch(rows, acc) end
        )

      {acc.failures, acc.errors}
    end
  end

  defp create_leads_for_job(job) do
    base_query =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.assignment_status == "assigned")
      |> where([r], r.dedupe_status in ["none", "soft"])
      |> where([r], is_nil(r.lead_id))

    reduce_in_batches(base_query, @batch_size, 0, fn rows, count ->
      Enum.reduce(rows, count, fn row, acc ->
        Leads.create_from_import_row(job, row)
        acc + 1
      end)
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
    base_query =
      ImportRow
      |> where([r], r.import_job_id == ^job.id and r.status == :valid)
      |> select([r], %{
        id: r.id,
        normalized_phone_number: r.normalized_phone_number,
        normalized_student_name: r.normalized_student_name
      })

    reduce_in_batches(base_query, @batch_size, {0, 0}, fn rows, {hard_total, soft_total} ->
      phones =
        rows
        |> Enum.map(& &1.normalized_phone_number)
        |> Enum.filter(&is_binary/1)
        |> Enum.uniq()

      leads_by_phone = fetch_existing_leads_by_phone(job.organization_id, phones)

      {hard_updates, soft_updates} =
        Enum.reduce(rows, {%{}, %{}}, fn row, {hard, soft} ->
          case dedupe_match(row, leads_by_phone) do
            {:hard, lead_id} ->
              {Map.update(hard, lead_id, [row.id], &[row.id | &1]), soft}

            {:soft, lead_id} ->
              {hard, Map.update(soft, lead_id, [row.id], &[row.id | &1])}

            :none ->
              {hard, soft}
          end
        end)

      hard_added = apply_dedupe_updates(hard_updates, :hard)
      soft_added = apply_dedupe_updates(soft_updates, :soft)

      {hard_total + hard_added, soft_total + soft_added}
    end)
  end

  defp dedupe_match(row, leads_by_phone) do
    case Map.get(leads_by_phone, row.normalized_phone_number, []) do
      [] ->
        :none

      leads ->
        name = row.normalized_student_name

        if is_binary(name) and name != "" do
          case Enum.find(leads, &(&1.normalized_student_name == name)) do
            %{id: lead_id} -> {:hard, lead_id}
            nil -> {:soft, hd(leads).id}
          end
        else
          {:soft, hd(leads).id}
        end
    end
  end

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
          inserted_at: NaiveDateTime.utc_now(:second),
          updated_at: NaiveDateTime.utc_now(:second)
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

  defp fetch_existing_leads_by_phone(_organization_id, []), do: %{}

  defp fetch_existing_leads_by_phone(organization_id, phones) do
    phones =
      phones
      |> Enum.reject(&(&1 == "" or is_nil(&1)))
      |> Enum.uniq()

    phones
    |> Enum.chunk_every(500)
    |> Enum.flat_map(fn chunk ->
      Repo.all(
        from(l in Lead,
          where:
            l.organization_id == ^organization_id and
              l.normalized_phone_number in ^chunk and
              is_nil(l.merged_into_lead_id),
          order_by: [desc: l.last_activity_at, desc: l.id],
          select: {l.normalized_phone_number, l.id, l.normalized_student_name}
        )
      )
    end)
    |> Enum.group_by(
      fn {phone, _id, _name} -> phone end,
      fn {_phone, id, name} -> %{id: id, normalized_student_name: name} end
    )
  end

  defp apply_dedupe_updates(updates, :hard) do
    Enum.reduce(updates, 0, fn {lead_id, row_ids}, acc ->
      {count, _} =
        Repo.update_all(
          from(r in ImportRow, where: r.id in ^row_ids),
          set: [
            dedupe_status: "hard",
            dedupe_reason: "phone_name_match",
            dedupe_matched_lead_id: lead_id,
            assignment_status: "skipped",
            assignment_error: %{error: "duplicate_lead"}
          ]
        )

      acc + count
    end)
  end

  defp apply_dedupe_updates(updates, :soft) do
    Enum.reduce(updates, 0, fn {lead_id, row_ids}, acc ->
      {count, _} =
        Repo.update_all(
          from(r in ImportRow, where: r.id in ^row_ids),
          set: [
            dedupe_status: "soft",
            dedupe_reason: "phone_match",
            dedupe_matched_lead_id: lead_id
          ]
        )

      acc + count
    end)
  end

  defp assign_rows_batch(rows, %{rules: rules, failures: failures, errors: errors} = acc) do
    {rules, success_updates, failure_updates, changed_rules} =
      Enum.reduce(rows, {rules, %{}, %{}, %{}}, fn row, {rules, success, failures_map, changed} ->
        case Assignments.pick_counselor_cached(rules) do
          {:ok, rule, updated_rules} ->
            success = Map.update(success, rule.counselor_id, [row.id], &[row.id | &1])
            changed = Map.put(changed, rule.id, rule)
            {updated_rules, success, failures_map, changed}

          {:error, reason, updated_rules} ->
            reason_text = to_string(reason)
            failures_map = Map.update(failures_map, reason_text, [row.id], &[row.id | &1])
            {updated_rules, success, failures_map, changed}
        end
      end)

    _assigned = apply_assignment_success(success_updates)
    {failed_count, failure_errors} = apply_assignment_failures(failure_updates)

    Enum.each(changed_rules, fn {_id, rule} ->
      Assignments.update_rule_counters!(rule)
    end)

    %{
      acc
      | rules: rules,
        failures: failures + failed_count,
        errors: merge_error_counts(errors, failure_errors)
    }
  end

  defp apply_assignment_success(assignments) do
    Enum.reduce(assignments, 0, fn {counselor_id, row_ids}, acc ->
      {count, _} =
        Repo.update_all(
          from(r in ImportRow, where: r.id in ^row_ids),
          set: [
            assigned_counselor_id: counselor_id,
            assignment_status: "assigned",
            assignment_error: nil
          ]
        )

      acc + count
    end)
  end

  defp apply_assignment_failures(failures) do
    Enum.reduce(failures, {0, %{}}, fn {reason, row_ids}, {count, errors} ->
      {updated, _} =
        Repo.update_all(
          from(r in ImportRow, where: r.id in ^row_ids),
          set: [
            assignment_status: "failed",
            assignment_error: %{error: reason}
          ]
        )

      {count + updated, Map.update(errors, reason, updated, &(&1 + updated))}
    end)
  end

  defp merge_error_counts(current, additions) do
    Map.merge(current, additions, fn _key, left, right -> left + right end)
  end

  defp reduce_in_batches(base_query, batch_size, acc, fun) do
    do_reduce_in_batches(base_query, batch_size, 0, acc, fun)
  end

  defp do_reduce_in_batches(base_query, batch_size, last_id, acc, fun) do
    rows =
      base_query
      |> where([r], r.id > ^last_id)
      |> order_by([r], asc: r.id)
      |> limit(^batch_size)
      |> Repo.all()

    case rows do
      [] ->
        acc

      _ ->
        acc = fun.(rows, acc)
        next_last_id = List.last(rows).id
        do_reduce_in_batches(base_query, batch_size, next_last_id, acc, fun)
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
