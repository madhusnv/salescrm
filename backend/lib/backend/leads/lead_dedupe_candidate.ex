defmodule Backend.Leads.LeadDedupeCandidate do
  use Ecto.Schema
  import Ecto.Changeset

  @match_types ~w(hard soft)a
  @statuses ~w(pending merged ignored)a

  schema "lead_dedupe_candidates" do
    field :match_type, Ecto.Enum, values: @match_types
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :decided_at, :utc_datetime
    field :notes, :string

    belongs_to :lead, Backend.Leads.Lead
    belongs_to :matched_lead, Backend.Leads.Lead
    belongs_to :import_row, Backend.Imports.ImportRow
    belongs_to :decision_by_user, Backend.Accounts.User

    timestamps()
  end

  def match_types, do: @match_types
  def statuses, do: @statuses

  def changeset(candidate, attrs) do
    candidate
    |> cast(attrs, [:match_type, :status, :decided_at, :notes])
    |> validate_required([:match_type, :status])
    |> validate_length(:notes, max: 500)
  end
end
