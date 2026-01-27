defmodule Backend.Repo.Migrations.AddMoreDbIndexes do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    create(
      index(:import_rows, [:import_job_id, :assignment_status, :row_number],
        name: :import_rows_job_assignment_row_idx
      )
    )

    create(
      index(:import_rows, [:import_job_id, :row_number],
        where:
          "status = 'valid' AND dedupe_status IN ('none','soft') AND assignment_status IN ('pending','failed')",
        name: :import_rows_job_unassigned_row_partial_idx
      )
    )

    create(
      index(:leads, [:organization_id, :branch_id, :next_follow_up_at],
        where: "merged_into_lead_id IS NULL AND next_follow_up_at IS NOT NULL",
        name: :leads_org_branch_followup_partial_idx
      )
    )

    create(
      index(:leads, [:organization_id, :assigned_counselor_id, :next_follow_up_at],
        where: "merged_into_lead_id IS NULL AND next_follow_up_at IS NOT NULL",
        name: :leads_org_counselor_followup_partial_idx
      )
    )

    create(
      index(:lead_dedupe_candidates, [:status, :match_type, :inserted_at],
        name: :lead_dedupe_candidates_status_match_inserted_idx
      )
    )

    create(
      index(:call_recordings, [:organization_id, :status, :recorded_at],
        name: :call_recordings_org_status_recorded_idx
      )
    )

    execute("""
    CREATE INDEX IF NOT EXISTS import_jobs_original_filename_trgm_idx
    ON import_jobs USING gin (original_filename gin_trgm_ops)
    WHERE original_filename IS NOT NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS universities_name_trgm_idx
    ON universities USING gin (name gin_trgm_ops)
    """)
  end

  def down do
    drop_if_exists(
      index(:import_rows, [:import_job_id, :assignment_status, :row_number],
        name: :import_rows_job_assignment_row_idx
      )
    )

    drop_if_exists(
      index(:import_rows, [:import_job_id, :row_number],
        name: :import_rows_job_unassigned_row_partial_idx
      )
    )

    drop_if_exists(
      index(:leads, [:organization_id, :branch_id, :next_follow_up_at],
        name: :leads_org_branch_followup_partial_idx
      )
    )

    drop_if_exists(
      index(:leads, [:organization_id, :assigned_counselor_id, :next_follow_up_at],
        name: :leads_org_counselor_followup_partial_idx
      )
    )

    drop_if_exists(
      index(:lead_dedupe_candidates, [:status, :match_type, :inserted_at],
        name: :lead_dedupe_candidates_status_match_inserted_idx
      )
    )

    drop_if_exists(
      index(:call_recordings, [:organization_id, :status, :recorded_at],
        name: :call_recordings_org_status_recorded_idx
      )
    )

    execute("DROP INDEX IF EXISTS import_jobs_original_filename_trgm_idx")
    execute("DROP INDEX IF EXISTS universities_name_trgm_idx")
  end
end
