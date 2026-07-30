defmodule Xeger.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/joetjen/xeger"

  def project do
    [
      app: :xeger,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Xeger - generate strings that match a regex-like pattern (regex → strings).",
      package: package(),

      # Docs
      name: "Xeger",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),

      # Dialyzer
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp deps do
    [
      # === CODE QUALITY & STATIC ANALYSIS ===
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      # Credo is invoked via `MIX_ENV=test mix credo`
      # Dialyzer is invoked via `MIX_ENV=test mix dialyzer`
      # Sobelow is invoked via `MIX_ENV=test mix sobelow`
      # Coveralls is invoked via `MIX_ENV=test mix coveralls

      # === TESTING ===
      {:mox, "~> 1.2", only: [:dev, :test]},
      {:faker, "~> 0.19", only: [:test]},
      {:stream_data, "~> 1.4", only: [:test]},

      # === DEVELOPMENT TOOLING ===
      # Mix, and Hex are built-in (no deps needed)
      {:ex_doc, "~> 0.40", only: [:dev], runtime: false},
      # ExDoc is invoked via `MIX_ENV=dev mix docs`

      # `mix ichor.gen` compiles priv/grammar/xeger.aether to
      # lib/xeger/grammar.ex ahead of time (see that file's own
      # banner comment to regenerate it). Only the generator needs to be
      # a dev dependency -- the checked-in generated module only calls
      # into the much smaller ichor_runtime below.
      {:ichor, "~> 0.2.1", only: :dev, runtime: false},

      # === RUNTIME ===
      # The support library the ichor.gen-generated parser
      # (lib/xeger/grammar.ex) actually calls at runtime.
      {:ichor_runtime, "~> 0.1.0"}
    ]
  end

  # Fast/cheap checks first so a broken commit fails quickly; dialyzer
  # (slowest, especially its first PLT build) runs last.
  defp aliases do
    [
      precommit: [
        "format",
        "compile --warnings-as-errors",
        "credo --strict",
        "sobelow",
        "test",
        "dialyzer"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        CHANGELOG.md
        guides
        .formatter.exs
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: nil,
      extras: [
        "README.md",
        "guides/TUTORIAL.md",
        "guides/REFERENCE.md",
        "guides/CHEATSHEET.md",
        "guides/EXAMPLES.md",
        "CHANGELOG.md": [title: "Changelog"],
        LICENSE: [title: "License"]
      ],
      groups_for_extras: [
        "Getting Started": ["guides/TUTORIAL.md"],
        Guides: ["guides/REFERENCE.md", "guides/CHEATSHEET.md", "guides/EXAMPLES.md"]
      ],
      groups_for_modules: [
        "Core API": [Xeger, Xeger.Pattern],
        Internal: [
          Xeger.AST,
          Xeger.Parser,
          Xeger.Parser.Actions,
          Xeger.Grammar,
          Xeger.Generator
        ]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end
end
