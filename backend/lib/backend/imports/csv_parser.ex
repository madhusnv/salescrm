defmodule Backend.Imports.CsvParser do
  alias NimbleCSV.RFC4180, as: CSV

  @required_headers ["student_name", "phone_number"]

  def parse_leads_csv(csv_binary) when is_binary(csv_binary) do
    rows = CSV.parse_string(csv_binary)

    case rows do
      [] ->
        {:error, :empty}

      [header | data_rows] ->
        with {:ok, header_map} <- normalize_headers(header),
             :ok <- validate_headers(header_map) do
          parsed_rows =
            data_rows
            |> Enum.with_index(2)
            |> Enum.map(fn {row, row_number} ->
              {row_number, map_row(row, header_map)}
            end)

          {:ok, parsed_rows}
        end
    end
  rescue
    _ -> {:error, :invalid_csv}
  end

  defp normalize_headers(header) do
    keys = header |> Enum.map(&normalize_header/1)

    if Enum.uniq(keys) == keys do
      {:ok, Enum.with_index(keys) |> Map.new(fn {key, idx} -> {key, idx} end)}
    else
      {:error, :duplicate_headers}
    end
  end

  defp validate_headers(header_map) do
    missing =
      Enum.filter(@required_headers, fn header -> not Map.has_key?(header_map, header) end)

    if missing == [] do
      :ok
    else
      {:error, {:missing_headers, missing}}
    end
  end

  defp map_row(row, header_map) do
    %{
      "student_name" => value_at(row, header_map, "student_name"),
      "phone_number" => value_at(row, header_map, "phone_number")
    }
  end

  defp value_at(row, header_map, key) do
    idx = Map.fetch!(header_map, key)
    row |> Enum.at(idx) |> to_string() |> String.trim()
  end

  defp normalize_header(header) do
    header
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end
end
