defmodule Zoneinfo.TimeZoneDatabase do
  @moduledoc """
  `Calendar.TimeZoneDatabase` implementation for Zoneinfo

  Pass this module to the `DateTime` functions:

      iex> DateTime.now!("Europe/Copenhagen", Zoneinfo.TimeZoneDatabase)
      #DateTime<2021-07-24 12:56:38.324705+02:00 CEST Europe/Copenhagen>

  or set it as the default by calling `Calendar.put_time_zone_database/1`:

      iex> Calendar.put_time_zone_database(Zoneinfo.TimeZoneDatabase)
      iex> DateTime.now!("Europe/Copenhagen")
      #DateTime<2021-07-24 12:56:38.324705+02:00 CEST Europe/Copenhagen>

  """

  @behaviour Calendar.TimeZoneDatabase
  import Zoneinfo.Utils

  @impl Calendar.TimeZoneDatabase
  def time_zone_period_from_utc_iso_days(iso_days, time_zone) do
    case Zoneinfo.Cache.get(time_zone) do
      {:ok, tzif} ->
        iso_days_to_gregorian_seconds(iso_days)
        |> find_period_for_utc_secs(tzif.periods)

      _ ->
        {:error, :time_zone_not_found}
    end
  end

  @impl Calendar.TimeZoneDatabase
  def time_zone_periods_from_wall_datetime(naive_datetime, time_zone) do
    case Zoneinfo.Cache.get(time_zone) do
      {:ok, tzif} ->
        {seconds, _micros} = NaiveDateTime.to_gregorian_seconds(naive_datetime)
        find_period_for_wall_secs(seconds, tzif.periods)

      _ ->
        {:error, :time_zone_not_found}
    end
  end

  @doc """
  Return the time zone database version

  This attempts to read `<tzpath>/version` and returns `:unknown` if non-existent.
  This allows external libraries to provide the version of TZ compiled that is
  currently being used with Zoneinfo
  """
  @spec version() :: String.t() | :unknown
  def version() do
    case File.read([Zoneinfo.tzpath(), "/version"]) do
      {:ok, ver} -> String.trim(ver)
      _ -> :unknown
    end
  end

  defp find_period_for_utc_secs(secs, periods) do
    period = Enum.find(periods, fn {time, _, _, _} -> secs >= time end)
    {:ok, period_to_map(period)}
  end

  # receives wall gregorian seconds (also referred as the 'given timestamp' in the comments below)
  # and the list of transitions
  defp find_period_for_wall_secs(_, [period]), do: {:ok, period_to_map(period)}

  defp find_period_for_wall_secs(wall_secs, [
         period = {utc_secs, utc_off, std_off, _},
         prev_period = {_ts2, prev_utc_off, prev_std_off, _}
         | tail
       ]) do
    period_start_wall_secs = utc_secs + utc_off + std_off
    prev_period_end_wall_secs = utc_secs + prev_utc_off + prev_std_off

    case {wall_secs >= period_start_wall_secs, wall_secs >= prev_period_end_wall_secs} do
      {false, false} ->
        # Try next earlier period
        find_period_for_wall_secs(wall_secs, [prev_period | tail])

      {true, true} ->
        # Contained in this period
        {:ok, period_to_map(period)}

      {false, true} ->
        # Time leaped forward and this is in the gap between periods
        {:gap,
         {period_to_map(prev_period),
          gregorian_seconds_to_naive_datetime(prev_period_end_wall_secs)},
         {period_to_map(period), gregorian_seconds_to_naive_datetime(period_start_wall_secs)}}

      {true, false} ->
        # Time fell back and this is in both periods
        {:ambiguous, period_to_map(prev_period), period_to_map(period)}
    end
  end

  defp period_to_map({_timestamp, utc_off, std_off, abbr}) do
    %{
      utc_offset: utc_off,
      std_offset: std_off,
      zone_abbr: abbr
    }
  end
end
