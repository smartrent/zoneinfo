defmodule Zoneinfo.Meta do
  alias Zoneinfo.TZif

  @moduledoc """
  Metadata derived from TZif information

  The metadata here is mostly useful for checking the quality of the TZif files that
  were loaded.
  """
  defstruct [:time_zone, :tz_string, :earliest_record_utc, :latest_record_utc, :record_count]

  @typedoc """
  Zoneinfo.Meta contains information about one time zone

  * `:time_zone` - the name of the time zone
  * `:tz_string` - if a POSIX TZ string is available, this is it
  * `:earliest_record_utc` - the UTC time of the earliest time zone record
  * `:latest_record_utc` - the UTC time of the latest time zone record
  * `:record_count` -- the number of records
  """
  @type t() :: %__MODULE__{
          time_zone: String.t(),
          tz_string: String.t() | nil,
          earliest_record_utc: NaiveDateTime.t(),
          latest_record_utc: NaiveDateTime.t(),
          record_count: non_neg_integer()
        }

  @doc false
  @spec to_meta(String.t(), TZif.t()) :: t()
  def to_meta(time_zone, tzif) do
    %__MODULE__{
      time_zone: time_zone,
      tz_string: tzif.tz_string,
      earliest_record_utc: ndt(Enum.at(tzif.periods, -2)),
      latest_record_utc: ndt(List.first(tzif.periods)),
      # The last record is the default for times before the first known one, so
      # it doesn't really count
      record_count: length(tzif.periods)
    }
  end

  defp ndt({gregorian_seconds, _utc_offset, _std_offset, _zone_abbr}) do
    Zoneinfo.Utils.gregorian_seconds_to_naive_datetime(gregorian_seconds)
  end
end
