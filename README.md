# Zoneinfo

[![Hex version](https://img.shields.io/hexpm/v/zoneinfo.svg "Hex version")](https://hex.pm/packages/zoneinfo)
[![CircleCI](https://circleci.com/gh/smartrent/zoneinfo.svg?style=svg)](https://circleci.com/gh/smartrent/zoneinfo)

Elixir time zone support for your OS-supplied zoneinfo files

Why Zoneinfo?

* Reuse your OS-maintained time zone database (usually in `/usr/share/zoneinfo`)
* Reduce your OTP release size by not bundling time zone data
* Load other [TZif](https://tools.ietf.org/html/rfc8536) files

Why not Zoneinfo?

* [`tzdata`](http://hex.pm/packages/tzdata) and
  [`tz`](http://hex.pm/packages/tz) work fine for you
* You can't rely on your OS to update time zone files and don't want to
  implement this yourself
* You're running on Windows (the zoneinfo database can still be installed, but
  this is not a typical configuration)
* You need to extrapolate time zone conversions far in the future or past.
  Zoneinfo currently is limited to the ranges in TZif files which typically go
  to 2038.
* Speed is of utmost importance. Zoneinfo loads time zones on demand and caches
  them, but it does not focus on performance like `tz`.

Zoneinfo is tested for consistency against the `tz` library. It's possible to
test against `tzdata` by modifying `@truth` in the unit tests. All libraries
source their information from the [IANA Time Zone
Database](http://www.iana.org/time-zones)

## Installation

First, add `:zoneinfo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoneinfo, "~> 0.1.0"}
  ]
end
```

Next, decide whether you want to configure Elixir to use Zoneinfo as the default
time zone lookup. If you do, add the following line to your `config.exs`:

```elixir
config :elixir, time_zone_database: Zoneinfo.TimeZoneDatabase
```

or call `Calendar.put_time_zone_database/1`:

```elixir
Calendar.put_time_zone_database(Zoneinfo.TimeZoneDatabase)
```

It's also possible to pass `Zoneinfo.TimeZoneDatabase` to `DateTime` functions to
avoid the global configuration.

The final step is to specify the location of the time zone files. Zoneinfo looks
at the following locations:

1. The `:tzpath` key in the application environment
2. The `TZDIR` environment variable
3. `/usr/share/zoneinfo`

Since `/usr/share/zoneinfo` is the default on Linux and OSX, you may not need to
do anything.

To set `:tzpath` in the application environment, add this line to your
`config.exs`:

```elixir
config :zoneinfo, tzpath: "/custom/location"
```

## Notes and caveats

### Caching

While Zoneinfo does not contain a database and therefore has no logic to pull
updates, it does cache data in memory for better performance. It flushes the
cache daily so that it's possible to pick up changes to the system timezone
data.

### Date ranges

Zoneinfo uses the date ranges stored in the TZif data for determining time zone
information. While TZif files support extrapolation of dates beyond what's
stored, Zoneinfo currently does not use it. This means that dates far enough in
the future won't be calculated correctly.

The default end date from the time zone compiler,
[zic(8)](https://data.iana.org/time-zones/tzdb/zic.8.txt), is 2038. This could,
of course, could change and one would hope that it would be pushed farther out
rather than reduced since the files are already pretty small.

If you're looking at creating the smallest possible time zone database for and
embedded system, using `zic`'s `-r` flag helps significantly, but make sure that
you have enough buffer to avoid extrapolation.

### Unit tests

The tests currently take a long time to run since they're checking a LOT of
dates and times. If you're working on a patch, you may want to limit the date
range in `time_zone_database_test.exs` to 10 years or less.

## Acknowledgments

Both [`tz`](http://hex.pm/packages/tz) and
[`tzdata`](http://hex.pm/packages/tzdata) were both extremely helpful in
answering time zone questions. Code in this library will almost certainly look
like it was influenced from the two libraries. Additionally, being able to
compare the output of Zoneinfo to the output of those libraries caught a few
subtle time zone handling bugs that could easily have gone unnoticed. The [IANA
time zone rules database comments](https://www.iana.org/time-zones) and
[timeanddate.com](https://www.timeanddate.com/time/change/) were also extremely
helpful to resolve discrepancies.

## License

Copyright (C) 2021 SmartRent.com, LLC

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
