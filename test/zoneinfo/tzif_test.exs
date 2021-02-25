defmodule Zoneinfo.TZifTest do
  use ExUnit.Case, async: true

  alias Zoneinfo.TZif

  @fixture_path Path.join(__DIR__, "../fixture")

  defp parse_file(name) do
    Path.join(@fixture_path, name)
    |> File.read!()
    |> TZif.parse()
  end

  test "loads v1 files" do
    {:ok, tzif} = parse_file("Honolulu_v1")

    assert tzif.version == 1
    assert length(tzif.periods) == 7
  end

  test "loads v2 files" do
    {:ok, tzif} = parse_file("Honolulu_v2")

    assert tzif.version == 2
    assert length(tzif.periods) == 8
    assert tzif.tz_string == "HST10"
  end

  test "is ok with missing v2 footer" do
    {:ok, tzif} = parse_file("Honolulu_v2_no_footer")

    assert tzif.version == 2
    assert length(tzif.periods) == 8
    assert tzif.tz_string == nil
  end

  test "rejects bad headers" do
    assert {:error, :invalid} = parse_file("bad_header")
  end

  test "rejects bad v1 count" do
    assert {:error, :invalid} = parse_file("Honolulu_v1_bad_count")
  end

  test "rejects bad v2 count" do
    # The bad count is in the v1 section
    assert {:error, :invalid} = parse_file("Honolulu_v2_bad_count")

    # The bad count is in the v2 section
    assert {:error, :invalid} = parse_file("Honolulu_v2_bad_count2")
  end

  test "rejects bad v2 footer" do
    assert {:error, :invalid} = parse_file("Honolulu_v2_bad_footer")
  end
end
