defmodule Backend.NormalizePhonePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Backend.Leads

  property "normalizes India country code prefix" do
    check all(digits <- string(:numeric, length: 10)) do
      assert Leads.normalize_phone("91" <> digits) == digits
    end
  end

  property "normalized phone contains only digits" do
    check all(phone <- string(:printable, min_length: 1)) do
      normalized = Leads.normalize_phone(phone)

      if normalized != nil do
        assert normalized =~ ~r/^\d*$/
      end
    end
  end
end
