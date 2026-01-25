defmodule Backend.Leads do
  import Ecto.Query, warn: false

  alias Backend.Accounts.Scope
  alias Backend.Access.Policy
  alias Backend.Analytics
  alias Backend.Imports.ImportRow
  alias Backend.Accounts.User
  alias Backend.Leads.{Lead, LeadActivity, LeadDedupeCandidate, LeadFollowup}
  alias Backend.Repo
  alias BackendWeb.Broadcaster

  @default_page_size 20

  def list_leads(%Scope{} = scope, filters \\ %{}, page \\ 1, page_size \\ @default_page_size) do
    offset = max(page - 1, 0) * page_size

    Lead
    |> scope_query(scope)
    |> apply_filters(filters)
    |> order_by([l], desc: l.last_activity_at, desc: l.id)
    |> limit(^page_size)
    |> offset(^offset)
    |> preload([:assigned_counselor, :university, :branch])
    |> Repo.all()
  end

  def count_leads(%Scope{} = scope, filters \\ %{}) do
    Lead
    |> scope_query(scope)
    |> apply_filters(filters)
    |> Repo.aggregate(:count, :id)
  end

  def get_lead!(%Scope{} = scope, id) do
    Lead
    |> scope_query(scope)
    |> preload([:assigned_counselor, :university, :branch])
    |> Repo.get!(id)
  end

  def change_lead(%Lead{} = lead, attrs \\ %{}) do
    Lead.changeset(lead, attrs)
  end

  def create_lead(%Scope{} = scope, attrs) do
    attrs = normalize_attrs(attrs)
    normalized_phone = normalize_phone(Map.get(attrs, "phone_number"))
    normalized_name = normalize_name(Map.get(attrs, "student_name"))
    now = DateTime.utc_now(:second)

    attrs =
      attrs
      |> Map.put_new("source", "manual")
      |> Map.put("normalized_phone_number", normalized_phone)
      |> Map.put("normalized_student_name", normalized_name)
      |> Map.put_new("last_activity_at", now)

    result =
      %Lead{
        organization_id: scope.user.organization_id,
        branch_id: scope.user.branch_id,
        created_by_user_id: scope.user.id
      }
      |> Lead.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, lead} ->
        _ = Analytics.log_event(scope, "lead_created", %{lead_id: lead.id})
        {:ok, lead}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_lead_status(%Scope{} = scope, %Lead{} = lead, new_status) do
    Repo.transaction(fn ->
      occurred_at = DateTime.utc_now(:second)

      lead =
        lead
        |> Lead.changeset(%{status: new_status, last_activity_at: occurred_at})
        |> Repo.update!()

      activity_attrs = %{
        activity_type: :status_change,
        body: "Status updated to #{format_status(new_status)}",
        metadata: %{status: to_string(new_status)},
        occurred_at: occurred_at
      }

      activity =
        %LeadActivity{lead_id: lead.id, user_id: scope.user.id}
        |> LeadActivity.changeset(activity_attrs)
        |> Repo.insert!()

      {lead, activity}
    end)
    |> case do
      {:ok, {lead, activity}} ->
        _ =
          Analytics.log_event(scope, "lead_status_updated", %{
            lead_id: lead.id,
            status: to_string(lead.status)
          })

        _ = Broadcaster.broadcast_lead_updated(scope.user.id, lead)

        {:ok, {lead, activity}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def add_note(%Scope{} = scope, %Lead{} = lead, body) when is_binary(body) do
    Repo.transaction(fn ->
      occurred_at = DateTime.utc_now(:second)

      activity =
        %LeadActivity{lead_id: lead.id, user_id: scope.user.id}
        |> LeadActivity.changeset(%{
          activity_type: :note,
          body: body,
          occurred_at: occurred_at
        })
        |> Repo.insert!()

      lead =
        lead
        |> Lead.changeset(%{last_activity_at: occurred_at})
        |> Repo.update!()

      {lead, activity}
    end)
    |> case do
      {:ok, {lead, activity}} ->
        _ = Analytics.log_event(scope, "note_added", %{lead_id: lead.id})
        {:ok, {lead, activity}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_activities(%Lead{} = lead) do
    LeadActivity
    |> where([a], a.lead_id == ^lead.id)
    |> order_by([a], desc: a.occurred_at)
    |> preload([:user])
    |> Repo.all()
  end

  def list_followups(%Lead{} = lead) do
    LeadFollowup
    |> where([f], f.lead_id == ^lead.id)
    |> order_by([f], desc: f.due_at)
    |> preload([:user])
    |> Repo.all()
  end

  def list_dedupe_candidates(
        %Scope{} = scope,
        filters \\ %{},
        page \\ 1,
        page_size \\ @default_page_size
      ) do
    offset = max(page - 1, 0) * page_size

    LeadDedupeCandidate
    |> scope_candidate_query(scope)
    |> apply_candidate_filters(filters)
    |> order_by([c], asc: c.status, desc: c.inserted_at)
    |> limit(^page_size)
    |> offset(^offset)
    |> preload([:lead, :matched_lead, :import_row])
    |> Repo.all()
  end

  def count_dedupe_candidates(%Scope{} = scope, filters \\ %{}) do
    LeadDedupeCandidate
    |> scope_candidate_query(scope)
    |> apply_candidate_filters(filters)
    |> Repo.aggregate(:count, :id)
  end

  def get_dedupe_candidate!(%Scope{} = scope, id) do
    LeadDedupeCandidate
    |> scope_candidate_query(scope)
    |> preload([:lead, :matched_lead, :import_row])
    |> Repo.get!(id)
  end

  def merge_candidate(%Scope{} = scope, %LeadDedupeCandidate{} = candidate) do
    Repo.transaction(fn ->
      decided_at = DateTime.utc_now(:second)

      candidate =
        candidate
        |> LeadDedupeCandidate.changeset(%{
          status: :merged,
          decided_at: decided_at
        })
        |> Ecto.Changeset.put_change(:decision_by_user_id, scope.user.id)
        |> Repo.update!()

      lead =
        Lead
        |> Repo.get!(candidate.lead_id)
        |> Lead.changeset(%{
          merged_into_lead_id: candidate.matched_lead_id,
          merged_at: decided_at
        })
        |> Repo.update!()

      {candidate, lead}
    end)
  end

  def ignore_candidate(%Scope{} = scope, %LeadDedupeCandidate{} = candidate) do
    candidate
    |> LeadDedupeCandidate.changeset(%{
      status: :ignored,
      decided_at: DateTime.utc_now(:second)
    })
    |> Ecto.Changeset.put_change(:decision_by_user_id, scope.user.id)
    |> Repo.update()
  end

  def schedule_followup(%Scope{} = scope, %Lead{} = lead, attrs) do
    Repo.transaction(fn ->
      followup =
        %LeadFollowup{lead_id: lead.id, user_id: scope.user.id}
        |> LeadFollowup.changeset(attrs)
        |> Repo.insert!()

      lead =
        lead
        |> Lead.changeset(%{next_follow_up_at: followup.due_at, last_activity_at: followup.due_at})
        |> Repo.update!()

      activity_attrs = %{
        activity_type: :followup_scheduled,
        body: followup.note,
        metadata: %{due_at: followup.due_at},
        occurred_at: DateTime.utc_now(:second)
      }

      activity =
        %LeadActivity{lead_id: lead.id, user_id: scope.user.id}
        |> LeadActivity.changeset(activity_attrs)
        |> Repo.insert!()

      {lead, followup, activity}
    end)
    |> case do
      {:ok, {lead, followup, activity}} ->
        _ =
          Analytics.log_event(scope, "followup_scheduled", %{
            lead_id: lead.id,
            followup_id: followup.id
          })

        {:ok, {lead, followup, activity}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def complete_followup(%Scope{} = scope, %LeadFollowup{} = followup) do
    Repo.transaction(fn ->
      completed_at = DateTime.utc_now(:second)

      followup =
        followup
        |> LeadFollowup.changeset(%{status: :completed, completed_at: completed_at})
        |> Repo.update!()

      next_due_at = next_followup_due_at(followup.lead_id)

      lead =
        Lead
        |> Repo.get!(followup.lead_id)
        |> Lead.changeset(%{next_follow_up_at: next_due_at, last_activity_at: completed_at})
        |> Repo.update!()

      activity_attrs = %{
        activity_type: :followup_completed,
        body: followup.note,
        metadata: %{completed_at: completed_at},
        occurred_at: completed_at
      }

      activity =
        %LeadActivity{lead_id: lead.id, user_id: scope.user.id}
        |> LeadActivity.changeset(activity_attrs)
        |> Repo.insert!()

      {lead, followup, activity}
    end)
  end

  def create_from_import_row(job, %ImportRow{} = row) do
    Repo.transaction(fn ->
      existing =
        Lead
        |> where([l], l.import_row_id == ^row.id)
        |> Repo.one()

      if existing do
        existing
      else
        now = DateTime.utc_now(:second)

        attrs = %{
          student_name: row.student_name,
          phone_number: row.phone_number,
          normalized_phone_number: row.normalized_phone_number,
          normalized_student_name: row.normalized_student_name,
          status: :new,
          source: "import",
          last_activity_at: now
        }

        lead =
          %Lead{
            organization_id: job.organization_id,
            branch_id: job.branch_id,
            university_id: job.university_id,
            assigned_counselor_id: row.assigned_counselor_id,
            created_by_user_id: job.created_by_user_id,
            import_row_id: row.id
          }
          |> Lead.changeset(attrs)
          |> Repo.insert!()

        Repo.update_all(from(r in ImportRow, where: r.id == ^row.id), set: [lead_id: lead.id])
        lead
      end
    end)
  end

  @doc """
  Assigns a lead to a counselor.

  Broadcasts are sent AFTER the transaction commits to prevent phantom updates.
  """
  def assign_lead(%Scope{} = scope, %Lead{} = lead, counselor_id) do
    result =
      Repo.transaction(fn ->
        counselor =
          Repo.one(
            from(u in User,
              where: u.id == ^counselor_id and u.organization_id == ^scope.user.organization_id,
              select: %{id: u.id, full_name: u.full_name}
            )
          )

        if counselor == nil do
          Repo.rollback(:invalid_counselor)
        end

        occurred_at = DateTime.utc_now(:second)

        lead =
          lead
          |> Lead.changeset(%{
            assigned_counselor_id: counselor.id,
            last_activity_at: occurred_at
          })
          |> Repo.update!()

        activity_attrs = %{
          activity_type: :assignment_change,
          body: "Assigned to #{counselor.full_name}",
          metadata: %{counselor_id: counselor.id},
          occurred_at: occurred_at
        }

        _activity =
          %LeadActivity{lead_id: lead.id, user_id: scope.user.id}
          |> LeadActivity.changeset(activity_attrs)
          |> Repo.insert!()

        {lead, counselor_id}
      end)

    case result do
      {:ok, {lead, counselor_id}} ->
        _ = Broadcaster.broadcast_lead_assigned(counselor_id, lead)
        {:ok, lead}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp scope_query(query, %Scope{} = scope) do
    query = where(query, [l], l.organization_id == ^scope.organization_id)

    case Policy.lead_access_level(scope) do
      :organization ->
        query

      :branch ->
        where(query, [l], l.branch_id == ^scope.branch_id)

      :own ->
        where(query, [l], l.assigned_counselor_id == ^scope.user_id)
    end
  end

  defp apply_filters(query, filters) do
    query
    |> maybe_filter_merged(filters)
    |> maybe_filter_status(filters)
    |> maybe_filter_search(filters)
    |> maybe_filter_counselor(filters)
  end

  defp maybe_filter_merged(query, %{"include_merged" => include}) when is_binary(include) do
    include = String.trim(include)

    if include in ["true", "1", "yes"] do
      query
    else
      where(query, [l], is_nil(l.merged_into_lead_id))
    end
  end

  defp maybe_filter_merged(query, _), do: where(query, [l], is_nil(l.merged_into_lead_id))

  defp scope_candidate_query(query, %Scope{} = scope) do
    base =
      from(c in query,
        join: l in Lead,
        on: c.lead_id == l.id
      )

    case Policy.lead_access_level(scope) do
      :organization ->
        from([c, l] in base, where: l.organization_id == ^scope.organization_id)

      :branch ->
        from([c, l] in base,
          where: l.organization_id == ^scope.organization_id and l.branch_id == ^scope.branch_id
        )

      :own ->
        from([c, l] in base,
          where:
            l.organization_id == ^scope.organization_id and
              l.assigned_counselor_id == ^scope.user_id
        )
    end
  end

  defp apply_candidate_filters(query, filters) do
    query
    |> maybe_filter_candidate_status(filters)
    |> maybe_filter_candidate_match_type(filters)
  end

  defp maybe_filter_candidate_status(query, %{"status" => status}) when is_binary(status) do
    status = status |> String.trim() |> String.downcase()

    if status == "" do
      query
    else
      where(query, [c, _l], c.status == ^status)
    end
  end

  defp maybe_filter_candidate_status(query, %{status: status}) do
    maybe_filter_candidate_status(query, %{"status" => to_string(status)})
  end

  defp maybe_filter_candidate_status(query, _), do: query

  defp maybe_filter_candidate_match_type(query, %{"match_type" => match_type})
       when is_binary(match_type) do
    match_type = match_type |> String.trim() |> String.downcase()

    if match_type == "" do
      query
    else
      where(query, [c, _l], c.match_type == ^match_type)
    end
  end

  defp maybe_filter_candidate_match_type(query, %{match_type: match_type}) do
    maybe_filter_candidate_match_type(query, %{"match_type" => to_string(match_type)})
  end

  defp maybe_filter_candidate_match_type(query, _), do: query

  defp maybe_filter_status(query, %{"status" => status}) when is_binary(status) do
    status = status |> String.trim() |> String.downcase()

    if status == "" do
      query
    else
      where(query, [l], l.status == ^status)
    end
  end

  defp maybe_filter_status(query, %{status: status}) do
    maybe_filter_status(query, %{"status" => to_string(status)})
  end

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_search(query, %{"search" => search}) when is_binary(search) do
    search = String.trim(search)

    if search == "" do
      query
    else
      like = "%#{search}%"

      where(
        query,
        [l],
        ilike(l.student_name, ^like) or ilike(l.phone_number, ^like)
      )
    end
  end

  defp maybe_filter_search(query, %{search: search}) do
    maybe_filter_search(query, %{"search" => to_string(search)})
  end

  defp maybe_filter_search(query, _), do: query

  defp maybe_filter_counselor(query, %{"counselor_id" => counselor_id})
       when is_binary(counselor_id) do
    case Integer.parse(counselor_id) do
      {id, _} -> where(query, [l], l.assigned_counselor_id == ^id)
      :error -> query
    end
  end

  defp maybe_filter_counselor(query, %{counselor_id: counselor_id}) do
    maybe_filter_counselor(query, %{"counselor_id" => to_string(counselor_id)})
  end

  defp maybe_filter_counselor(query, _), do: query

  defp next_followup_due_at(lead_id) do
    LeadFollowup
    |> where([f], f.lead_id == ^lead_id and f.status == :pending)
    |> order_by([f], asc: f.due_at)
    |> select([f], f.due_at)
    |> limit(1)
    |> Repo.one()
  end

  defp format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_status(status) when is_binary(status) do
    status
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Map.new()
  end

  def normalize_phone(phone_number) when is_binary(phone_number) do
    digits = phone_number |> String.replace(~r/\D/, "")

    case digits do
      <<"91", rest::binary>> when byte_size(rest) == 10 -> rest
      _ -> digits
    end
  end

  def normalize_phone(_), do: nil

  def normalize_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
  end

  def normalize_name(_), do: nil

  def get_lead_by_phone(%Scope{} = scope, normalized_phone) when is_binary(normalized_phone) do
    Lead
    |> where([l], l.organization_id == ^scope.organization_id)
    |> where([l], l.normalized_phone_number == ^normalized_phone)
    |> where([l], is_nil(l.merged_into_lead_id))
    |> order_by([l], desc: l.last_activity_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_lead_by_phone(_scope, _normalized_phone), do: nil
end
