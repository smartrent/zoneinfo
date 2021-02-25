defmodule Zoneinfo.TZif do
  @magic "TZif"

  @moduledoc false

  @typedoc """
  {from, ut_offset, name, std or dst, wall or std, local or ut}
  """
  @type period() ::
          {integer(), Calendar.utc_offset(), Calendar.std_offset(), Calendar.zone_abbr()}

  defstruct [:version, :periods, :tz_string]
  @type t() :: %__MODULE__{version: 1..3, periods: period()}

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
         standard_indicators,
         ut_indicators
       ) do
    times = for <<time::signed-size(size) <- transition_times>>, do: to_gregorian_seconds(time)

    lt_record =
      for <<utoff::signed-32, dst, tz_index <- local_time_types>> do
        {utoff, get_tz_abbr(raw_tz_designations, tz_index), std_or_dst(dst)}
      end

    num_lt_records = length(lt_record)
    std_wall = process_standard_indicators(standard_indicators, num_lt_records)
    ut_local = process_ut_indicators(ut_indicators, num_lt_records)

    {first_utoff, first_abbr, _} = hd(lt_record)
    prehistory_record = {-2_147_483_647, first_utoff, 0, first_abbr}

    lt_record_w_extra = Enum.zip([lt_record, std_wall, ut_local])
    types = for <<type <- transition_types>>, do: Enum.at(lt_record_w_extra, type)

    process_records(times, types, 0, [prehistory_record])
  end

  defp process_records([], [], _st_offset, acc), do: acc

  defp process_records(
         [time | times],
         [{{utoff, tz_designation, dst}, _std_wall, _ut_local} | infos],
         st_offset,
         acc
       ) do
    new_st_offset = if dst == :std, do: utoff, else: st_offset

    record = {time, new_st_offset, utoff - new_st_offset, tz_designation}
    # IO.puts("#{inspect(record)} #{inspect(dst)} #{std_wall} #{ut_local}")
    process_records(times, infos, new_st_offset, [record | acc])
  end

  defp to_gregorian_seconds(unix_time) do
    unix_time + 62_167_219_200
  end

  defp process_standard_indicators(<<>>, expected) do
    List.duplicate(:wall_time, expected)
  end

  defp process_standard_indicators(standard_indicators, _expected) do
    for <<b <- standard_indicators>>, do: to_stdwall(b)
  end

  defp process_ut_indicators(<<>>, expected) do
    List.duplicate(:local, expected)
  end

  defp process_ut_indicators(ut_indicators, _expected) do
    for <<b <- ut_indicators>>, do: to_ut_local(b)
  end

  defp std_or_dst(0), do: :std
  defp std_or_dst(_), do: :dst

  defp to_stdwall(0), do: :wall_time
  defp to_stdwall(_), do: :std_time

  defp to_ut_local(0), do: :local
  defp to_ut_local(_), do: :ut

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
