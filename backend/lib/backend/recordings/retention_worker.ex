defmodule Backend.Recordings.RetentionWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  alias Backend.Recordings

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    _ = Recordings.expire_old_recordings()
    :ok
  end
end
