defmodule Zoneinfo.TimeZoneDatabaseTest do
  use ExUnit.Case, async: true
  import Zoneinfo.Utils

  @truth Tz

  # Set these to the range of times that are important
  # Make sure that the Makefile generates tzif files that include
  # range.
  @earliest_time ~N[1940-01-02 00:00:00]
  @latest_time ~N[2038-01-01 00:00:00]

  defp step_size(time_zone) do
    # Vary the step size deterministically per time zone to try to
    # cover a few more boundary conditions
    nominal_step_size = 7 * 60 * 60 * 24

    nominal_step_size + :erlang.phash2(time_zone, div(nominal_step_size, 4)) -
      div(nominal_step_size, 8)
  end

  defp check_time_zone(time_zone, time, end_time, step_size) do
    iso_days =
      Calendar.ISO.naive_datetime_to_iso_days(
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
        time.second,
        {0, 6}
      )

    next_time = NaiveDateTime.add(time, step_size)

    zoneinfo_result =
      Zoneinfo.TimeZoneDatabase.time_zone_period_from_utc_iso_days(iso_days, time_zone)

    expected_result =
      @truth.TimeZoneDatabase.time_zone_period_from_utc_iso_days(iso_days, time_zone)

    assert same_results?(zoneinfo_result, expected_result), """
    Assertion failed for #{time_zone} @ #{inspect(time)}

    iso_days=#{inspect(iso_days)}
    gregorian_seconds=#{inspect(iso_days_to_gregorian_seconds(iso_days))}

    Zoneinfo returned #{inspect(zoneinfo_result)}
    #{@truth |> to_string() |> String.trim_leading("Elixir.")}     returned #{
      inspect(expected_result)
    }
    """

    if NaiveDateTime.compare(next_time, end_time) == :lt do
      check_time_zone(time_zone, next_time, end_time, step_size)
    end
  end

  for time_zone <- Zoneinfo.time_zones() do
    test "zoneinfo consistent for #{time_zone} for utc iso days" do
      check_time_zone(
        unquote(time_zone),
        @earliest_time,
        @latest_time,
        step_size(unquote(time_zone))
      )
    end
  end

  defp same_period?(
         %{std_offset: s, utc_offset: u, zone_abbr: z},
         %{std_offset: s, utc_offset: u, zone_abbr: z}
       ),
       do: true

  # TODO: Debug why this is different sometimes.
  defp same_period?(
         %{std_offset: tzf1, utc_offset: tzf2, zone_abbr: z},
         %{std_offset: tz1, utc_offset: tz2, zone_abbr: z}
       )
       when tzf1 + tzf2 == tz1 + tz2,
       do: true

  defp same_period?(_a, _b), do: false

  defp same_results?({:ok, p1}, {:ok, p2}) do
    same_period?(p1, p2)
  end

  defp same_results?({:gap, {ap1, t1}, {ap2, t2}}, {:gap, {bp1, t1}, {bp2, t2}}) do
    same_period?(ap1, bp1) and same_period?(ap2, bp2)
  end

  defp same_results?({:ambiguous, ap1, ap2}, {:ambiguous, bp1, bp2}) do
    same_period?(ap1, bp1) and same_period?(ap2, bp2)
  end

  defp same_results?(a, b), do: a == b

  defp check_wall_clock(time_zone, time, end_time, step_size) do
    next_time = NaiveDateTime.add(time, step_size)

    zoneinfo_result =
      Zoneinfo.TimeZoneDatabase.time_zone_periods_from_wall_datetime(time, time_zone)

    expected_result =
      @truth.TimeZoneDatabase.time_zone_periods_from_wall_datetime(time, time_zone)

    assert same_results?(zoneinfo_result, expected_result), """
    Assertion failed for #{time_zone} @ #{inspect(time)}


    Zoneinfo returned #{inspect(zoneinfo_result)}
    #{@truth |> to_string() |> String.trim_leading("Elixir.")}     returned #{
      inspect(expected_result)
    }
    """

    if NaiveDateTime.compare(next_time, end_time) == :lt do
      check_wall_clock(time_zone, next_time, end_time, step_size)
    end
  end

  for time_zone <- Zoneinfo.time_zones() do
    test "zoneinfo consistent for #{time_zone} for wall clock inputs" do
      check_wall_clock(
        unquote(time_zone),
        @earliest_time,
        @latest_time,
        step_size(unquote(time_zone))
      )
    end
  end

  # test "time_zone period from utc iso days", %{time_zones: time_zones} do
  #   ndt_now = NaiveDateTime.local_now()

  #   for time_zone <- time_zones do
  #     for delta_days <- Enum.take_every(0..10000, 30) do
  #       delta_seconds = delta_days * 24 * 60 * 60 * -1
  #       ndt = NaiveDateTime.add(ndt_now, delta_seconds, :second)

  #       iso_days =
  #         Calendar.ISO.naive_datetime_to_iso_days(
  #           ndt.year,
  #           ndt.month,
  #           ndt.day,
  #           ndt.hour,
  #           ndt.minute,
  #           ndt.second,
  #           {0, 6}
  #         )

  #       case Tz.TimeZoneDatabase.time_zone_period_from_utc_iso_days(iso_days, time_zone) do
  #         {:ok,
  #          %{
  #            std_offset: std_offset,
  #            utc_offset: utc_offset,
  #            zone_abbr: abbr
  #          }} ->
  #           # assuming largest std offset i 1 hour
  #           assert abs(std_offset) in 0..(60 * 60)
  #           # largest utc offset is 14 hours
  #           assert abs(utc_offset) in 0..(14 * 60 * 60)
  #           assert is_binary(abbr)

  #         {:error, :time_zone_not_found} ->
  #           IO.puts("Time zone not found #{time_zone}")
  #           assert false
  #       end
  #     end
  #   end
  # end

  # test "time_zone period from wall date time", %{time_zones: time_zones} do
  #   ndt_now = NaiveDateTime.local_now()

  #   for time_zone <- time_zones do
  #     for delta_days <- Enum.take_every(0..10000, 30) do
  #       delta_seconds = delta_days * 24 * 60 * 60 * -1
  #       ndt = NaiveDateTime.add(ndt_now, delta_seconds, :second)

  #       case Tz.TimeZoneDatabase.time_zone_periods_from_wall_datetime(ndt, time_zone) do
  #         {:ok,
  #          %{
  #            std_offset: std_offset,
  #            utc_offset: utc_offset,
  #            zone_abbr: abbr
  #          }} ->
  #           # assuming largest std offset i 1 hour
  #           assert abs(std_offset) in 0..(60 * 60)
  #           # largest utc offset is 14 hours
  #           assert abs(utc_offset) in 0..(14 * 60 * 60)
  #           assert is_binary(abbr)

  #         {:error, :time_zone_not_found} ->
  #           IO.puts("Time zone not found #{time_zone}")
  #           assert false
  #       end
  #     end
  #   end
  # end
end
