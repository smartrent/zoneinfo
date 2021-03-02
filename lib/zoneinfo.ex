defmodule Zoneinfo do
  @moduledoc """
  Elixir time zone support for your OS-supplied time zone database

  Tell Elixir to use this as the default time zone database by running:

  ```elixir
  Calendar.put_time_zone_database(Zoneinfo.TimeZoneDatabase)
  ```

  Time zone data is loaded from the path returned by `tzpath/0`. The default
  is to use `/usr/share/zoneinfo`, but that may be changed by setting the
  `$TZPATH` environment or adding the following to your project's `config.exs`:

  ```elixir
  config :zoneinfo, tzpath: "/custom/location"
  ```

  Call `time_zones/0` to get the list of supported time zones.
  """

  @doc """
  Return all known time zones

  This function scans the path returned by `tzpath/0` for all time zones and
  performs a basic check on each file. It may not be fast. It will not return
  the aliases that zoneinfo uses for backwards compatibility even though they
  may still work.
  """
  @spec time_zones() :: [String.t()]
  def time_zones() do
    Zoneinfo.Cache.get_time_zones()
  end

  @doc """
  Return the path to the time zone files
  """
  @spec tzpath() :: binary()
  def tzpath() do
    with nil <- Application.get_env(:zoneinfo, :tzpath),
         nil <- System.get_env("TZPATH") do
      "/usr/share/zoneinfo"
    end
  end
end
