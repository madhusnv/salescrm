defmodule BackendWeb.Api.RecordingControllerTest do
  use BackendWeb.ConnCase, async: true

  alias Backend.Accounts
  alias Backend.Access.Role
  alias Backend.Leads
  alias Backend.Recordings.CallRecording
  alias BackendWeb.ApiToken
  alias Backend.Organizations.{Branch, Organization, University}
  alias Backend.Repo

  setup %{conn: conn} do
    uniq = System.unique_integer([:positive])

    organization =
      Repo.insert!(%Organization{
        name: "Org #{uniq}",
        country: "IN",
        timezone: "Asia/Kolkata"
      })

    branch = Repo.insert!(%Branch{organization_id: organization.id, name: "Branch #{uniq}"})

    role =
      Repo.insert!(%Role{organization_id: organization.id, name: "Super Admin", is_system: true})

    {:ok, user} =
      Accounts.register_user(%{
        full_name: "Admin #{uniq}",
        email: "admin#{uniq}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        organization_id: organization.id,
        branch_id: branch.id,
        role_id: role.id
      })

    university =
      Repo.insert!(%University{organization_id: organization.id, name: "Uni #{uniq}"})

    {:ok, lead} =
      Leads.create_lead(Backend.Accounts.Scope.for_user(user), %{
        student_name: "Lead #{uniq}",
        phone_number: "900000#{uniq}",
        university_id: university.id
      })

    token = ApiToken.sign_access_token(user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn, lead: lead}
  end

  test "uploads and completes a recording", %{conn: conn, lead: lead} do
    init_params = %{
      "lead_id" => lead.id,
      "content_type" => "audio/m4a",
      "consent_granted" => true,
      "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    conn = post(conn, ~p"/api/recordings/init", init_params)
    assert %{"data" => %{"id" => recording_id}} = json_response(conn, 200)

    upload_body = "fake-audio"

    conn =
      conn
      |> put_req_header("content-type", "audio/m4a")
      |> put(~p"/api/recordings/#{recording_id}/upload", upload_body)

    assert %{"data" => %{"file_url" => file_url}} = json_response(conn, 200)

    complete_params = %{
      "status" => "uploaded",
      "file_url" => file_url,
      "file_size_bytes" => byte_size(upload_body),
      "duration_seconds" => 5
    }

    conn = post(conn, ~p"/api/recordings/#{recording_id}/complete", complete_params)
    assert %{"data" => %{"status" => "uploaded"}} = json_response(conn, 200)

    recording = Repo.get!(CallRecording, recording_id)
    assert recording.file_url == file_url
  end
end
