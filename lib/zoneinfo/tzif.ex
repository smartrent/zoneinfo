defmodule Zoneinfo.TZif do
  @magic "TZif"

  @moduledoc false

  @typedoc """
  {from, ut_offset, name, std or dst, wall or std, local or ut}
  """
  @type period() ::
          {integer(), Calendar.utc_offset(), Calendar.std_offset(), Calendar.zone_abbr()}

  defstruct [:version, :periods, :tz_string]
  @type t() :: %__MODULE__{version: 1..3, periods: [period()], tz_string: String.t() | nil}

  @doc """
  Parse TZif data
  """
  # @spec parse(binary()) :: {:ok, t()} | {:error, :invalid}
  def parse(data) when is_binary(data) do
    token = {%__MODULE__{}, data}

    case version(data) do
      {:ok, 1} ->
        token
        |> parse_v1_data()
        |> format_result()

      {:ok, _two_plus} ->
        token
        |> skip_v1_data()
        |> parse_v2_data()
        |> parse_footer()
        |> format_result()

      error ->
        error
    end
  end

  defp format_result({nil, _rest}), do: {:error, :invalid}
  defp format_result({result, _rest}), do: {:ok, result}

  @doc """
  Return the TZif version
  """
  @spec version(any) :: {:error, :invalid} | {:ok, 1..9}
  def version(<<@magic, 0, _rest::binary>>), do: {:ok, 1}

  def version(<<@magic, version, _rest::binary>>) when version >= ?2 and version <= ?9,
    do: {:ok, version - ?0}

  def version(_anything_else) do
    {:error, :invalid}
  end

  defp parse_v1_data(
         {tzif,
          <<@magic, _version, _unused::15-bytes, isutcnt::32, isstdcnt::32, leapcnt::32,
            timecnt::32, typecnt::32, charcnt::32,
            transition_times::unit(32)-size(timecnt)-binary,
            transition_types::unit(8)-size(timecnt)-binary,
            local_time_types::unit(48)-size(typecnt)-binary,
            time_zone_designations::unit(8)-size(charcnt)-binary,
            _leap_second_records::unit(64)-size(leapcnt)-binary,
            standard_indicators::unit(8)-size(isstdcnt)-binary,
            ut_indicators::unit(8)-size(isutcnt)-binary, rest::binary()>>}
       ) do
    new_tzif = %{
      tzif
      | version: 1,
        periods:
          decode_transition_times(
            32,
            transition_times,
            transition_types,
            local_time_types,
            time_zone_designations,
            standard_indicators,
            ut_indicators
          )
    }

    {new_tzif, rest}
  end

  defp parse_v1_data(_other) do
    {nil, nil}
  end

  defp skip_v1_data(
         {tzif,
          <<@magic, _version, _unused::15-bytes, isutcnt::32, isstdcnt::32, leapcnt::32,
            timecnt::32, typecnt::32, charcnt::32,
            _transition_times::unit(32)-size(timecnt)-binary,
            _transition_types::unit(8)-size(timecnt)-binary,
            _local_time_types::unit(48)-size(typecnt)-binary,
            _time_zone_designations::unit(8)-size(charcnt)-binary,
            _leap_second_records::unit(64)-size(leapcnt)-binary,
            _standard_indicators::unit(8)-size(isstdcnt)-binary,
            _ut_indicators::unit(8)-size(isutcnt)-binary, rest::binary()>>}
       ) do
    {tzif, rest}
  end

  defp skip_v1_data(_other) do
    {nil, nil}
  end

  defp parse_v2_data(
         {tzif,
          <<@magic, version, _unused::15-bytes, isutcnt::32, isstdcnt::32, leapcnt::32,
            timecnt::32, typecnt::32, charcnt::32,
            transition_times::unit(64)-size(timecnt)-binary,
            transition_types::unit(8)-size(timecnt)-binary,
            local_time_types::unit(48)-size(typecnt)-binary,
            time_zone_designations::unit(8)-size(charcnt)-binary,
            _leap_second_records::unit(96)-size(leapcnt)-binary,
            standard_indicators::unit(8)-size(isstdcnt)-binary,
            ut_indicators::unit(8)-size(isutcnt)-binary, rest::binary()>>}
       ) do
    new_tzif = %{
      tzif
      | version: version - ?0,
        periods:
          decode_transition_times(
            64,
            transition_times,
            transition_types,
            local_time_types,
            time_zone_designations,
            standard_indicators,
            ut_indicators
          )
    }

    {new_tzif, rest}
  end

  defp parse_v2_data(_other) do
    {nil, nil}
  end

  defp parse_footer({_tzif, <<>>} = token), do: token

  defp parse_footer({tzif, <<?\n, footer::binary>>}) do
    case String.split(footer, "\n", parts: 2) do
      [tz_string, _rest] ->
        {%{tzif | tz_string: tz_string}, <<>>}

      _other ->
        # This is unexpected, so error out.
        {nil, nil}
    end
  end

  defp parse_footer(_other) do
    {nil, nil}
  end

  defp decode_transition_times(
         size,
         transition_times,
         transition_types,
         local_time_types,
         raw_tz_designations,
         _standard_indicators,
         _ut_indicators
       ) do
    times = for <<time::signed-size(size) <- transition_times>>, do: to_gregorian_seconds(time)

    lt_record =
      for <<utoff::signed-32, dst, tz_index <- local_time_types>> do
        {utoff, get_tz_abbr(raw_tz_designations, tz_index), std_or_dst(dst)}
      end

    {first_utoff, first_abbr, _} = hd(lt_record)
    prehistory_record = {-2_147_483_647, first_utoff, 0, first_abbr}

    types = for <<type <- transition_types>>, do: Enum.at(lt_record, type)
    guess = first_utc_offset(types, nil)

    process_records(times, types, guess, [prehistory_record])
  end

  # Use either the first record marked :std or
  defp first_utc_offset([{0, "-00", :std} | rest], guess) do
    first_utc_offset(rest, guess)
  end

  defp first_utc_offset([{offset, _tz_abbrev, :std} | _rest], _guess), do: offset

  defp first_utc_offset([{offset, _tz_abbrev, :dst} | rest], nil),
    do: first_utc_offset(rest, offset + 3600)

  defp first_utc_offset([_record | rest], guess), do: first_utc_offset(rest, guess)
  defp first_utc_offset([], guess), do: guess

  defp process_records([time | times], [{0, "-00", :std} | infos], st_offset, acc) do
    # Unknown offset is represented by "-00"
    process_records(times, infos, st_offset, [{time, 0, 0, "-00"} | acc])
  end

  defp process_records([time | times], [{offset, tz_abbrev, :std} | infos], _st_offset, acc) do
    record = {time, offset, 0, tz_abbrev}
    process_records(times, infos, offset, [record | acc])
  end

  defp process_records(
         [time, time2 | times],
         [{offset, tz_abbrev, :dst}, {next_st_offset, tz_abbrev2, :std} | infos],
         prev_st_offset,
         acc
       ) do
    std_offset =
      cond do
        # Common case of no offset change
        prev_st_offset == next_st_offset and offset - prev_st_offset != 0 -> prev_st_offset
        # DST should have an offset from the UTC offset. If it doesn't, then make it be 1 hour
        offset - next_st_offset == 0 and offset - prev_st_offset == 0 -> offset - 3600
        # Prefer a DST with an offset from UTC
        offset - next_st_offset == 0 -> prev_st_offset
        offset - prev_st_offset == 0 -> next_st_offset
        # Prefer a DST with a positive offset from UTC
        offset - prev_st_offset < 0 and offset - next_st_offset > 0 -> next_st_offset
        offset - prev_st_offset > 0 and offset - next_st_offset < 0 -> prev_st_offset
        # Pick the smaller DST offset
        abs(offset - next_st_offset) < abs(offset - prev_st_offset) -> next_st_offset
        # Punt
        true -> prev_st_offset
      end

    record1 = {time, std_offset, offset - std_offset, tz_abbrev}
    record2 = {time2, next_st_offset, 0, tz_abbrev2}

    process_records(times, infos, next_st_offset, [record2, record1 | acc])
  end

  defp process_records([time | times], [{offset, tz_abbrev, :dst} | infos], prev_st_offset, acc) do
    record = {time, prev_st_offset, offset - prev_st_offset, tz_abbrev}

    process_records(times, infos, prev_st_offset, [record | acc])
  end

  defp process_records([], [], _prev_st_offset, acc), do: acc

  defp to_gregorian_seconds(unix_time) do
    unix_time + 62_167_219_200
  end

  defp std_or_dst(0), do: :std
  defp std_or_dst(_), do: :dst

  defp get_tz_abbr(raw_tz_designations, index) do
    raw_tz_designations
    |> :binary.bin_to_list()
    |> Enum.drop(index)
    |> take_til_null()
    |> to_string()
  end

  defp take_til_null(string, acc \\ [])

  defp take_til_null([0 | _rest], acc) do
    acc
    |> Enum.reverse()
  end

  defp take_til_null([c | rest], acc) do
    take_til_null(rest, [c | acc])
  end
end
