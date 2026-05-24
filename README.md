# clipsweep

A one-hotkey macOS clipboard cleanup tool. Reads the current clipboard, strips cosmetic line breaks that terminal apps inject when they wrap text to column width, preserves real structure (Markdown, code, logs, diffs, stack traces, tables, URLs, CJK), optionally converts em-dashes and en-dashes to ASCII hyphens, and writes the cleaned text back to the clipboard. A second hotkey restores the previous clipboard contents (one level of undo).

Pure-Lua transformer module, loaded by Hammerspoon. No external dependencies. No app to maintain.

## Status

v0.1.0, local-only.

## Requirements

- macOS with Hammerspoon installed (`/Applications/Hammerspoon.app`).
- That is the entire dependency footprint.

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
| `strip_trailing_ws`   | true    | strip trailing whitespace per line                |
| `collapse_blank_lines`| true    | collapse runs of 3+ blank lines to 1 blank line   |
| `convert_dashes`      | false   | convert U+2014 / U+2013 to ASCII hyphen           |

To override defaults, edit the `clipsweep.clean(text, opts)` call in `hammerspoon/snippet.lua` and pass an `opts` table.

## What it preserves

`clipsweep` is built to leave structure alone. Lines starting with any of these signals are preserved unchanged:

- Markdown headings (`#`), bullets (`-`, `*`, `+`), numbered lists, blockquotes (`>`), tables (`|`), setext underlines (`---`, `===`), link references (`[`), HTML tags (`<`).
- Fenced code blocks (everything inside ```` ``` ```` or `~~~`).
- Indented code (4+ leading spaces or a tab).
- Shell continuations (`\`, `&&`, `||`, `|`, `;` at end of line).
- Log lines (ISO timestamps, `[INFO]`/`[ERROR]` shapes, syslog).
- Diff hunks (`@@`, `+++`, `---`, `+`/`-`/space inside a hunk).
- Stack frames (Python `File "..."`, JS `at fn (...)`, Go `file.go:N`, Rust numbered frames, `Traceback`, `panic:`).
- TSV/tabular data (lines with 2+ tabs).
- Short single-word lines (under 40 chars, no spaces).

## What it cleans

- Paragraph wraps: consecutive non-blank prose lines get joined with a single space.
- Hyphenated wraps at line end (`self-\ncontained` -> `self-contained`): joined without space.
- URL wraps (lineA ends in a URL token, lineB continues): joined without space.
- CJK text at the wrap boundary: joined without space (no inter-word space convention).
- Trailing whitespace per line.
- Runs of 3+ blank lines collapsed to 1 blank line between content.

## Limitations

- Heuristic, not perfect. The restore hotkey is the safety net.
- One level of undo only.
- URL detection is best-effort; some edge cases (URL ending at end of a sentence with no terminal punctuation) may join incorrectly.
- v1 does not normalize smart quotes or other Unicode punctuation.

## Layout

```
clipsweep/
|-- README.md
|-- LICENSE
|-- CHANGELOG.md
|-- .gitignore
|-- .editorconfig
|-- lua/clipsweep.lua            # core transformer
|-- hammerspoon/snippet.lua      # paste this into ~/.hammerspoon/init.lua
|-- tests/
|   |-- run.lua                  # Hammerspoon-Console-loadable entry
|   |-- test_clipsweep.lua       # fixture iterator
|   `-- fixtures/                # 27 paired NN_name.in / NN_name.expected files
`-- docs/rules.md                # full heuristic spec
```

## Test

After cloning to `~/projects/clipsweep/`, in the Hammerspoon Console:

```lua
dofile(os.getenv("HOME") .. "/projects/clipsweep/tests/run.lua")
```

Expected output: `clipsweep tests: 30/30 PASS`.

## Uninstall

Remove the marked region from `~/.hammerspoon/init.lua` (between `-- BEGIN clipsweep` and `-- END clipsweep`). Optional: `rm -rf ~/projects/clipsweep/`.

## License

MIT. See `LICENSE`.
