# clipsweep

One-hotkey macOS clipboard cleanup: unwraps terminal-wrapped text while preserving Markdown, code, logs, diffs, tables, URLs, and CJK.

[![tests](https://github.com/rgsuarez/clipsweep/actions/workflows/test.yml/badge.svg)](https://github.com/rgsuarez/clipsweep/actions/workflows/test.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![release](https://img.shields.io/github/v/release/rgsuarez/clipsweep?sort=semver)](https://github.com/rgsuarez/clipsweep/releases)

## Motivation

Terminal-rendered output (agent CLIs, log tails, `man` pages, paged tools) wraps at the column width of the terminal. Pasting that text into a chat client, a doc, a ticket, or another tool brings the cosmetic wrap with it: every paragraph arrives as a stack of hard-broken short lines, often with a 2-space gutter. Plain hand-cleanup is tedious and easy to get wrong on structured content (Markdown, code fences, diffs, stack traces).

`clipsweep` solves this with one hotkey. It joins prose lines that were only broken for terminal width, leaves real structure alone (Markdown, code blocks, diffs, log lines, stack frames, tables, URLs, CJK), and writes the cleaned text back to the clipboard. A second hotkey restores the pre-transform clipboard as a one-level undo.

Pure-Lua transformer module, loaded by Hammerspoon. No external dependencies. No app to maintain.

## Status

v0.4.0, local-only.

## Requirements

- macOS with Hammerspoon installed (`/Applications/Hammerspoon.app`).
- That is the entire dependency footprint at runtime.

For developing and running tests off-device: optional Lua 5.3 or 5.4 (`brew install lua` on macOS, `apt install lua5.4` on Debian/Ubuntu).

## Install

1. Clone or copy this repo to `~/projects/clipsweep/`.
2. Open `hammerspoon/snippet.lua`. Copy its contents.
3. Open `~/.hammerspoon/init.lua`. Paste the snippet between two marker comments:

   ```lua
   -- BEGIN clipsweep
   ... snippet contents ...
   -- END clipsweep
   ```

4. Save `init.lua`. If you have a Hammerspoon `pathwatcher` autoreload set up (the default in most configs), the change loads instantly. Otherwise, reload Hammerspoon manually from the menu bar.

5. Verify the load: open the Hammerspoon Console (menu bar -> Console). You should see no errors.

## Usage

- `Cmd+Shift+Opt+V`: clean the current clipboard. An alert briefly shows `clipsweep: -N lines, -M chars`.
- `Cmd+Shift+Opt+Z`: restore the pre-transform clipboard. Alert: `clipsweep: restored`.

The default config is conservative:

| flag                  | default | what it does                                      |
|-----------------------|---------|---------------------------------------------------|
| `join_wraps`          | true    | join terminal-wrap line breaks in prose           |
| `normalize_quotes`    | true    | fold smart quotes (U+2018/19/1C/1D) to ASCII      |
| `strip_trailing_ws`   | true    | strip trailing whitespace per line                |
| `collapse_blank_lines`| true    | collapse runs of 3+ blank lines to 1 blank line   |
| `convert_dashes`      | false   | convert U+2014 / U+2013 to ASCII hyphen           |

Plus an unconditional Pass 0 that folds CRLF and bare CR to LF (no flag; always on).

To override defaults, edit the `clipsweep.clean(text, opts)` call in `hammerspoon/snippet.lua` and pass an `opts` table.

## What it preserves

`clipsweep` is built to leave structure alone. Lines starting with any of these signals are preserved unchanged:

- Markdown headings (`#`), tables (`|`), setext underlines (`---`, `===`), link references (`[`), HTML tags (`<`).
- List and blockquote boundaries: bullets (`-`, `*`, `+`), numbered lists, and blockquotes (`>`) each stay anchored to their own line. One item is never merged into the next, nor into an adjacent paragraph. As of v0.4.0 a marker-less line wrapped *below* such a marker is treated as a cosmetic wrap and folded into the item (see "What it cleans") rather than left as a stray short line.
- Fenced code blocks (everything inside ```` ``` ```` or `~~~`).
- Indented code (4+ leading spaces or a tab).
- Shell continuations (`\`, `&&`, `||`, `|`, `;` at end of line).
- Log lines (ISO timestamps, `[INFO]`/`[ERROR]` shapes, syslog).
- Diff hunks (`@@`, `+++`, `---`, `+`/`-`/space inside a hunk).
- Stack frames (Python `File "..."`, JS `at fn (...)`, Go `file.go:N`, Rust numbered frames, `Traceback`, `panic:`).
- Exception-class headers (`ValueError:`, `RuntimeError:`, `NullPointerException:`, `DeprecationWarning:`, `MyApp.ParseError:`, Node-style bare `Error:`).
- TSV/tabular data (lines with 2+ tabs).
- Short single-word lines (under 40 chars, no spaces, ASCII).
- Table cell-wrap continuation lines (a non-`|` line immediately after a `|` row is preserved verbatim; mode resets on blank line).

## What it cleans

- Paragraph wraps: consecutive non-blank prose lines get joined with a single space.
- List and blockquote continuation wraps (new in v0.4.0): a bullet, numbered item, or blockquote whose text was hard-wrapped onto marker-less lines below it is rejoined into one line. Item boundaries are kept (the next marker, a blank line, or any other structure still breaks the join); only the within-item wrap collapses. Headings are deliberately excluded.
- Hyphenated wraps at line end (`self-\ncontained` -> `self-contained`): joined without space.
- URL wraps (lineA ends in a URL token, lineB continues): joined without space.
- CJK text at the wrap boundary: joined without space (no inter-word space convention).
- Trailing whitespace per line.
- Runs of 3+ blank lines collapsed to 1 blank line between content.
- CRLF and bare CR line endings folded to LF (unconditional Pass 0).
- Smart quotes folded to ASCII (`'` and `"`) so pasted shell commands and code parse correctly. Default on; disable with `clipsweep.clean(text, { normalize_quotes = false })`. Applies everywhere, including inside code fences.

## Limitations

- Heuristic, not perfect. The restore hotkey is the safety net.
- One level of undo only.
- URL detection is best-effort; some edge cases (URL ending at end of a sentence with no terminal punctuation) may join incorrectly.
- Smart-quote normalization covers the four common quotes (U+2018, U+2019, U+201C, U+201D) only. Other Unicode punctuation (primes, guillemets, low-9 / high-reversed-9 quote variants, ellipsis) and em/en dashes (see `convert_dashes`) are not folded by `normalize_quotes`. UTF-8 BOM is preserved as-is.
- Java-style lowercase-prefix exception FQNs (`java.lang.NullPointerException`) are not matched by the exception-class preserve.
- A paragraph that immediately follows a Markdown table without a blank-line separator (CommonMark violation but common) is preserved as cell-wrap continuation, not joined.

## Layout

```
clipsweep/
|-- README.md
|-- LICENSE
|-- CHANGELOG.md
|-- CONTRIBUTING.md
|-- CODE_OF_CONDUCT.md
|-- SECURITY.md
|-- .gitattributes
|-- .gitignore
|-- .editorconfig
|-- .luacheckrc
|-- .github/
|   |-- workflows/test.yml
|   |-- ISSUE_TEMPLATE/{bug_report.md,config.yml}
|   `-- PULL_REQUEST_TEMPLATE.md
|-- lua/clipsweep.lua            # core transformer
|-- hammerspoon/snippet.lua      # paste this into ~/.hammerspoon/init.lua
|-- tests/
|   |-- README.md                # test harness reference
|   |-- run.lua                  # entry point
|   |-- test_clipsweep.lua       # fixture iterator
|   `-- fixtures/                # paired NN_name.in / NN_name.expected files
`-- docs/rules.md                # full heuristic spec
```

## Test

Two invocation paths, same fixture suite:

```bash
# Command-line (CI-equivalent; non-zero exit on failure):
lua tests/run.lua

# Hammerspoon Console (interactive iteration):
dofile(os.getenv("HOME") .. "/projects/clipsweep/tests/run.lua")
```

Or from a shell with the Hammerspoon CLI installed:

```bash
hs -c "dofile(os.getenv('HOME') .. '/projects/clipsweep/tests/run.lua')"
```

Expected output: `clipsweep tests: 64/64 PASS`.

See `tests/README.md` for the fixture format reference and `CONTRIBUTING.md` for the walkthrough on adding a fixture.

## Uninstall

Remove the marked region from `~/.hammerspoon/init.lua` (between `-- BEGIN clipsweep` and `-- END clipsweep`). Optional: `rm -rf ~/projects/clipsweep/`.

## Contributing

See `CONTRIBUTING.md` for dev setup, fixture conventions, branch and commit conventions, and the pull request checklist. Behavior changes need a fixture pair, a `docs/rules.md` entry, and a `CHANGELOG.md [Unreleased]` line.

## Security

See `SECURITY.md`. To report a vulnerability, open a private security advisory at https://github.com/rgsuarez/clipsweep/security/advisories/new.

## License

MIT. See `LICENSE`.
