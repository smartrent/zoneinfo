defmodule Zoneinfo.MetaTest do
  use ExUnit.Case

  alias Zoneinfo.Meta

  @fixture_path Path.join(__DIR__, "../fixture")

  defp parse_file(name) do
    Path.join(@fixture_path, name)
    |> File.read!()
    |> Zoneinfo.TZif.parse()
  end

  test "to_meta/2" do
    {:ok, tzif} = parse_file("Honolulu_v2")
    meta = Meta.to_meta("America/Honolulu", tzif)

    assert meta.time_zone == "America/Honolulu"
    assert meta.tz_string == "HST10"
    assert meta.earliest_record_utc == ~N[1896-01-13 22:31:26]
    # Yes, this looks strange. The file was shortened on purpose
    assert meta.latest_record_utc == ~N[1947-06-08 12:30:00]
    assert meta.record_count == 8
  end
end
