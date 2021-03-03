from_utc_jobs = %{
  "Tzdata" => fn {iso_days, time_zone} ->
    Tzdata.TimeZoneDatabase.time_zone_period_from_utc_iso_days(iso_days, time_zone)
  end,
  "Tz" => fn {iso_days, time_zone} ->
    Tz.TimeZoneDatabase.time_zone_period_from_utc_iso_days(iso_days, time_zone)
  end,
  "Zoneinfo" => fn {iso_days, time_zone} ->
    Zoneinfo.TimeZoneDatabase.time_zone_period_from_utc_iso_days(iso_days, time_zone)
  end
}

ndt_to_iso = fn ndt ->
  Calendar.ISO.naive_datetime_to_iso_days(
    ndt.year,
    ndt.month,
    ndt.day,
    ndt.hour,
    ndt.minute,
    ndt.second,
    {0, 6}
  )
end

inputs = [
  {"converting now", {ndt_to_iso.(NaiveDateTime.utc_now()), "America/New_York"}}
]

Benchee.run(from_utc_jobs,
  #  parallel: 4,
  warmup: 5,
  time: 30,
  memory_time: 1,
  inputs: inputs,
  formatters: [Benchee.Formatters.Console]
)
