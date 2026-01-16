defmodule Backend.Analytics.AnalyticsDailyStat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analytics_daily_stats" do
    field(:metric, :string)
    field(:stat_date, :date)
    field(:value, :integer, default: 0)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)

    timestamps()
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:organization_id, :branch_id, :metric, :stat_date, :value])
    |> validate_required([:organization_id, :metric, :stat_date, :value])
    |> validate_length(:metric, max: 64)
  end
end
