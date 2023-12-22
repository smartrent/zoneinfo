defmodule ZoneinfoTest do
  use ExUnit.Case, async: false
  doctest Zoneinfo

  test "time_zones/0" do
    all_time_zones = Zoneinfo.time_zones()

    # Spot check that the Makefile ran zic on all expected data files
    assert "America/New_York" in all_time_zones
    assert "America/Argentina/Buenos_Aires" in all_time_zones
    assert "Africa/Cairo" in all_time_zones
    assert "Australia/Sydney" in all_time_zones
    assert "Antarctica/Troll" in all_time_zones
    assert "Asia/Tokyo" in all_time_zones
    assert "Europe/London" in all_time_zones
    assert "Indian/Maldives" in all_time_zones
    assert "Pacific/Tahiti" in all_time_zones
    assert "Etc/UTC" in all_time_zones

    # Check that directories weren't included
    refute "America" in all_time_zones
  end

  test "valid_time_zone?/1" do
    assert Zoneinfo.valid_time_zone?("America/New_York")
    refute Zoneinfo.valid_time_zone?("Mars/Gale_Crater")
  end

  describe "tzpath/0" do
    test "app environment" do
      # This is set in the config.exs for testing
      assert Zoneinfo.tzpath() == Application.app_dir(:zoneinfo, ["priv", "zoneinfo"])
    end

    test "OS environment" do
      old_path = clear_path()
      System.put_env("TZDIR", "tzpath_environment")

      assert Zoneinfo.tzpath() == "tzpath_environment"

      :os.unsetenv(~c"TZDIR")
      pop_path(old_path)
    end

    test "deprecated TZPATH OS environment" do
      old_path = clear_path()
      System.put_env("TZPATH", "tzpath_environment")

      assert Zoneinfo.tzpath() == "tzpath_environment"

      :os.unsetenv(~c"TZPATH")
      pop_path(old_path)
    end

    test "default" do
      old_path = clear_path()

      assert Zoneinfo.tzpath() == "/usr/share/zoneinfo"

      pop_path(old_path)
    end

    defp clear_path() do
      old_path = Application.get_env(:zoneinfo, :tzpath)
      Application.delete_env(:zoneinfo, :tzpath)
      old_path
    end

    defp pop_path(old_path) do
      Application.put_env(:zoneinfo, :tzpath, old_path)
    end
  end
end
