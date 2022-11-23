current = Zoneinfo.tz_version()

# iana_version/0 introduced in v0.17
fun = if function_exported?(Tz, :iana_version, 0), do: :iana_version, else: :version
tz = apply(Tz, fun, [])

if current != tz do
  Mix.raise("""
  The current TZVERSION compiled does not match the Tz library version
  and tests may not be considered valid:

    expected: #{tz}
    got: #{current}

  Please update :tz dependency for the version expected
  """)
end

ExUnit.start(exclude: [slow: true])

# Run the following for a more thorough test
# mix test --include slow
