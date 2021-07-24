defmodule Zoneinfo.MixProject do
  use Mix.Project

  @version "0.1.4"
  @source_url "https://github.com/smartrent/zoneinfo"

  def project do
    [
      app: :zoneinfo,
      version: @version,
      elixir: "~> 1.11",
      description: description(),
      package: package(),
      compilers: compilers(Mix.env()),
      aliases: aliases(),
      make_targets: ["all"],
      make_clean: ["clean"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        flags: [:unmatched_returns, :error_handling, :race_conditions, :underspecs]
      ],
      docs: docs(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  defp aliases() do
    [bench: ["run bench/bench.exs"]]
  end

  def compilers(env) when env in [:dev, :test] do
    [:elixir_make | Mix.compilers()]
  end

  def compilers(_env), do: Mix.compilers()

  def application() do
    [mod: {Zoneinfo.Application, []}]
  end

  defp description do
    "Elixir time zone support that uses OS-supplied zoneinfo files"
  end

  defp package do
    %{
      # The file list is the default minus the Makefile which is only for dev/test
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE",
        "CHANGELOG.md"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp deps do
    [
      # No prod dependencies. These are only for dev and test.
      {:benchee, "~> 1.0", only: :dev},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:elixir_make, "> 0.6.0", only: [:dev, :test]},
      # Locked dependencies to guarantee that tz and tzdata use the same IANA time zone database
      # It's ok to update. Change the version in the Makefile.
      {:tz, "~> 0.12.0", only: [:dev, :test]},
      {:tzdata, "~> 1.1.0", only: [:dev, :test]}
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
