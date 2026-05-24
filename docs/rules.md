# clipsweep heuristic rules

This document describes every transformation rule applied by `lua/clipsweep.lua` in `M.clean(text, opts)`. Read this first when extending or debugging the transformer.

## Pass order

Passes run in this fixed order. Each is independently gated by an `opts` flag.

| order | pass                       | flag                   | default |
|-------|----------------------------|------------------------|---------|
| 1     | strip_trailing_ws_pass     | `strip_trailing_ws`    | true    |
| 2     | strip_gutter_pass          | `strip_gutter`         | true    |
| 3     | join_wraps_pass            | `join_wraps`           | true    |
| 4     | convert_dashes_pass        | `convert_dashes`       | false   |
| 5     | collapse_blank_lines_pass  | `collapse_blank_lines` | true    |

The trailing-newline count of the input is preserved across all passes. Passes never synthesize a trailing `\n`; the collapse pass may reduce 3+ trailing blank lines, but cannot turn a non-newline-terminated input into a newline-terminated one.

## Pass 1: strip_trailing_ws

Removes trailing spaces and tabs from each line. Does not modify line breaks or content otherwise.

Example:

```
"foo   \nbar\t\n"  ->  "foo\nbar\n"
```

## Pass 2: join_wraps

The core unwrap pass. Walks the input line-by-line, opportunistically joining consecutive non-blank lines into a single longer line when the break between them is a cosmetic terminal-wrap break.

### Block-all-joins at lineA (first line of a potential join)

If the line currently being inspected starts a paragraph and matches ANY of these, no join is attempted; the line is emitted as-is and the walker advances:

- Indented-code prefix: a leading tab, or 4+ leading spaces.
- Markdown heading (`#`).
- Markdown bullet (`-`, `*`, `+` followed by a space).
- Markdown numbered list (`[0-9]+\.` followed by a space).
- Blockquote (`>`).
- Fenced code block opener / closer (` ``` ` or `~~~`).
- Table row (`|`).
- Setext underline or horizontal rule (standalone `---` or `===`).
- Link reference or footnote (`[`).
- HTML / XML tag (`<`).
- Shell prompt mimic (`$ `).
- Log line: `[YYYY-...`, ISO `YYYY-MM-DD`, syslog `Mon Jan 1 12:34:56`, bracketed level `[DEBUG]`, level prefix `INFO:`, `[PID]`.
- Stack frame: ` at fn (`, ` File "`, ` foo.go:N`, numbered Rust frame ` 0:`, `panic:`, `Traceback`.
- Diff hunk / header: `+++`, `---`, `@@`, or any leading `+`/`-`/` ` while inside an active diff hunk.
- Short single-word line (length < 40 chars, no spaces).

### Per-iteration breakers inside the inner join loop

Inside an active join, the next candidate line (lineB) breaks the join if any of the following are true:

- lineB is blank.
- The accumulator (the line being built) ends with a shell continuation (`\`, `&&`, `||`, `|`, `;`).
- lineB itself triggers any of the block-all-joins rules above.
- Both the accumulator and lineB contain 2 or more tab characters (TSV / tabular data).

## Gutter strip pre-pass (`strip_gutter`)

Runs after the trailing-whitespace strip and before `join_wraps`. Walks every line and removes 1-3 leading spaces from non-blank lines, except when the leading whitespace is semantically meaningful:

- Lines inside a fenced code block (between ` ``` ` markers) are not modified.
- Lines that match a diff marker (`+++`, `---`, `@@`, or `+`/`-`/space inside an active diff hunk) are not modified.
- Lines that match a stack frame shape (`Traceback`, `panic:`, `  File "..."`, `    at fn(...)`, etc.) are not modified.
- Lines starting with a tab or with 4+ leading spaces are not modified (indented code).

Effect: terminal-rendered content that arrives with a uniform 2-space left gutter on every line, including the first line of a paragraph, is flattened to column 0. Indented bullets, numbered lists, blockquotes, headings, and table rows likewise lose the gutter and become column-0 structural elements; `join_wraps` then sees them as bare structural starters and preserves them correctly.

### Join separator selection

When a join proceeds, the separator between the accumulator and lineB defaults to a single space. Three special cases override that:

1. **Hyphenated wrap.** If the accumulator ends with `-` and lineB starts with a lowercase letter, separator is empty (the hyphen is preserved).

   ```
   "self-\ncontained"  ->  "self-contained"
   ```

2. **URL wrap.** If the accumulator's last whitespace-delimited token contains `://` and does not end in sentence-terminator punctuation (`.,;!?])`), AND lineB does not start with an uppercase letter (which would suggest a new sentence), separator is empty.

   ```
   "https://example.com/very-long-\npath/here"  ->  "https://example.com/very-long-path/here"
   ```

   Heuristic limitation: a URL that legitimately ends a clause and is followed by a lowercase continuation may be joined without space. The restore hotkey is the safety net.

3. **CJK.** If the accumulator's last UTF-8 codepoint OR lineB's first UTF-8 codepoint is in the CJK ranges (U+3000-U+9FFF or U+FF00-U+FFEF), separator is empty. CJK scripts do not use inter-word spaces.

### Fence and diff state tracking

- `in_fence` toggles on any line whose stripped form starts with ` ``` ` or `~~~`. While `in_fence` is true, every line is emitted verbatim and joins are suspended.
- `in_diff` turns on at a line starting with `@@`, off at any blank line. While `in_diff` is true, lines starting with `+`, `-`, or a single leading space are preserve-before (treated as diff context).

## Pass 3: convert_dashes (opt-in)

Replaces U+2014 (em-dash glyph) and U+2013 (en-dash glyph) with ASCII hyphen `-`. Skipped while `in_fence` is true. Fence boundary lines themselves are not modified.

Disabled by default (`convert_dashes = false`). Enable via `opts.convert_dashes = true` on a per-call basis, or by editing the default in `lua/clipsweep.lua`.

## Pass 4: collapse_blank_lines

Runs of 2 or more consecutive blank lines in the body collapse to a single blank line. Trailing blank lines at the end of the body are trimmed (the original trailing-newline count is restored after this pass, so this affects body-internal collapse only, not end-of-text formatting).

Example:

```
"foo\n\n\n\nbar"  ->  "foo\n\nbar"
```

## Trailing-newline behavior

`clipsweep` preserves the number of trailing `\n` characters in the input. If the input ended with zero trailing newlines, the output ends with zero. If it ended with one, the output ends with one. The collapse pass may reduce 3+ trailing newlines to 2 if the user has unusual end-of-text whitespace, but never synthesizes a trailing newline that wasn't there.

## Empty input

`M.clean("")` returns `""`. `M.clean(nil)` returns `""`.

## Determinism and idempotence

The transformer is pure: same input -> same output. It is idempotent on most outputs: `clean(clean(x)) == clean(x)` for inputs that do not depend on accumulator-tail state (rare edge cases involving exactly-once-applied transformations exist, but are unlikely in practice).
