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
    path = Path.expand(tzpath())

    Path.join(path, "**")
    |> Path.wildcard()
    # Filter out directories and symlinks to old names of time zones
    |> Enum.filter(fn f -> File.lstat!(f, time: :posix).type == :regular end)
    # Filter out anything that doesn't look like a TZif file
    |> Enum.filter(&contains_tzif?/1)
    # Fix up the remaining paths to look like time zones
    |> Enum.map(&String.replace_leading(&1, path <> "/", ""))
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

  @doc """
  Return whether a time zone is valid
  """
  @spec valid_time_zone?(String.t()) :: boolean
  def valid_time_zone?(time_zone) do
    case Zoneinfo.Cache.get(time_zone) do
      {:ok, _} ->
        true

      _ ->
        false
    end
  end

  @doc """
  Return Zoneinfo metadata on a time zone

  The returned metadata is limited to what's available in the source TZif data
  file for the time zone. It's mostly useful for verifying that time zone
  information is available for dates used in your application. Note that proper
  time zone calculations depend on many things and it's possible that they'll
  work outside of the returned ranged. However, it's also possible that a time
  zone database was built and then a law changed which invalidates a record.
  """
  @spec get_metadata(String.t()) :: {:ok, Zoneinfo.Meta.t()} | {:error, atom()}
  defdelegate get_metadata(time_zone), to: Zoneinfo.Cache, as: :meta

  defp contains_tzif?(path) do
    case File.open(path, [:read], &contains_tzif_helper/1) do
      {:ok, result} -> result
      _error -> false
    end
  end

  defp contains_tzif_helper(io) do
    with buff when is_binary(buff) and byte_size(buff) == 8 <- IO.binread(io, 8),
         {:ok, _version} <- Zoneinfo.TZif.version(buff) do
      true
    else
      _anything -> false
    end
  end
end
