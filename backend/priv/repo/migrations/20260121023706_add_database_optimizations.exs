defmodule Backend.Repo.Migrations.AddDatabaseOptimizations do
  use Ecto.Migration

  @doc """
  Database optimization migration addressing:
  1. Composite partial indexes for leads (org/branch/status + not merged)
  2. Trigram indexes for ILIKE search on name/phone
  3. Fix call_logs unique index to match lookup pattern
  4. Analytics composite indexes
  5. Import rows composite indexes
  6. Lead activities/followups indexes
  7. Import jobs indexes
  """

  def up do
    # ===========================================
    # 1. LEADS: Composite partial indexes
    # ===========================================

    # Backfill last_activity_at for leads that have NULL values
    execute """
    UPDATE leads
    SET last_activity_at = inserted_at
    WHERE last_activity_at IS NULL
    """

    # Main list screen: org + branch + status + sorted by last_activity
    # Partial index excludes merged leads (most common filter)
    create index(:leads, [:organization_id, :branch_id, :status, :last_activity_at],
             where: "merged_into_lead_id IS NULL",
             name: :leads_org_branch_status_activity_partial_idx
           )

    # Counselor "my leads" view: assigned counselor + activity
    create index(:leads, [:organization_id, :assigned_counselor_id, :last_activity_at],
             where: "merged_into_lead_id IS NULL",
             name: :leads_org_counselor_activity_partial_idx
           )

    # Fast phone lookup for dedupe (active leads only)
    create index(:leads, [:organization_id, :normalized_phone_number],
             where: "merged_into_lead_id IS NULL",
             name: :leads_org_phone_partial_idx
           )

    # Branch-scoped phone lookup
    create index(:leads, [:organization_id, :branch_id, :normalized_phone_number],
             where: "merged_into_lead_id IS NULL",
             name: :leads_org_branch_phone_partial_idx
           )

    # ===========================================
    # 2. LEADS: Trigram indexes for ILIKE search
    # ===========================================

    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    execute """
    CREATE INDEX leads_student_name_trgm_idx
    ON leads USING gin (student_name gin_trgm_ops)
    """

    execute """
    CREATE INDEX leads_phone_number_trgm_idx
    ON leads USING gin (phone_number gin_trgm_ops)
    """

    # ===========================================
    # 3. CALL_LOGS: Fix unique index to match lookup pattern
    # ===========================================

    # Drop the mismatched unique index
    drop_if_exists unique_index(:call_logs, [:organization_id, :device_call_id])

    # Create correct unique index matching get_call_log_by_device_id/3
    create unique_index(:call_logs, [:organization_id, :counselor_id, :device_call_id],
             name: :call_logs_org_counselor_device_unique_idx
           )

    # Add composite index for lead call history queries
    create index(:call_logs, [:lead_id, :started_at], name: :call_logs_lead_started_idx)

    # Counselor call history
    create index(:call_logs, [:counselor_id, :started_at], name: :call_logs_counselor_started_idx)

    # ===========================================
    # 4. ANALYTICS: Composite indexes for dashboard queries
    # ===========================================

    # Org + branch + time for branch-scoped dashboards
    create index(:analytics_events, [:organization_id, :branch_id, :occurred_at],
             name: :analytics_events_org_branch_occurred_idx
           )

    # Org + time + event_type for aggregation queries
    create index(:analytics_events, [:organization_id, :occurred_at, :event_type],
             name: :analytics_events_org_occurred_type_idx
           )

    # Daily stats lookup
    create index(:analytics_daily_stats, [:organization_id, :branch_id, :stat_date],
             name: :analytics_daily_stats_org_branch_date_idx
           )

    # ===========================================
    # 5. IMPORT_ROWS: Composite indexes for job processing
    # ===========================================

    # Main filter: job + status + row order
    create index(:import_rows, [:import_job_id, :status, :row_number],
             name: :import_rows_job_status_row_idx
           )

    # Dedupe/assignment filter
    create index(:import_rows, [:import_job_id, :dedupe_status, :assignment_status],
             name: :import_rows_job_dedupe_assign_idx
           )

    # Lead creation lookup
    create index(:import_rows, [:import_job_id, :lead_id], name: :import_rows_job_lead_idx)

    # ===========================================
    # 6. LEAD_ACTIVITIES: Index for timeline queries
    # ===========================================

    create index(:lead_activities, [:lead_id, :occurred_at],
             name: :lead_activities_lead_occurred_idx
           )

    # ===========================================
    # 7. LEAD_FOLLOWUPS: Index for pending followup queries
    # ===========================================

    create index(:lead_followups, [:lead_id, :status, :due_at],
             name: :lead_followups_lead_status_due_idx
           )

    # Counselor followups dashboard
    create index(:lead_followups, [:user_id, :status, :due_at],
             name: :lead_followups_user_status_due_idx
           )

    # ===========================================
    # 8. IMPORT_JOBS: Composite indexes for list queries
    # ===========================================

    create index(:import_jobs, [:organization_id, :inserted_at],
             name: :import_jobs_org_inserted_idx
           )

    create index(:import_jobs, [:organization_id, :status, :inserted_at],
             name: :import_jobs_org_status_inserted_idx
           )

    # ===========================================
    # 9. CALL_RECORDINGS: Counselor + status for reports
    # ===========================================

    create index(:call_recordings, [:counselor_id, :status, :recorded_at],
             name: :call_recordings_counselor_status_recorded_idx
           )

    create index(:call_recordings, [:call_log_id, :status],
             name: :call_recordings_call_status_idx
           )

    # ===========================================
    # 10. USERS: Composite for counselor list queries
    # ===========================================

    create index(:users, [:organization_id, :branch_id, :is_active],
             name: :users_org_branch_active_idx
           )
  end

  def down do
    # Leads
    drop_if_exists index(:leads, [:organization_id, :branch_id, :status, :last_activity_at],
                     name: :leads_org_branch_status_activity_partial_idx
                   )

    drop_if_exists index(:leads, [:organization_id, :assigned_counselor_id, :last_activity_at],
                     name: :leads_org_counselor_activity_partial_idx
                   )

    drop_if_exists index(:leads, [:organization_id, :normalized_phone_number],
                     name: :leads_org_phone_partial_idx
                   )

    drop_if_exists index(:leads, [:organization_id, :branch_id, :normalized_phone_number],
                     name: :leads_org_branch_phone_partial_idx
                   )

    execute "DROP INDEX IF EXISTS leads_student_name_trgm_idx"
    execute "DROP INDEX IF EXISTS leads_phone_number_trgm_idx"

    # Call logs
    drop_if_exists unique_index(:call_logs, [:organization_id, :counselor_id, :device_call_id],
                     name: :call_logs_org_counselor_device_unique_idx
                   )

    drop_if_exists index(:call_logs, [:lead_id, :started_at], name: :call_logs_lead_started_idx)

    drop_if_exists index(:call_logs, [:counselor_id, :started_at],
                     name: :call_logs_counselor_started_idx
                   )

    # Restore original unique index
    create unique_index(:call_logs, [:organization_id, :device_call_id])

    # Analytics
    drop_if_exists index(:analytics_events, [:organization_id, :branch_id, :occurred_at],
                     name: :analytics_events_org_branch_occurred_idx
                   )

    drop_if_exists index(:analytics_events, [:organization_id, :occurred_at, :event_type],
                     name: :analytics_events_org_occurred_type_idx
                   )

    drop_if_exists index(:analytics_daily_stats, [:organization_id, :branch_id, :stat_date],
                     name: :analytics_daily_stats_org_branch_date_idx
                   )

    # Import rows
    drop_if_exists index(:import_rows, [:import_job_id, :status, :row_number],
                     name: :import_rows_job_status_row_idx
                   )

    drop_if_exists index(:import_rows, [:import_job_id, :dedupe_status, :assignment_status],
                     name: :import_rows_job_dedupe_assign_idx
                   )

    drop_if_exists index(:import_rows, [:import_job_id, :lead_id],
                     name: :import_rows_job_lead_idx
                   )

    # Lead activities/followups
    drop_if_exists index(:lead_activities, [:lead_id, :occurred_at],
                     name: :lead_activities_lead_occurred_idx
                   )

    drop_if_exists index(:lead_followups, [:lead_id, :status, :due_at],
                     name: :lead_followups_lead_status_due_idx
                   )

    drop_if_exists index(:lead_followups, [:user_id, :status, :due_at],
                     name: :lead_followups_user_status_due_idx
                   )

    # Import jobs
    drop_if_exists index(:import_jobs, [:organization_id, :inserted_at],
                     name: :import_jobs_org_inserted_idx
                   )

    drop_if_exists index(:import_jobs, [:organization_id, :status, :inserted_at],
                     name: :import_jobs_org_status_inserted_idx
                   )

    # Call recordings
    drop_if_exists index(:call_recordings, [:counselor_id, :status, :recorded_at],
                     name: :call_recordings_counselor_status_recorded_idx
                   )

    drop_if_exists index(:call_recordings, [:call_log_id, :status],
                     name: :call_recordings_call_status_idx
                   )

    # Users
    drop_if_exists index(:users, [:organization_id, :branch_id, :is_active],
                     name: :users_org_branch_active_idx
                   )
  end
end
