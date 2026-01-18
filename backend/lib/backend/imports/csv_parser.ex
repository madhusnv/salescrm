defmodule Backend.Imports.CsvParser do
  alias NimbleCSV.RFC4180, as: CSV

  @required_headers ["student_name", "phone_number"]

  # Map alternative header names to the canonical names
  @header_aliases %{
    "student_name" => ["student_name", "studentname", "student name", "name", "student"],
    "phone_number" => [
      "phone_number",
      "phonenumber",
      "phone number",
      "phone",
      "mobile",
      "mobile_number",
      "contact"
    ]
  }

  def parse_leads_csv(csv_binary) when is_binary(csv_binary) do
    rows = CSV.parse_string(csv_binary, skip_headers: false)

    case rows do
      [] ->
        {:error, :empty}

      [header | data_rows] ->
        with {:ok, header_map} <- normalize_headers(header),
             {:ok, canonical_map} <- map_to_canonical(header_map),
             :ok <- validate_headers(canonical_map) do
          parsed_rows =
            data_rows
            |> Enum.with_index(2)
            |> Enum.map(fn {row, row_number} ->
              {row_number, map_row(row, canonical_map)}
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

  defp map_to_canonical(header_map) do
    canonical =
      Enum.reduce(@header_aliases, %{}, fn {canonical_name, aliases}, acc ->
        found_alias = Enum.find(aliases, fn alias -> Map.has_key?(header_map, alias) end)

        if found_alias do
          Map.put(acc, canonical_name, Map.get(header_map, found_alias))
        else
          acc
        end
      end)

    {:ok, canonical}
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
