# clipsweep tests

This directory contains the fixture harness and the test fixtures.

## Layout

- `run.lua` — entry point. Sets up paths and invokes `test_clipsweep.run_all()`.
- `test_clipsweep.lua` — fixture iterator. Reads each `NN_name.in` / `NN_name.expected` pair, runs `clipsweep.clean()`, byte-compares the result.
- `fixtures/NN_name.in` — input bytes for fixture `NN_name`.
- `fixtures/NN_name.expected` — expected output bytes.
- `fixtures/NN_name.opts` — (optional) one `key=value` per line for non-default options. Falls back to `FIXTURE_OPTS` in `test_clipsweep.lua` for backward compatibility.

## Invocation

**Command-line / CI:**

```
lua tests/run.lua
```

Exits 0 on full pass, non-zero on any failure. Lua 5.3 or 5.4 works; the language surface is identical for clipsweep's usage. The runner derives the repo root from its own script path, so the same command works from any working directory.

**Hammerspoon Console (interactive iteration):**

```
dofile(os.getenv("HOME") .. "/projects/clipsweep/tests/run.lua")
```

Or from a shell with the Hammerspoon CLI installed (Hammerspoon menu bar -> Install Command Line Tool):

```
hs -c "dofile(os.getenv('HOME') .. '/projects/clipsweep/tests/run.lua')"
```

The Hammerspoon path is convenient when you are also iterating on `hammerspoon/snippet.lua`; the standalone-Lua path is faster for pure transformer changes.

## Fixture conventions

- Numbered `NN_short_name` where `NN` is a two-digit prefix that orders fixtures in run order.
- `.in` and `.expected` are read in binary mode (`rb`). Encode exact line endings, BOMs, and trailing-newline state.
- Negative-case fixtures (prefixed `45_negative_...` etc.) verify a preserve matcher does NOT over-fire on prose.

See `../CONTRIBUTING.md` for the walkthrough on adding a fixture.

## `.opts` sibling file format

```
key1 = value1
key2 = value2
```

- Keys are word characters / underscores.
- Values are `true`, `false`, or a plain string.
- One pair per line. Blank lines and lines that do not match `key = value` are ignored.

Example: `tests/fixtures/17_em_dash_in_prose.opts`

```
convert_dashes = true
```

For backward compatibility, fixtures listed in the `FIXTURE_OPTS` table in `test_clipsweep.lua` still work without a `.opts` file. Prefer `.opts` files for new fixtures.
