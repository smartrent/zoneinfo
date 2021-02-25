defmodule Zoneinfo.Utils do
  @moduledoc false

  @spec iso_days_to_gregorian_seconds(Calendar.iso_days()) :: integer()
  def iso_days_to_gregorian_seconds({days, {parts_in_day, 86_400_000_000}}) do
    div(days * 86_400_000_000 + parts_in_day, 1_000_000)
  end

  @spec gregorian_seconds_to_naive_datetime(non_neg_integer()) :: NaiveDateTime.t()
  def gregorian_seconds_to_naive_datetime(seconds) do
    :calendar.gregorian_seconds_to_datetime(seconds)
    |> NaiveDateTime.from_erl!()
  end
end
