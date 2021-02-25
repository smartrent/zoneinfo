defmodule Zoneinfo.CacheTest do
  use ExUnit.Case, async: false
  alias Zoneinfo.Cache

  test "looks up timezone that exists" do
    assert {:ok, _} = Cache.get("America/New_York")
  end

  test "returns error on unknown timezones" do
    assert {:error, :enoent} == Cache.get("Mars/Jezero_Crater")
  end

  test "garbage collection clears loaded data" do
    {:ok, _} = Cache.get("America/New_York")
    assert :ets.info(Zoneinfo.Cache, :size) > 0

    Process.send(Zoneinfo.Cache, :gc, [])

    # Wait for the message
    Process.sleep(50)

    assert :ets.info(Zoneinfo.Cache, :size) == 0
  end
end
