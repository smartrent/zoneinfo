defmodule Zoneinfo.TimeZoneDatabaseTest do
  use ExUnit.Case, async: true
  import Zoneinfo.Utils

  @truth Tz

  # Set these to the range of times that are important
  # Make sure that the Makefile generates tzif files that include range.
  @earliest_time ~N[1940-01-02 00:00:00]
  @latest_time ~N[2038-01-01 00:00:00]

  # This is a list of known utc_offset discrepancies with Tz
  #
  # The total time zone offset (utc_offset + std_offset) is correct so time
  # zone conversions will return the right answer. However, the utc_offset and
  # std_offset differ from Tz.
  @std_offset_discrepancies %{
    # Europe/Monaco and Europe/Paris
    #
    # Zoneinfo returned {:ok, %{std_offset: 3600, utc_offset: 3600, zone_abbr: "WEMT"}}
    # Tz       returned {:ok, %{std_offset: 7200, utc_offset: 0, zone_abbr: "WEMT"}}
    #
    # Tz is right. The UTC offset heuristic messes up since the right answer is
    # a 2 hour DST offset. There's a nearby standard time offset that would be
    # 1 hour in both cases and the heuristic rules prioritize matching that
    # one. You can tell by comparing zone abbreviations that the real one is
    # the 2 hour offset.
    "Europe/Monaco" => [1945],
    "Europe/Paris" => 1944..1945,

    # Africa/Casablanca and Africa/El_Aaiun
    #
    # Zoneinfo returned {:ok, %{std_offset: 3600, utc_offset: -3600, zone_abbr: "+00"}}
    # Tz       returned {:ok, %{std_offset: -3600, utc_offset: 3600, zone_abbr: "+00"}}
    #
    # Casablanca and El Aaiun are on DST (+01) most of the year and then drops
    # back to standard time (+00) for Ramadan. I think that both Zoneinfo and
    # Tz are wrong. Since it's a standard time, it seems like std_offset should
    # be 0. Unfortunately, the TZif file marks the time zone records as "dst"
    # which I think is an artifact of the IANA rules database hardcoding the
    # start and end dates.
    "Africa/Casablanca" => 2019..2037,
    "Africa/El_Aaiun" => 2019..2037
  }

  defp step_size(time_zone) do
    # Vary the step size deterministically per time zone to try to cover a few
    # more boundary conditions
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

    context = {time_zone, time.year}

    assert same_results?(context, zoneinfo_result, expected_result), """
    Assertion failed for #{time_zone} @ #{inspect(time)}

    iso_days=#{inspect(iso_days)}
    gregorian_seconds=#{inspect(iso_days_to_gregorian_seconds(iso_days))}

    Zoneinfo returned #{inspect(zoneinfo_result)}
    #{@truth |> to_string() |> String.trim_leading("Elixir.")}       returned #{
      inspect(expected_result)
    }

    Add #{inspect(context)} to known discrepancy if this needs to be ignored
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
         _context,
         %{std_offset: s, utc_offset: u, zone_abbr: z},
         %{std_offset: s, utc_offset: u, zone_abbr: z}
       ),
       do: true

  defp same_period?(
         context,
         %{std_offset: tzf1, utc_offset: tzf2, zone_abbr: z},
         %{std_offset: tz1, utc_offset: tz2, zone_abbr: z}
       )
       when tzf1 + tzf2 == tz1 + tz2 do
    # Time zone calculations will work since the sum of the two gets the right
    # answer. Elixir's calendar computations currently always sum the two.
    #
    # However, if a user's program needs to know the utc offset or the offset
    # from standard time, it will get the wrong answer.
    #
    # If we know about the discrepancy, return that the answer is good.
    {time_zone, year} = context

    case @std_offset_discrepancies[time_zone] do
      nil -> false
      years -> year in years
    end
  end

  defp same_period?(_context, _a, _b), do: false

  defp same_results?(context, {:ok, p1}, {:ok, p2}) do
    same_period?(context, p1, p2)
  end

  defp same_results?(context, {:gap, {ap1, t1}, {ap2, t2}}, {:gap, {bp1, t1}, {bp2, t2}}) do
    same_period?(context, ap1, bp1) and same_period?(context, ap2, bp2)
  end

  defp same_results?(context, {:ambiguous, ap1, ap2}, {:ambiguous, bp1, bp2}) do
    same_period?(context, ap1, bp1) and same_period?(context, ap2, bp2)
  end

  defp same_results?(_context, a, b), do: a == b

  defp check_wall_clock(time_zone, time, end_time, step_size) do
    next_time = NaiveDateTime.add(time, step_size)

    zoneinfo_result =
      Zoneinfo.TimeZoneDatabase.time_zone_periods_from_wall_datetime(time, time_zone)

    expected_result =
      @truth.TimeZoneDatabase.time_zone_periods_from_wall_datetime(time, time_zone)

    context = {time_zone, time.year}

    assert same_results?(context, zoneinfo_result, expected_result), """
    Assertion failed for #{time_zone} @ #{inspect(time)}


    Zoneinfo returned #{inspect(zoneinfo_result)}
    #{@truth |> to_string() |> String.trim_leading("Elixir.")}       returned #{
      inspect(expected_result)
    }

    Add #{inspect(context)} to known discrepancy if this needs to be ignored
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
