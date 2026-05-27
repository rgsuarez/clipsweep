## Summary

(One BLUF sentence. What changed, and why.)

## What changes

(Bullet list of files and behavioral effects.)

## Why

(One paragraph on the problem this solves and the chosen approach.)

## Test plan

- [ ] `lua tests/run.lua` returns `N/N PASS` locally.
- [ ] `hs -c "dofile(os.getenv('HOME') .. '/projects/clipsweep/tests/run.lua')"` returns `N/N PASS`.
- [ ] Manual repro of the relevant clipboard input in Hammerspoon (if user-visible).
- [ ] `luacheck lua/ hammerspoon/ tests/` clean.

## Checklist

- [ ] Fixture added or updated (if behavior changed).
- [ ] `docs/rules.md` updated (if a rule was added or changed).
- [ ] `CHANGELOG.md` `[Unreleased]` section appended.
- [ ] No new dependencies introduced (clipsweep is pure-Lua by design).
