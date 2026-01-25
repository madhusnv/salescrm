defmodule Backend.Access.Permissions do
  @moduledoc """
  Central registry of all permission keys.
  Use these constants instead of string literals for compile-time safety.
  """

  # Lead permissions
  def leads_read_all, do: "leads.read_all"
  def leads_read_branch, do: "leads.read_branch"
  def leads_read_own, do: "leads.read_own"
  def leads_create, do: "leads.create"
  def leads_update, do: "leads.update"
  def leads_delete, do: "leads.delete"
  def leads_assign, do: "leads.assign"
  def leads_reassign, do: "leads.reassign"
  def leads_import, do: "leads.import"
  def leads_export, do: "leads.export"

  # Call/Recording permissions
  def calls_read_all, do: "calls.read_all"
  def calls_read_branch, do: "calls.read_branch"
  def recordings_playback, do: "recordings.playback"
  def recordings_download, do: "recordings.download"

  # Analytics permissions
  def analytics_org, do: "analytics.org"
  def analytics_branch, do: "analytics.branch"
  def analytics_own, do: "analytics.own"

  # Admin permissions
  def admin_users, do: "admin.users"
  def admin_branches, do: "admin.branches"
  def admin_roles, do: "admin.roles"
  def admin_settings, do: "admin.settings"

  # Audit permissions
  def audit_read, do: "audit.read"

  # Reports permissions
  def reports_counselors, do: "reports.counselors"

  @doc """
  Returns all permission keys for seeding.
  """
  def all do
    [
      %{key: leads_read_all(), description: "Read all leads in organization", category: "leads"},
      %{key: leads_read_branch(), description: "Read leads in own branch", category: "leads"},
      %{key: leads_read_own(), description: "Read own assigned leads", category: "leads"},
      %{key: leads_create(), description: "Create leads", category: "leads"},
      %{key: leads_update(), description: "Update leads", category: "leads"},
      %{key: leads_delete(), description: "Delete leads", category: "leads"},
      %{key: leads_assign(), description: "Assign leads to counselors", category: "leads"},
      %{
        key: leads_reassign(),
        description: "Reassign leads between counselors",
        category: "leads"
      },
      %{key: leads_import(), description: "Import leads from CSV", category: "leads"},
      %{key: leads_export(), description: "Export leads", category: "leads"},
      %{key: calls_read_all(), description: "Read all call logs", category: "calls"},
      %{key: calls_read_branch(), description: "Read branch call logs", category: "calls"},
      %{key: recordings_playback(), description: "Play call recordings", category: "recordings"},
      %{
        key: recordings_download(),
        description: "Download call recordings",
        category: "recordings"
      },
      %{key: analytics_org(), description: "View organization analytics", category: "analytics"},
      %{key: analytics_branch(), description: "View branch analytics", category: "analytics"},
      %{key: analytics_own(), description: "View own analytics", category: "analytics"},
      %{key: admin_users(), description: "Manage users", category: "admin"},
      %{key: admin_branches(), description: "Manage branches", category: "admin"},
      %{key: admin_roles(), description: "Manage roles", category: "admin"},
      %{key: admin_settings(), description: "Manage settings", category: "admin"},
      %{key: audit_read(), description: "Read audit logs", category: "audit"},
      %{key: reports_counselors(), description: "View counselor reports", category: "reports"}
    ]
  end

  @doc """
  Returns default permissions for Super Admin role.
  """
  def super_admin_permissions do
    Enum.map(all(), & &1.key)
  end

  @doc """
  Returns default permissions for Branch Manager role.
  """
  def branch_manager_permissions do
    [
      leads_read_branch(),
      leads_create(),
      leads_update(),
      leads_assign(),
      leads_reassign(),
      leads_import(),
      leads_export(),
      calls_read_branch(),
      recordings_playback(),
      analytics_branch(),
      reports_counselors()
    ]
  end

  @doc """
  Returns default permissions for Counselor role.
  """
  def counselor_permissions do
    [
      leads_read_own(),
      leads_update(),
      recordings_playback(),
      analytics_own()
    ]
  end
end
