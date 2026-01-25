defmodule BackendWeb.Router do
  use BackendWeb, :router

  import BackendWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {BackendWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(BackendWeb.Plugs.SecurityHeaders)
    plug(:fetch_current_scope_for_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(BackendWeb.Plugs.ApiAuth, :fetch_current_user)
  end

  pipeline :api_auth do
    plug(BackendWeb.Plugs.ApiAuth, :require_authenticated)
  end

  pipeline :admin_branch_scoped do
    plug(BackendWeb.Plugs.RequirePermission, "branch.manage")
    plug(BackendWeb.Plugs.RequireBranchScope, param: "branch_id")
  end

  pipeline :require_admin do
    plug(BackendWeb.Plugs.RequireAdmin)
  end

  scope "/", BackendWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
  end

  # Other scopes may use custom stacks.
  scope "/api", BackendWeb.Api do
    pipe_through(:api)

    post("/auth/login", SessionController, :create)
    post("/auth/refresh", SessionController, :refresh)
  end

  scope "/api", BackendWeb.Api do
    pipe_through([:api, :api_auth])

    get("/assignment-rules", AssignmentRuleController, :index)
    post("/assignment-rules", AssignmentRuleController, :create)
    put("/assignment-rules/:id", AssignmentRuleController, :update)
    delete("/assignment-rules/:id", AssignmentRuleController, :delete)
    get("/universities", UniversityController, :index)
    get("/leads", LeadController, :index)
    post("/leads", LeadController, :create)
    get("/leads/:id", LeadController, :show)
    post("/leads/:id/status", LeadController, :update_status)
    post("/leads/:id/notes", LeadController, :add_note)
    post("/leads/:id/followups", LeadController, :schedule_followup)
    get("/call-logs", CallLogController, :index)
    post("/call-logs", CallLogController, :create)
    post("/recordings/init", RecordingController, :init)
    put("/recordings/:id/upload", RecordingController, :upload)
    post("/recordings/:id/complete", RecordingController, :complete)
    get("/recordings", RecordingController, :index)
    get("/counselor-stats", CounselorStatsController, :show)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: BackendWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  ## Authentication routes

  scope "/", BackendWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :require_authenticated_user,
      on_mount: [{BackendWeb.UserAuth, :require_authenticated}] do
      live("/dashboard", DashboardLive, :index)
      live("/leads", LeadIndexLive, :index)
      live("/leads/:id", LeadShowLive, :show)
      live("/leads/dedupe", LeadDedupeLive, :index)
      live("/imports/leads", ImportLeadsLive, :index)
      live("/imports/leads/:id", ImportJobLive, :show)
      live("/assignments/rules", AssignmentRulesLive, :index)
      live("/users/settings", UserLive.Settings, :edit)
      live("/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email)
    end

    get("/imports/leads/template", CsvTemplateController, :show)
    post("/users/update-password", UserSessionController, :update_password)
  end

  scope "/", BackendWeb do
    pipe_through([:browser])

    live_session :current_user,
      on_mount: [{BackendWeb.UserAuth, :mount_current_scope}] do
      live("/users/register", UserLive.Registration, :new)
      live("/users/log-in", UserLive.Login, :new)
    end

    post("/users/log-in", UserSessionController, :create)
    delete("/users/log-out", UserSessionController, :delete)
  end

  scope "/admin", BackendWeb do
    pipe_through([:browser, :require_authenticated_user, :require_admin])

    live_session :admin,
      on_mount: [{BackendWeb.UserAuth, :require_authenticated}] do
      live("/users", Admin.UserLive.Index, :index)
      live("/users/new", Admin.UserLive.Index, :new)
      live("/users/:id/edit", Admin.UserLive.Index, :edit)
      live("/branches", Admin.BranchLive.Index, :index)
      live("/branches/new", Admin.BranchLive.Index, :new)
      live("/branches/:id/edit", Admin.BranchLive.Index, :edit)
      live("/universities", Admin.UniversityLive.Index, :index)
      live("/universities/new", Admin.UniversityLive.Index, :new)
      live("/universities/:id/edit", Admin.UniversityLive.Index, :edit)
      live("/recordings", Admin.RecordingLive.Index, :index)
      live("/audit", Admin.AuditLive.Index, :index)
      live("/organization", Admin.OrganizationLive.Settings, :index)
      live("/counselor-reports", Admin.CounselorReportLive.Index, :index)
      live("/counselor-reports/:id", Admin.CounselorReportLive.Show, :show)
    end

    get("/export/leads", Admin.ExportController, :leads)
  end
end
