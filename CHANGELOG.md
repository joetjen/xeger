# Changelog

## Unreleased

### Added

* Added custom `~G` sigil for ergonomic pattern creation
  * `~G/pattern/` compiles a pattern
  * `~G/pattern/s` creates a stream directly
  * `~G/pattern/c` explicitly compiles (same as no modifier)
* Enhanced `take/3` to accept both binary patterns and compiled `Pattern.t()` structs

### Fixed

* Fixed infinite loop issue when generating strings from patterns with unbounded repetition
* Fixed Stream handling in Elixir 1.18+ by implementing proper max_len calculation
* Fixed nonneg_compositions/2 to handle edge case where n > 0 and k = 0
* Fixed heredoc formatting issues for @moduledoc and @doc attributes
* Fixed default value declaration for multi-clause stream/2 function

### Improved

* Organized dependencies alphabetically in mix.exs
* Added comprehensive @moduledoc documentation for Parser and Generator modules
* Improved @doc and @spec coverage across all public functions
* Expanded test suite with 21 additional test cases for better coverage
* Updated all dependencies to latest compatible versions
* Ensured code compiles without warnings (--warnings-as-errors)
* Passed all static analysis checks (Credo, Dialyzer, Sobelow)

## 0.1.0

* Initial release: parse + generate for a practical regex subset.
