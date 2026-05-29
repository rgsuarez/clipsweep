# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-05-29

### Added

- `normalize_quotes` pass (default on): folds the four common smart quotes to ASCII. U+2018 / U+2019 to `'`, U+201C / U+201D to `"`. Runs in the Pass 0 input-normalization stage, before any structure-aware pass, and applies to the whole input including inside code fences. Disable per call with `M.clean(text, { normalize_quotes = false })`.
- Fixtures `54_smart_quotes_shell` (the multi-line shell command repro), `55_ascii_quotes_unchanged` (negative: ASCII quotes pass through), and `56_smart_quotes_in_code_fence` (pins the deliberate non-fence-aware behavior).

### Changed

- BEHAVIOR REVERSAL: smart quotes are now normalized to ASCII by default. The v0.1.0 contract left them untouched ("v1 does not normalize smart quotes"). The fixture `20_smart_quotes_preserved` is renamed to `20_smart_quotes_normalized`, keeps its curly-quote input, and now expects ASCII output. To restore the old behavior, pass `{ normalize_quotes = false }`.
- `docs/rules.md`: Pass 0 is now an "input normalization" stage documenting both line-ending folding (unconditional) and smart-quote folding (`normalize_quotes`, default on), including the deliberate contrast with the fence-aware `convert_dashes`.
- `README.md`: status to v0.3.0; config table, "What it cleans", and Limitations updated for smart-quote normalization.

### Fixed

- Smart quotes emitted by LLM tooling (codex and similar) in a copied shell command no longer break the paste. clipsweep previously reported "0 changes" and left the curly quotes in place, so the pasted command hung in the shell continuation prompt. The quotes now fold to ASCII and the command parses.

## [0.2.0] - 2026-05-27

### Added

- Pass 0: unconditional line-ending normalization. CRLF and bare CR fold to LF at the top of `M.clean` before any other pass. Output is always LF-only.
- Preserve rule for exception-class headers at column 0: `ClassName(Error|Exception|Warning|Fault):` (e.g. `ValueError:`, `NullPointerException:`, `MyApp.ParseError:`, plus the Node.js-style bare `Error:` / `Exception:`). Java-style lowercase-prefix FQNs (`java.lang.NullPointerException`) are a known limitation.
- Per-iteration join breaker: when the accumulator ends with an unbalanced open `(` or `[`, the join breaks. Prevents wrapped Markdown link / image syntax like `[label](\nhttps://...)` from having a space injected inside the parens.
- Conservative table cell-wrap continuation preserve: a non-`|`, non-blank, non-preserved line immediately following a `|` row (or another cell-wrap continuation) is preserved verbatim. Mode resets on blank line, other structural preserve, fence entry, or EOF.
- 23 new fixtures: M7 positive coverage (4 documented preserves previously untested), M8 boundary cases (10), L6 negative-case over-fire prevention (6), and 3 positive fixtures for the new H2/H3/M3 rules. Total fixture count: 53.
- `.gitattributes` enforcing LF for source and binary-mode (`-text`) for `tests/fixtures/*.{in,expected,opts}`.
- `SECURITY.md` with threat model and private-advisory reporting workflow.
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `tests/README.md`.
- `.github/workflows/test.yml` running `luacheck` and the fixture suite on `ubuntu-latest` via `lua5.4`. Fires on push to `main` and on every pull request.
- `.github/ISSUE_TEMPLATE/bug_report.md`, `.github/ISSUE_TEMPLATE/config.yml`, `.github/PULL_REQUEST_TEMPLATE.md`.
- `.luacheckrc` for static-analysis config; matches CI.
- `.opts` sibling-file convention for per-fixture options (one `key=value` per line). Falls back to the hand-maintained `FIXTURE_OPTS` map for backward compatibility.

### Changed

- `hammerspoon/snippet.lua`: `transform()` now wraps `clipsweep.clean()` in `pcall`. A Lua error surfaces as a 2.5s `hs.alert` (was: silent Console log) and rolls back `previous_clipboard` to `nil` so a subsequent restore does not stomp the clipboard with the input as if the transform had succeeded.
- `hammerspoon/snippet.lua`: undo stash moved from a `do`-block local to `_G.clipsweep_state.previous_clipboard`. A pathwatcher-triggered re-evaluation of `init.lua` no longer drops the one level of undo. A true `hs.reload()` still resets the stash (intentional; the Lua state itself is torn down).
- `hammerspoon/snippet.lua`: `restore()` clears `_G.clipsweep_state.previous_clipboard` after writing. A second restore in a row reports "nothing to restore" instead of stomping a freshly-copied clipboard.
- `hammerspoon/snippet.lua`: renamed misleading `sign` helper to `format_delta` with a comment documenting the inverted-sign UX (positive delta -> "-N" because cleanup typically shrinks content).
- `tests/run.lua` and `tests/test_clipsweep.lua`: paths derive from the runner's own script location instead of hardcoded `$HOME/projects/clipsweep`. Standalone `lua tests/run.lua` exits non-zero on failure.
- `docs/rules.md`: pass numbering made consistent (Pass 0 normalize, 1 strip_trailing_ws, 2 strip_gutter, 3 join_wraps, 4 convert_dashes, 5 collapse_blank_lines) in both the table and the prose headings. New sections for Pass 0, exception-class preserve, unbalanced-bracket breaker, cell-wrap continuation, unclosed fences, shell-continuation lookback inside `strip_gutter`, ASCII-only qualifier on short-single-word, and BOM behavior.
- `README.md` adds badges, motivation paragraph, Contributing and Security pointers; qualifies the table-preservation claim with the cell-wrap conservative tradeoff; updates the test invocation to show both Hammerspoon-Console and standalone-Lua paths; updates PASS count to 53.

### Fixed

- CRLF input no longer leaves stray `\r` characters mid-line after a join.
- Markdown link wrapped across lines (`[label](\nhttps://...)`) no longer gets a space injected inside the parens.
- Bare `ValueError: x` (and other `ClassName(Error|Exception|Warning|Fault):` shapes) at column 0 is no longer joined into following prose.
- Silent failures in `transform()` now surface as `hs.alert` to the user.
- Undo state survives pathwatcher reloads of `init.lua`.
- Second restore in a row no longer stomps freshly-copied clipboard.
- `docs/rules.md` pass-numbering inconsistency resolved.

## [0.1.0] - 2026-05-23

### Added

- Initial release.
- Core transformer module `lua/clipsweep.lua` with four passes: strip trailing whitespace, join wraps, convert dashes (off by default), collapse blank lines.
- Hammerspoon snippet `hammerspoon/snippet.lua` for one-hotkey clipboard cleanup (`Cmd+Shift+Opt+V`) and one-level restore (`Cmd+Shift+Opt+Z`).
- 30 fixture-based test cases under `tests/fixtures/`, runnable in the Hammerspoon Console via `tests/run.lua`.
- Code-indent detection requires 4+ leading spaces or a leading tab. 1-3 leading spaces on a continuation line are stripped during a prose join (handles agent-CLI 2-space left-gutter output and Markdown-style continuation indent).
- New gutter-strip pre-pass (`strip_gutter`, default `true`) dedents 1-3 leading spaces from every non-blank line before the join pass runs. Skips lines inside code fences, diff markers, stack frames, and 4+-space / tab indented code. Effect: terminal-rendered content with a uniform 2-space left gutter ends up flush-left, with structural elements (bullets, numbered lists, headings, blockquotes, tables, code fences) intact at column 0.
- Full heuristic spec documented in `docs/rules.md`.

[Unreleased]: https://github.com/rgsuarez/clipsweep/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/rgsuarez/clipsweep/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/rgsuarez/clipsweep/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rgsuarez/clipsweep/releases/tag/v0.1.0
