defmodule Backend.CsvParserPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Backend.Imports.CsvParser

  property "parses valid lead CSV rows" do
    check all(
            name <- string(:alphanumeric, min_length: 1),
            phone <- string(?0..?9, min_length: 10, max_length: 12)
          ) do
      csv = "student_name,phone_number\n#{name},#{phone}\n"

      assert {:ok, [{2, row}]} = CsvParser.parse_leads_csv(csv)
      assert row["student_name"] == name
      assert row["phone_number"] == phone
    end
  end
end
