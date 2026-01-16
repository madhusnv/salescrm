defmodule Backend.Analytics.DailyRollupWorker do
  use Oban.Worker, queue: :analytics, max_attempts: 3

  alias Backend.Analytics

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"date" => date}}) do
    with {:ok, date} <- Date.from_iso8601(date) do
      _ = Analytics.rollup_daily(date)
      :ok
    end
  end

  def perform(%Oban.Job{}) do
    date = Date.utc_today() |> Date.add(-1)
    _ = Analytics.rollup_daily(date)
    :ok
  end
end
