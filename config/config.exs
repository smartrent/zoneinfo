import Config

config :elixir, time_zone_database: Zoneinfo.TimeZoneDatabase

# Comment out this line to test with the OS database
config :zoneinfo, tzpath: Path.expand(Path.join(Mix.Project.compile_path(), "../priv/zoneinfo"))

# Turn off autoupdate on tzdata since if we're comparing our results with its
# results (See @truth in unit tests), we don't want it updating its database to
# something newer. See the Makefile for which timezone the unit tests use.
config :tzdata, :autoupdate, :disabled

config :tz, build_time_zone_periods_with_ongoing_dst_changes_until_year: 2039
