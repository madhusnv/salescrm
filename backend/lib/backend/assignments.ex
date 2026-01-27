defmodule Backend.Assignments do
  import Ecto.Query, warn: false

  alias Backend.Assignments.AssignmentRule
  alias Backend.Repo

  def list_rules(organization_id, filters \\ %{}) do
    AssignmentRule
    |> where([r], r.organization_id == ^organization_id)
    |> apply_filters(filters)
    |> order_by([r], desc: r.is_active, desc: r.priority, asc: r.counselor_id)
    |> preload([:university, :counselor, :branch])
    |> Repo.all()
  end

  def get_rule!(id) do
    AssignmentRule
    |> preload([:university, :counselor, :branch])
    |> Repo.get!(id)
  end

  def create_rule(attrs) do
    %AssignmentRule{}
    |> AssignmentRule.changeset(attrs)
    |> Repo.insert()
  end

  def update_rule(%AssignmentRule{} = rule, attrs) do
    rule
    |> AssignmentRule.changeset(attrs)
    |> Repo.update()
  end

  def delete_rule(%AssignmentRule{} = rule) do
    Repo.delete(rule)
  end

  def get_rule_for_org!(organization_id, id) do
    AssignmentRule
    |> where([r], r.organization_id == ^organization_id)
    |> Repo.get!(id)
  end

  def change_rule(%AssignmentRule{} = rule, attrs \\ %{}) do
    AssignmentRule.changeset(rule, attrs)
  end

  def pick_counselor(organization_id, branch_id, university_id) do
    rules = list_assignment_candidates(organization_id, branch_id, university_id)

    case {rules, pick_available_rule(rules)} do
      {[], _} ->
        {:error, :no_assignment_rules}

      {_, {:ok, rule, next_count}} ->
        updated_rule =
          rule
          |> AssignmentRule.system_changeset(%{
            assigned_count: next_count,
            last_assigned_at: DateTime.utc_now(:second)
          })
          |> Repo.update!()

        {:ok, updated_rule.counselor_id}

      {_, :none} ->
        {:error, :no_available_counselors}
    end
  end

  def list_assignment_candidates(organization_id, branch_id, university_id) do
    AssignmentRule
    |> where(
      [r],
      r.organization_id == ^organization_id and
        r.university_id == ^university_id and
        r.is_active == true
    )
    |> maybe_filter_branch(branch_id)
    |> order_by([r], desc: r.priority, asc: r.last_assigned_at, asc: r.assigned_count)
    |> limit(50)
    |> Repo.all()
  end

  def pick_counselor_cached(rules) when is_list(rules) do
    case pick_available_rule(rules) do
      {:ok, rule, next_count} ->
        updated_rule = %{
          rule
          | assigned_count: next_count,
            last_assigned_at: DateTime.utc_now(:second)
        }

        {:ok, updated_rule, replace_rule(rules, updated_rule)}

      :none ->
        {:error, :no_available_counselors, rules}
    end
  end

  def update_rule_counters!(%AssignmentRule{} = rule) do
    rule
    |> AssignmentRule.system_changeset(%{
      assigned_count: rule.assigned_count,
      last_assigned_at: rule.last_assigned_at
    })
    |> Repo.update!()
  end

  defp apply_filters(query, %{"university_id" => university_id}) when university_id != "" do
    where(query, [r], r.university_id == ^String.to_integer(university_id))
  end

  defp apply_filters(query, _), do: query

  defp maybe_filter_branch(query, nil), do: query
  defp maybe_filter_branch(query, ""), do: query

  defp maybe_filter_branch(query, branch_id) do
    branch_id =
      case branch_id do
        value when is_binary(value) -> String.to_integer(value)
        value -> value
      end

    # Find rules where branch_id is NULL (applies to all branches) OR matches the specific branch
    where(query, [r], is_nil(r.branch_id) or r.branch_id == ^branch_id)
  end

  defp pick_available_rule(rules) do
    today = today_in_india()

    Enum.find_value(rules, :none, fn rule ->
      effective_count =
        if same_day?(rule.last_assigned_at, today) do
          rule.assigned_count
        else
          0
        end

      if capped?(rule.daily_cap, effective_count) do
        false
      else
        {:ok, rule, effective_count + 1}
      end
    end)
  end

  defp capped?(nil, _count), do: false
  defp capped?(cap, count), do: count >= cap

  defp same_day?(nil, _today), do: false

  defp same_day?(datetime, today) do
    Date.compare(to_date_in_india(datetime), today) == :eq
  end

  defp today_in_india do
    DateTime.utc_now()
    |> to_date_in_india()
  end

  defp to_date_in_india(datetime) do
    datetime
    |> DateTime.add(19_800, :second)
    |> DateTime.to_date()
  end

  defp replace_rule(rules, updated_rule) do
    Enum.map(rules, fn rule ->
      if rule.id == updated_rule.id do
        updated_rule
      else
        rule
      end
    end)
  end
end
