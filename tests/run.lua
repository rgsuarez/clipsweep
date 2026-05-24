-- clipsweep test runner.
-- In the Hammerspoon Console (after cloning to ~/projects/clipsweep/):
--   dofile(os.getenv("HOME") .. "/projects/clipsweep/tests/run.lua")

local home = os.getenv("HOME")
local lua_dir   = home .. "/projects/clipsweep/lua/?.lua"
local tests_dir = home .. "/projects/clipsweep/tests/?.lua"

if not package.path:find(lua_dir, 1, true) then
  package.path = package.path .. ";" .. lua_dir
end
if not package.path:find(tests_dir, 1, true) then
  package.path = package.path .. ";" .. tests_dir
end

-- Force a fresh load so iterative edits to the module / harness are picked up.
package.loaded.clipsweep = nil
package.loaded.test_clipsweep = nil

local tests = require("test_clipsweep")
tests.run_all()
