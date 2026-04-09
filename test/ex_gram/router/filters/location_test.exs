defmodule ExGram.Router.Filters.LocationTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Location

  @ctx %{}

  describe "call/3" do
    test "matches any location update" do
      assert Location.call({:location, %{latitude: 40.7128, longitude: -74.006}}, @ctx, nil) == true
    end

    test "matches regardless of opts value" do
      assert Location.call({:location, %{}}, @ctx, :anything) == true
    end

    test "does not match non-location updates" do
      refute Location.call({:command, :start, ""}, @ctx, nil)
      refute Location.call({:text, "hello", %{}}, @ctx, nil)
      refute Location.call({:callback_query, %{data: "x"}}, @ctx, nil)
      refute Location.call({:message, %{}}, @ctx, nil)
    end
  end
end
