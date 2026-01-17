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
    query =
      AssignmentRule
      |> where(
        [r],
        r.organization_id == ^organization_id and
          r.university_id == ^university_id and
          r.is_active == true
      )
      |> maybe_filter_branch(branch_id)
      |> order_by([r], desc: r.priority, asc: r.last_assigned_at, asc: r.assigned_count)

    rules = Repo.all(from(r in query, limit: 50))

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

    where(query, [r], r.branch_id == ^branch_id)
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
end
