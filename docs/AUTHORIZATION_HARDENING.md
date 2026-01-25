# Authorization Hardening Plan

This document addresses critical security and reliability issues in the current authorization system, broadcasting patterns, and login protection.

## Table of Contents
1. [Problem Statement](#problem-statement)
2. [Issue 1: Centralize Authorization Model](#issue-1-centralize-authorization-model)
3. [Issue 2: After-Commit Broadcasting](#issue-2-after-commit-broadcasting)
4. [Issue 3: Rate Limiting on Login](#issue-3-rate-limiting-on-login)
5. [Implementation Checklist](#implementation-checklist)
6. [Migration Plan](#migration-plan)

---

## Problem Statement

### Current Issues

| Issue | Risk | Impact |
|-------|------|--------|
| Role name string checks scattered across codebase | Security regression if role renamed | HIGH |
| DB queries for role checks on every request | Performance degradation | MEDIUM |
| Broadcasts inside transactions | Phantom updates to clients | MEDIUM |
| No rate limiting on login endpoints | Credential stuffing attacks | HIGH |

### Affected Files

```
lib/backend/leads.ex              # role_name() checks
lib/backend/reports.ex            # role_name() checks
lib/backend/access.ex             # super_admin?() DB queries
lib/backend_web/live/lead_index_live.ex    # role_name string comparisons
lib/backend_web/plugs/require_admin.ex     # role_name string comparisons
```

---

## Issue 1: Centralize Authorization Model

### Current State (Problematic)

```elixir
# Pattern found in leads.ex, reports.ex, etc.
defp role_name(user) do
  user = Repo.preload(user, :role)
  user.role.name
end

# Usage - brittle string comparison
role_name(user) == "Branch Manager" -> ...
```

**Problems:**
- Renaming a role breaks security silently
- DB query on every check (`Repo.preload`)
- Logic duplicated across 5+ modules
- No compile-time safety

### Solution: Permission-Based Policy Module

#### Step 1: Define Permission Keys

Create a central permission registry:

```elixir
# lib/backend/access/permissions.ex
defmodule Backend.Access.Permissions do
  @moduledoc """
  Central registry of all permission keys.
  Use these constants instead of string literals.
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
end
```

#### Step 2: Create Scope Struct with Preloaded Permissions

```elixir
# lib/backend/access/scope.ex
defmodule Backend.Access.Scope do
  @moduledoc """
  Represents the authorization scope for a user session.
  Preloaded at auth time, cached in session/socket.
  """

  defstruct [
    :user,
    :user_id,
    :organization_id,
    :branch_id,
    :role_id,
    :role_name,
    :permissions,
    :is_super_admin
  ]

  alias Backend.Repo
  alias Backend.Access.{Role, RolePermission, Permission}
  import Ecto.Query

  @doc """
  Build scope from authenticated user. Call once at login/session mount.
  """
  def build(user) when is_struct(user) do
    user = Repo.preload(user, [:role, :branch])
    permissions = load_permissions(user.role_id)

    %__MODULE__{
      user: user,
      user_id: user.id,
      organization_id: user.organization_id,
      branch_id: user.branch_id,
      role_id: user.role_id,
      role_name: user.role.name,
      permissions: MapSet.new(permissions),
      is_super_admin: user.role.name == "Super Admin"
    }
  end

  defp load_permissions(role_id) do
    from(rp in RolePermission,
      join: p in Permission,
      on: rp.permission_id == p.id,
      where: rp.role_id == ^role_id,
      select: p.key
    )
    |> Repo.all()
  end
end
```

#### Step 3: Create Policy Module

```elixir
# lib/backend/access/policy.ex
defmodule Backend.Access.Policy do
  @moduledoc """
  Central authorization policy. All permission checks go through here.
  """

  alias Backend.Access.Scope
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

  # Convenience functions for common checks

  def can_read_all_leads?(%Scope{} = scope) do
    can?(scope, P.leads_read_all())
  end

  def can_read_branch_leads?(%Scope{} = scope) do
    can?(scope, P.leads_read_branch()) or can_read_all_leads?(scope)
  end

  def can_assign_leads?(%Scope{} = scope) do
    can?(scope, P.leads_assign())
  end

  def can_access_recordings?(%Scope{} = scope) do
    can?(scope, P.recordings_playback())
  end

  def can_view_analytics?(%Scope{} = scope, level) do
    case level do
      :org -> can?(scope, P.analytics_org())
      :branch -> can?(scope, P.analytics_branch()) or can?(scope, P.analytics_org())
      :own -> can?(scope, P.analytics_own()) or can_view_analytics?(scope, :branch)
    end
  end
end
```

#### Step 4: Create Custom Exception

```elixir
# lib/backend/access/unauthorized_error.ex
defmodule Backend.Access.UnauthorizedError do
  defexception [:message, :permission]

  @impl true
  def exception(opts) do
    %__MODULE__{
      message: Keyword.get(opts, :message, "Unauthorized"),
      permission: Keyword.get(opts, :permission)
    }
  end
end
```

#### Step 5: Update UserAuth to Build Scope

```elixir
# lib/backend_web/user_auth.ex (additions)

defp mount_current_scope(session, socket) do
  Phoenix.Component.assign_new(socket, :current_scope, fn ->
    if user = get_user_from_session(session) do
      Backend.Access.Scope.build(user)
    end
  end)
end
```

#### Step 6: Refactor Leads Context

**Before:**
```elixir
defp scope_query(query, user) do
  cond do
    Access.super_admin?(user) -> query
    role_name(user) == "Branch Manager" ->
      where(query, [l], l.branch_id == ^user.branch_id)
    true ->
      # Counselor sees only assigned leads
      from(l in query,
        join: la in assoc(l, :lead_assignments),
        where: la.user_id == ^user.id and la.is_active == true
      )
  end
end
```

**After:**
```elixir
alias Backend.Access.{Scope, Policy}
alias Backend.Access.Permissions, as: P

defp scope_query(query, %Scope{} = scope) do
  cond do
    Policy.can?(scope, P.leads_read_all()) ->
      # Org-wide access
      where(query, [l], l.organization_id == ^scope.organization_id)

    Policy.can?(scope, P.leads_read_branch()) ->
      # Branch-level access
      where(query, [l], l.branch_id == ^scope.branch_id)

    true ->
      # Counselor: only assigned leads
      from(l in query,
        join: la in assoc(l, :lead_assignments),
        where: la.user_id == ^scope.user_id and la.is_active == true
      )
  end
end
```

---

## Issue 2: After-Commit Broadcasting

### Current State (Problematic)

```elixir
def assign_lead(lead, user, assigner) do
  Repo.transaction(fn ->
    # ... update lead assignment
    Broadcaster.broadcast_lead_assigned(lead, user)  # <-- INSIDE transaction!
  end)
end
```

**Problem:** If transaction rolls back after broadcast, clients see phantom updates.

### Solution: After-Commit Pattern

#### Option A: Using Ecto.Multi with after-commit callback

```elixir
# lib/backend/leads.ex
def assign_lead(lead, user, assigner) do
  Multi.new()
  |> Multi.update(:deactivate_old, deactivate_old_assignments(lead))
  |> Multi.insert(:assignment, create_assignment_changeset(lead, user, assigner))
  |> Multi.update(:lead, update_lead_assignment(lead, user))
  |> Repo.transaction()
  |> case do
    {:ok, %{lead: lead, assignment: assignment}} ->
      # Broadcast AFTER successful commit
      Broadcaster.broadcast_lead_assigned(lead, user)
      {:ok, lead}

    {:error, _step, changeset, _changes} ->
      {:error, changeset}
  end
end
```

#### Option B: Using Oban for guaranteed delivery

For critical notifications (mobile push, email), use Oban jobs:

```elixir
# lib/backend/leads.ex
def assign_lead(lead, user, assigner) do
  Multi.new()
  |> Multi.update(:lead, ...)
  |> Multi.insert(:assignment, ...)
  |> Oban.insert(:notification_job, fn %{lead: lead} ->
    Backend.Workers.NotifyAssignment.new(%{
      lead_id: lead.id,
      user_id: user.id
    })
  end)
  |> Repo.transaction()
end
```

```elixir
# lib/backend/workers/notify_assignment.ex
defmodule Backend.Workers.NotifyAssignment do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"lead_id" => lead_id, "user_id" => user_id}}) do
    lead = Leads.get_lead!(lead_id)
    user = Accounts.get_user!(user_id)

    # These happen after commit, with retry guarantees
    Broadcaster.broadcast_lead_assigned(lead, user)
    PushNotifications.notify_counselor(user, lead)

    :ok
  end
end
```

#### Refactor Checklist

Search and fix all broadcast calls inside transactions:

```bash
# Find potential issues
grep -rn "Repo.transaction" lib/backend/ | xargs -I{} grep -l "Broadcaster\|broadcast"
```

Files to audit:
- `lib/backend/leads.ex`
- `lib/backend/imports.ex`
- `lib/backend/assignments.ex`

---

## Issue 3: Rate Limiting on Login

### Risk Assessment

Without rate limiting:
- Credential stuffing attacks can test millions of passwords
- Brute force attacks on known email addresses
- API abuse and resource exhaustion

### Solution: Hammer Rate Limiter

#### Step 1: Add Dependency

```elixir
# mix.exs
defp deps do
  [
    {:hammer, "~> 6.1"},
    {:hammer_backend_ets, "~> 6.1"}  # Or Redis for distributed
  ]
end
```

#### Step 2: Configure Hammer

```elixir
# config/config.exs
config :hammer,
  backend: {Hammer.Backend.ETS, [
    expiry_ms: 60_000 * 60 * 2,  # 2 hours
    cleanup_interval_ms: 60_000 * 10  # 10 minutes
  ]}
```

#### Step 3: Create Rate Limit Plug

```elixir
# lib/backend_web/plugs/rate_limit.ex
defmodule BackendWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug for sensitive endpoints.
  """

  import Plug.Conn
  alias Plug.Conn

  @login_limit 5          # attempts
  @login_window 60_000    # 1 minute
  @api_limit 100          # requests
  @api_window 60_000      # 1 minute

  def init(opts), do: opts

  def call(conn, :login) do
    key = "login:#{client_ip(conn)}"
    check_rate(conn, key, @login_limit, @login_window, "Too many login attempts")
  end

  def call(conn, :api) do
    key = "api:#{client_ip(conn)}"
    check_rate(conn, key, @api_limit, @api_window, "API rate limit exceeded")
  end

  def call(conn, {:api_auth, user_id}) do
    key = "api:user:#{user_id}"
    check_rate(conn, key, @api_limit * 2, @api_window, "API rate limit exceeded")
  end

  defp check_rate(conn, key, limit, window, message) do
    case Hammer.check_rate(key, window, limit) do
      {:allow, _count} ->
        conn

      {:deny, retry_after} ->
        conn
        |> put_resp_header("retry-after", to_string(div(retry_after, 1000)))
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: message, retry_after: retry_after}))
        |> halt()
    end
  end

  defp client_ip(conn) do
    # Check X-Forwarded-For for proxied requests
    forwarded_for =
      conn
      |> Conn.get_req_header("x-forwarded-for")
      |> List.first()

    case forwarded_for do
      nil ->
        conn.remote_ip |> :inet.ntoa() |> to_string()

      forwarded ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()
    end
  end
end
```

#### Step 4: Apply to Router

```elixir
# lib/backend_web/router.ex

pipeline :rate_limited_login do
  plug BackendWeb.Plugs.RateLimit, :login
end

pipeline :rate_limited_api do
  plug BackendWeb.Plugs.RateLimit, :api
end

# Apply to login routes
scope "/", BackendWeb do
  pipe_through [:browser, :redirect_if_user_is_authenticated, :rate_limited_login]

  live_session :redirect_if_user_is_authenticated, ... do
    live "/users/log-in", UserLive.Login, :new
  end

  post "/users/log-in", UserSessionController, :create
end

# Apply to API auth
scope "/api", BackendWeb do
  pipe_through [:api, :rate_limited_api]

  post "/auth/login", AuthController, :login
  post "/auth/refresh", AuthController, :refresh
end
```

#### Step 5: Add Account Lockout (Optional Enhancement)

```elixir
# lib/backend/accounts.ex

@max_failed_attempts 5
@lockout_duration_minutes 30

def authenticate_user(email, password) do
  user = get_user_by_email(email)

  cond do
    is_nil(user) ->
      # Prevent timing attacks
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}

    user.locked_until && DateTime.compare(user.locked_until, DateTime.utc_now()) == :gt ->
      {:error, :account_locked}

    Bcrypt.verify_pass(password, user.hashed_password) ->
      clear_failed_attempts(user)
      {:ok, user}

    true ->
      record_failed_attempt(user)
      {:error, :invalid_credentials}
  end
end

defp record_failed_attempt(user) do
  new_count = (user.failed_login_attempts || 0) + 1

  updates =
    if new_count >= @max_failed_attempts do
      %{
        failed_login_attempts: new_count,
        locked_until: DateTime.add(DateTime.utc_now(), @lockout_duration_minutes * 60, :second)
      }
    else
      %{failed_login_attempts: new_count}
    end

  user
  |> Ecto.Changeset.change(updates)
  |> Repo.update()
end

defp clear_failed_attempts(user) do
  user
  |> Ecto.Changeset.change(%{failed_login_attempts: 0, locked_until: nil})
  |> Repo.update()
end
```

#### Migration for Account Lockout

```elixir
# priv/repo/migrations/XXXXXX_add_login_lockout_fields.exs
defmodule Backend.Repo.Migrations.AddLoginLockoutFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
    end
  end
end
```

---

## Implementation Checklist

### Phase 1: Authorization Centralization (Priority: HIGH)

- [ ] Create `lib/backend/access/permissions.ex` - permission key constants
- [ ] Create `lib/backend/access/scope.ex` - scope struct with preloaded permissions
- [ ] Create `lib/backend/access/policy.ex` - central policy checks
- [ ] Create `lib/backend/access/unauthorized_error.ex` - exception
- [ ] Update `lib/backend_web/user_auth.ex` - build scope at session mount
- [ ] Refactor `lib/backend/leads.ex` - use Policy.can?() instead of role_name()
- [ ] Refactor `lib/backend/reports.ex` - use Policy.can?()
- [ ] Refactor `lib/backend_web/live/lead_index_live.ex` - use scope.permissions
- [ ] Refactor `lib/backend_web/plugs/require_admin.ex` - use Policy.can?()
- [ ] Add permission seeding to `priv/repo/seeds.exs`
- [ ] Add tests for Policy module
- [ ] Add tests for scope-based query scoping

### Phase 2: After-Commit Broadcasting (Priority: MEDIUM)

- [ ] Audit all `Repo.transaction` blocks for broadcast calls
- [ ] Refactor `lib/backend/leads.ex` assign functions
- [ ] Refactor `lib/backend/imports.ex` completion broadcasts
- [ ] Create Oban worker for critical notifications
- [ ] Add tests for broadcast-after-commit behavior

### Phase 3: Rate Limiting (Priority: HIGH)

- [ ] Add `hammer` and `hammer_backend_ets` deps
- [ ] Configure Hammer in `config/config.exs`
- [ ] Create `lib/backend_web/plugs/rate_limit.ex`
- [ ] Apply rate limiting to login routes in router
- [ ] Apply rate limiting to API routes
- [ ] Add migration for account lockout fields
- [ ] Implement account lockout in `Accounts.authenticate_user/2`
- [ ] Add tests for rate limiting behavior
- [ ] Add monitoring/alerting for rate limit hits

---

## Migration Plan

### Week 1: Authorization
1. Create new modules (Permissions, Scope, Policy)
2. Add permission seeding
3. Refactor one context (Leads) as proof of concept
4. Write tests

### Week 2: Complete Authorization Rollout
1. Refactor remaining contexts (Reports, etc.)
2. Refactor LiveViews and plugs
3. Remove all `role_name()` helper functions
4. Full test coverage

### Week 3: Broadcasting + Rate Limiting
1. Implement after-commit pattern
2. Add Hammer rate limiting
3. Add account lockout
4. Integration testing
5. Deploy to staging

### Week 4: Monitoring + Production
1. Add metrics for auth failures
2. Add alerts for lockouts
3. Deploy to production
4. Monitor and tune rate limits

---

## Testing Strategy

```elixir
# test/backend/access/policy_test.exs
defmodule Backend.Access.PolicyTest do
  use Backend.DataCase

  alias Backend.Access.{Policy, Scope, Permissions}

  describe "can?/2" do
    test "super admin bypasses all checks" do
      scope = build_scope(role: "Super Admin", permissions: [])
      assert Policy.can?(scope, Permissions.leads_read_all())
    end

    test "user with permission is allowed" do
      scope = build_scope(permissions: ["leads.read_branch"])
      assert Policy.can?(scope, "leads.read_branch")
    end

    test "user without permission is denied" do
      scope = build_scope(permissions: ["leads.read_own"])
      refute Policy.can?(scope, "leads.read_all")
    end
  end

  describe "authorize!/2" do
    test "raises UnauthorizedError when denied" do
      scope = build_scope(permissions: [])

      assert_raise Backend.Access.UnauthorizedError, fn ->
        Policy.authorize!(scope, "admin.users")
      end
    end
  end
end
```

---

## Metrics to Track

After implementation, monitor:

| Metric | Alert Threshold |
|--------|-----------------|
| Login failures per minute | > 50 |
| Account lockouts per hour | > 10 |
| Rate limit 429 responses | > 100/min |
| Authorization denials | Spike > 3x baseline |
| Unauthorized exception rate | Any occurrence |

---

## References

- [Phoenix Authentication Guide](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html)
- [Hammer Rate Limiter](https://hexdocs.pm/hammer/Hammer.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [Ecto.Multi Documentation](https://hexdocs.pm/ecto/Ecto.Multi.html)
