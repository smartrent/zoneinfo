# Changelog

## v0.1.3

* Improvements
  * UTC and standard time offsets are now tested for consistency with Tz.
    Normally you just want the overall offset from UTC and that was already
    tested (this is what's used in the DateTime calculations). The TZif data
    doesn't split out the offsets, but it turned out that a heuristic works
    really well.
  * Unit tests run quickly. Thorough tests are available via `mix test --include
    slow`

* Bug fixes
  * Fixed UTC and standard time offsets discrepancies with Tz (and hence the IANA
    rules database). The only known exceptions now are Paris and Monoco in the
    mid-1940s and Morocco. See the unit tests for discussion on the differences.

## v0.1.2

* New features
  * Add `Zoneinfo.get_metadata/1` to expose diagnostic information useful for
    sanity checking date ranges available on a system

## v0.1.1

* New features
  * Add `Zoneinfo.valid_time_zone?/1` to quickly check if a time zone is in the
    database

## v0.1.0

Initial release to hex.
