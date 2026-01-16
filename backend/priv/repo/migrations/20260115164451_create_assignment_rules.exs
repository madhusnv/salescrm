defmodule Backend.Repo.Migrations.CreateAssignmentRules do
  use Ecto.Migration

  def change do
    create table(:assignment_rules) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:branch_id, references(:branches, on_delete: :nilify_all))
      add(:university_id, references(:universities, on_delete: :delete_all), null: false)
      add(:counselor_id, references(:users, on_delete: :delete_all), null: false)
      add(:is_active, :boolean, null: false, default: true)
      add(:priority, :integer, null: false, default: 0)
      add(:daily_cap, :integer)
      add(:assigned_count, :integer, null: false, default: 0)
      add(:last_assigned_at, :utc_datetime)

      timestamps()
    end

    create(index(:assignment_rules, [:organization_id]))
    create(index(:assignment_rules, [:branch_id]))
    create(index(:assignment_rules, [:university_id]))
    create(index(:assignment_rules, [:counselor_id]))
    create(unique_index(:assignment_rules, [:organization_id, :university_id, :counselor_id]))
  end
end
