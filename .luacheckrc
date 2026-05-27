-- luacheck configuration for clipsweep.
-- Run with: luacheck lua/ hammerspoon/ tests/
-- CI matches this configuration.

std = "max"

-- Defaults that apply to every file unless overridden below.
ignore = {
  "212",  -- unused argument (intentional in some signatures)
}

max_line_length = 140

-- Hammerspoon snippet runs inside the Hammerspoon Lua state, which provides
-- `hs` as a global, and uses _G.clipsweep_state as the intentional cross-reload
-- undo stash.
files["hammerspoon/snippet.lua"] = {
  globals = { "hs", "clipsweep_state" },
}

-- Test runner and harness run under either Hammerspoon (with `hs`) or
-- standalone Lua (with `arg`).
files["tests/run.lua"] = {
  globals = { "hs", "arg" },
}
files["tests/test_clipsweep.lua"] = {
  globals = { "hs" },
}
