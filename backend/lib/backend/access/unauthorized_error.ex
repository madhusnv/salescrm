defmodule Backend.Access.UnauthorizedError do
  @moduledoc """
  Exception raised when a user attempts an unauthorized action.
  """

  defexception [:message, :permission]

  @impl true
  def exception(opts) do
    %__MODULE__{
      message: Keyword.get(opts, :message, "Unauthorized"),
      permission: Keyword.get(opts, :permission)
    }
  end
end
