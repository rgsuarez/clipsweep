# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-23

### Added

- Initial release.
- Core transformer module `lua/clipsweep.lua` with four passes: strip trailing whitespace, join wraps, convert dashes (off by default), collapse blank lines.
- Hammerspoon snippet `hammerspoon/snippet.lua` for one-hotkey clipboard cleanup (`Cmd+Shift+Opt+V`) and one-level restore (`Cmd+Shift+Opt+Z`).
- 30 fixture-based test cases under `tests/fixtures/`, runnable in the Hammerspoon Console via `tests/run.lua`.
- Code-indent detection requires 4+ leading spaces or a leading tab. 1-3 leading spaces on a continuation line are stripped during a prose join (handles agent-CLI 2-space left-gutter output and Markdown-style continuation indent).
- New gutter-strip pre-pass (`strip_gutter`, default `true`) dedents 1-3 leading spaces from every non-blank line before the join pass runs. Skips lines inside code fences, diff markers, stack frames, and 4+-space / tab indented code. Effect: terminal-rendered content with a uniform 2-space left gutter ends up flush-left, with structural elements (bullets, numbered lists, headings, blockquotes, tables, code fences) intact at column 0.
- Full heuristic spec documented in `docs/rules.md`.
