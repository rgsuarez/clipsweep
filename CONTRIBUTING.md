# Contributing to clipsweep

clipsweep is a pure-Lua text transformer plus a small Hammerspoon snippet. Contributions are welcome. This document covers the developer workflow and the conventions used in the repo.

## Development setup

You need:

- macOS with Hammerspoon installed (for full integration testing of the snippet).
- Lua 5.3 or 5.4 (for command-line iteration and CI parity). On macOS: `brew install lua`. On Debian/Ubuntu: `apt install lua5.4`.
- Optional: `luarocks install luacheck` for static analysis (matches CI).

Clone:

```
git clone https://github.com/rgsuarez/clipsweep.git
cd clipsweep
```

## Running tests

Two invocation paths run the same fixture suite:

```
# Command-line (CI-equivalent; non-zero exit on failure):
lua tests/run.lua

# Hammerspoon Console (interactive iteration; in-process):
hs -c "dofile(os.getenv('HOME') .. '/projects/clipsweep/tests/run.lua')"
```

Expected: `clipsweep tests: N/N PASS`. Any failure prints the fixture name and a byte-diff snippet.

The Hammerspoon path is convenient when you are also iterating on `hammerspoon/snippet.lua`; the standalone-Lua path is faster for pure transformer changes.

## Fixture format

Each test fixture is a pair (with an optional sibling) under `tests/fixtures/`:

- `NN_short_name.in`: input bytes. Treated as binary; encode exact line endings, BOM, trailing-newline state.
- `NN_short_name.expected`: expected output bytes.
- `NN_short_name.opts` (optional): one `key=value` per line for non-default options, e.g. `convert_dashes=true`. Falls back to the hand-maintained `FIXTURE_OPTS` map in `tests/test_clipsweep.lua`.

The harness reads both files in binary mode and does byte-exact comparison. CRLF, BOM, lone CR, and no-trailing-newline are all distinct valid cases.

To add a fixture:

1. Pick the next free `NN_` prefix.
2. Write the `.in` file with the exact clipboard input you want to test. Use `printf` for byte-precise content (CRLF, BOM, lone CR, no-final-newline).
3. Generate the `.expected` by running the current cleaner:

   ```
   lua -e "package.path='./lua/?.lua;'..package.path; \
     io.write(require('clipsweep').clean(io.open('tests/fixtures/NN_name.in','rb'):read('*a')))" \
     > tests/fixtures/NN_name.expected
   ```

4. Inspect the `.expected` and confirm it matches your intent.
5. Run `lua tests/run.lua` and confirm `N+1/N+1 PASS`.

## Heuristic philosophy

Read `docs/rules.md` before adding or modifying a heuristic. Every new preserve rule needs:

- A positive fixture that proves the rule fires when it should.
- A negative fixture that proves the rule does NOT fire when it should not (the `45_negative_*` shape).
- A bullet in the appropriate section of `docs/rules.md`.
- A `CHANGELOG.md` `[Unreleased]` entry.

clipsweep is intentionally conservative: false positives (over-preserving) are acceptable; false negatives (corrupting structure) are not. When in doubt, preserve.

## Branch and commit conventions

- Work on a feature branch off `main`. Naming: `feat/<short>`, `fix/<short>`, `chore/<short>`, `docs/<short>`, `test/<short>`.
- Commit messages: imperative mood. Conventional-commit prefix optional but appreciated. First line under 72 chars; the body explains the why.
- One concern per pull request. A feature with its tests is one PR. A feature plus an unrelated refactor is two.
- Pre-push: `lua tests/run.lua` must return `N/N PASS`. Do not bypass any local pre-push hook.

## Pull request checklist

The PR template will ask for:

- Fixture added or updated (if behavior changes).
- `docs/rules.md` updated (if a rule is added or changed).
- `CHANGELOG.md` `[Unreleased]` section appended.
- Tests pass locally via both invocation paths.
- `luacheck lua/ hammerspoon/ tests/` clean.

## `.gitattributes` and line endings

The repo enforces LF for source files and treats fixtures as binary (`-text`). If you cloned before `.gitattributes` landed and now see CRLF on a fixture, run `git add --renormalize .` once to fix.

## License and contributor agreement

By submitting a contribution you agree it is licensed under the repo's MIT license (see `LICENSE`). No separate CLA.
