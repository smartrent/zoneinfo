defmodule Zoneinfo.UtilsTest do
  use ExUnit.Case, async: true
  alias Zoneinfo.Utils

  test "iso_days_to_gregorian_seconds/1" do
    ndt = NaiveDateTime.local_now()

    iso_days =
      Calendar.ISO.naive_datetime_to_iso_days(
        ndt.year,
        ndt.month,
        ndt.day,
        ndt.hour,
        ndt.minute,
        ndt.second,
        ndt.microsecond
      )

    greg_seconds = Utils.iso_days_to_gregorian_seconds(iso_days)

    {expected_greg_seconds, _micros} = NaiveDateTime.to_gregorian_seconds(ndt)

    assert greg_seconds == expected_greg_seconds
  end

  test "datetime to gregorian and back" do
    ndt = NaiveDateTime.local_now()

    {secs, _micros} = NaiveDateTime.to_gregorian_seconds(ndt)
    output = Utils.gregorian_seconds_to_naive_datetime(secs)

    assert ndt == output
  end
end
