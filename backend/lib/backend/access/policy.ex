defmodule Backend.Access.Policy do
  @moduledoc """
  Central authorization policy. All permission checks go through here.
  No more role name string comparisons - use this module instead.
  """

  alias Backend.Accounts.Scope
  alias Backend.Access.Permissions, as: P

  @doc """
  Check if scope has a specific permission.
  Super admins bypass all checks.
  """
  def can?(%Scope{is_super_admin: true}, _permission), do: true

  def can?(%Scope{permissions: permissions}, permission) when is_binary(permission) do
    MapSet.member?(permissions, permission)
  end

  def can?(_, _), do: false

  @doc "Permissions that allow reading leads."
  def lead_read_permissions do
    [P.leads_read_all(), P.leads_read_branch(), P.leads_read_own()]
  end

  @doc "Check if scope can read leads at any level."
  def can_read_leads?(%Scope{} = scope) do
    Enum.any?(lead_read_permissions(), &can?(scope, &1))
  end

  @doc """
  Check permission and raise if denied.
  """
  def authorize!(%Scope{} = scope, permission) do
    unless can?(scope, permission) do
      raise Backend.Access.UnauthorizedError,
        message: "Permission denied: #{permission}",
        permission: permission
    end

    :ok
  end

  # Lead access level helpers

  @doc "Can read all leads in organization"
  def can_read_all_leads?(%Scope{} = scope) do
    can?(scope, P.leads_read_all())
  end

  @doc "Can read leads in own branch"
  def can_read_branch_leads?(%Scope{} = scope) do
    can?(scope, P.leads_read_branch()) or can_read_all_leads?(scope)
  end

  @doc "Can assign leads to counselors"
  def can_assign_leads?(%Scope{} = scope) do
    can?(scope, P.leads_assign())
  end

  @doc "Can access call recordings"
  def can_access_recordings?(%Scope{} = scope) do
    can?(scope, P.recordings_playback())
  end

  @doc "Can view counselor reports"
  def can_view_counselor_reports?(%Scope{} = scope) do
    can?(scope, P.reports_counselors())
  end

  @doc "Check analytics access level"
  def can_view_analytics?(%Scope{} = scope, level) do
    case level do
      :org -> can?(scope, P.analytics_org())
      :branch -> can?(scope, P.analytics_branch()) or can?(scope, P.analytics_org())
      :own -> can?(scope, P.analytics_own()) or can_view_analytics?(scope, :branch)
    end
  end

  @doc """
  Returns the lead access level for a scope.
  Used by query scoping functions.
  """
  def lead_access_level(%Scope{} = scope) do
    cond do
      can?(scope, P.leads_read_all()) -> :organization
      can?(scope, P.leads_read_branch()) -> :branch
      true -> :own
    end
  end
end
