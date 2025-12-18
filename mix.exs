defmodule RegSynth.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/joetjen/regsynth"

  def project do
    [
      app: :regsynth,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "RegSynth - generate strings that match a regex-like pattern (regex → strings).",
      package: package(),

      # Docs
      name: "RegSynth",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),

      # Dialyzer
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Development and Test Dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.39.3", only: :dev, runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false}

      # Runtime Dependencies
      # (none)
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        CHANGELOG.md
        QUICKSTART.md
        USAGE_GUIDE.md
        EXAMPLES.md
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
        "QUICKSTART.md",
        "USAGE_GUIDE.md",
        "EXAMPLES.md",
        "CHANGELOG.md": [title: "Changelog"]
      ],
      groups_for_extras: [
        "Getting Started": ["QUICKSTART.md"],
        Guides: ["USAGE_GUIDE.md", "EXAMPLES.md"]
      ],
      groups_for_modules: [
        "Core API": [RegSynth],
        Internal: [RegSynth.AST, RegSynth.Parser, RegSynth.Generator]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end
end
