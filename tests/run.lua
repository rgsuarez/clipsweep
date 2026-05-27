-- clipsweep test runner.
-- Two invocation paths:
--   1. Hammerspoon Console (interactive iteration):
--        dofile(os.getenv("HOME") .. "/projects/clipsweep/tests/run.lua")
--   2. Standalone Lua (CI or terminal):
--        lua tests/run.lua    (from repo root, or from any cwd)

local function script_path()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  return src
end

local function dir_of(path)
  return path:match("(.*/)") or "./"
end

local tests_dir = dir_of(script_path())
local repo_root = tests_dir:gsub("/tests/$", ""):gsub("/tests$", "")
if repo_root == tests_dir then
  -- Edge case: tests_dir did not end in /tests/. Use parent.
  repo_root = tests_dir .. ".."
end

local lua_dir = repo_root .. "/lua/?.lua"
local tests_pkg = repo_root .. "/tests/?.lua"

if not package.path:find(lua_dir, 1, true) then
  package.path = package.path .. ";" .. lua_dir
end
if not package.path:find(tests_pkg, 1, true) then
  package.path = package.path .. ";" .. tests_pkg
end

-- Force a fresh load so iterative edits to the module or harness are picked up.
package.loaded.clipsweep = nil
package.loaded.test_clipsweep = nil

local tests = require("test_clipsweep")
tests.fixtures_dir = repo_root .. "/tests/fixtures"

local _, fail = tests.run_all()

-- Under standalone Lua (no global `hs`), exit non-zero so CI fails on red.
if not _G.hs then
  os.exit(fail > 0 and 1 or 0)
end
