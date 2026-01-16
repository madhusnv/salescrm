defmodule Backend.DedupeCandidatesTest do
  use Backend.DataCase

  import Backend.AccountsFixtures

  alias Backend.Leads
  alias Backend.Leads.LeadDedupeCandidate
  alias Backend.Organizations.University
  alias Backend.Repo

  test "merge_candidate/2 marks lead as merged and updates candidate" do
    user = user_fixture()
    scope = user_scope_fixture(user)

    university =
      Repo.insert!(%University{organization_id: user.organization_id, name: "Merge University"})

    {:ok, lead} =
      Leads.create_lead(scope, %{
        student_name: "Lead One",
        phone_number: "9000000001",
        university_id: university.id,
        assigned_counselor_id: user.id
      })

    {:ok, matched_lead} =
      Leads.create_lead(scope, %{
        student_name: "Lead Two",
        phone_number: "9000000001",
        university_id: university.id,
        assigned_counselor_id: user.id
      })

    candidate =
      Repo.insert!(%LeadDedupeCandidate{
        lead_id: lead.id,
        matched_lead_id: matched_lead.id,
        match_type: :soft,
        status: :pending
      })

    {:ok, {candidate, merged_lead}} = Leads.merge_candidate(scope, candidate)

    assert candidate.status == :merged
    assert candidate.decision_by_user_id == user.id
    assert merged_lead.merged_into_lead_id == matched_lead.id
    assert merged_lead.merged_at != nil
  end

  test "ignore_candidate/2 keeps lead and updates candidate" do
    user = user_fixture()
    scope = user_scope_fixture(user)

    university =
      Repo.insert!(%University{organization_id: user.organization_id, name: "Ignore University"})

    {:ok, lead} =
      Leads.create_lead(scope, %{
        student_name: "Lead Three",
        phone_number: "9000000002",
        university_id: university.id,
        assigned_counselor_id: user.id
      })

    {:ok, matched_lead} =
      Leads.create_lead(scope, %{
        student_name: "Lead Four",
        phone_number: "9000000002",
        university_id: university.id,
        assigned_counselor_id: user.id
      })

    candidate =
      Repo.insert!(%LeadDedupeCandidate{
        lead_id: lead.id,
        matched_lead_id: matched_lead.id,
        match_type: :soft,
        status: :pending
      })

    {:ok, candidate} = Leads.ignore_candidate(scope, candidate)

    assert candidate.status == :ignored
    assert candidate.decision_by_user_id == user.id
  end
end
