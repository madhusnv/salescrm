defmodule Backend.Imports.ImportJobWorker do
  use Oban.Worker, queue: :imports, max_attempts: 3

  alias Backend.Imports
  alias Backend.Imports.ImportJob
  alias Backend.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"import_job_id" => job_id, "csv_content" => csv_content}}) do
    job = Repo.get!(ImportJob, job_id)

    case Imports.process_job(job, csv_content) do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
