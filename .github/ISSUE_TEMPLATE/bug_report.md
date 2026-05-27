---
name: Bug report
about: A clipboard input that produces wrong or surprising output.
title: ''
labels: bug
assignees: ''
---

## Repro fixture

Paste the offending clipboard input verbatim. Include exact line endings and trailing whitespace. If line endings or BOM matter, describe them explicitly (e.g., "CRLF" or "starts with UTF-8 BOM").

```
<input here>
```

## Observed output

What clipsweep produced.

```
<output here>
```

## Expected output

What you wanted.

```
<expected here>
```

## Environment

- macOS version:
- Hammerspoon version:
- clipsweep version (commit SHA or release tag):
- Invocation path (Hammerspoon hotkey, `lua tests/run.lua`, or direct `M.clean()` call):

## Bisect (optional but helpful)

If you can, run with one or more flags disabled to narrow it down:

```
require("clipsweep").clean(input, { strip_gutter = false })
require("clipsweep").clean(input, { join_wraps   = false })
require("clipsweep").clean(input, { collapse_blank_lines = false })
```

Report which flag changes the result.
