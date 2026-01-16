defmodule BackendWeb.Api.AssignmentRuleController do
  use BackendWeb, :controller

  alias Backend.Assignments

  def index(conn, params) do
    user = conn.assigns.current_user
    rules = Assignments.list_rules(user.organization_id, params)
    json(conn, %{data: render_rules(rules)})
  end

  def create(conn, %{"assignment_rule" => params}) do
    user = conn.assigns.current_user
    attrs = Map.put(params, "organization_id", user.organization_id)

    case Assignments.create_rule(attrs) do
      {:ok, rule} ->
        json(conn, %{data: render_rule(rule)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_on(changeset)})
    end
  end

  def update(conn, %{"id" => id, "assignment_rule" => params}) do
    user = conn.assigns.current_user
    rule = Assignments.get_rule_for_org!(user.organization_id, id)

    case Assignments.update_rule(rule, params) do
      {:ok, rule} ->
        json(conn, %{data: render_rule(rule)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_on(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    rule = Assignments.get_rule_for_org!(user.organization_id, id)
    {:ok, _rule} = Assignments.delete_rule(rule)
    send_resp(conn, :no_content, "")
  end

  defp render_rules(rules), do: Enum.map(rules, &render_rule/1)

  defp render_rule(rule) do
    %{
      id: rule.id,
      organization_id: rule.organization_id,
      branch_id: rule.branch_id,
      university_id: rule.university_id,
      counselor_id: rule.counselor_id,
      is_active: rule.is_active,
      priority: rule.priority,
      daily_cap: rule.daily_cap,
      assigned_count: rule.assigned_count,
      last_assigned_at: rule.last_assigned_at
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
