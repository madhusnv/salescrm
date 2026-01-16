defmodule Backend.Repo.Migrations.CreateAnalyticsDailyStats do
  use Ecto.Migration

  def change do
    create table(:analytics_daily_stats) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:branch_id, references(:branches, on_delete: :nilify_all))
      add(:metric, :string, null: false)
      add(:stat_date, :date, null: false)
      add(:value, :integer, null: false, default: 0)

      timestamps()
    end

    create(index(:analytics_daily_stats, [:organization_id, :stat_date]))
    create(index(:analytics_daily_stats, [:branch_id, :stat_date]))

    create(
      unique_index(:analytics_daily_stats, [:organization_id, :branch_id, :metric, :stat_date],
        name: :analytics_daily_stats_unique
      )
    )
  end
end
