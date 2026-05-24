-- clipsweep test harness.
-- Loaded by tests/run.lua. Iterates the tests/fixtures/ directory,
-- reads each NN_name.in / NN_name.expected pair, runs the cleaner,
-- and reports pass/fail.

local M = {}

local FIXTURES_DIR = os.getenv("HOME") .. "/projects/clipsweep/tests/fixtures"

-- Fixtures that exercise non-default opts (the rest run on M.defaults).
local FIXTURE_OPTS = {
  ["17_em_dash_in_prose"]       = { convert_dashes = true },
  ["18_en_dash_in_range"]       = { convert_dashes = true },
  ["19_dash_inside_code_fence"] = { convert_dashes = true },
}

local function read_file(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local content = f:read("*all") or ""
  f:close()
  return content
end

local function list_fixtures(dir)
  local names = {}
  local seen = {}

  if hs and hs.fs and hs.fs.dir then
    for entry in hs.fs.dir(dir) do
      if entry:sub(-3) == ".in" then
        local base = entry:sub(1, -4)
        if not seen[base] then
          seen[base] = true
          table.insert(names, base)
        end
      end
    end
  else
    local p = io.popen('ls "' .. dir .. '"')
    if p then
      for entry in p:lines() do
        if entry:sub(-3) == ".in" then
          local base = entry:sub(1, -4)
          if not seen[base] then
            seen[base] = true
            table.insert(names, base)
          end
        end
      end
      p:close()
    end
  end

  table.sort(names)
  return names
end

local function visible(s)
  if s == nil then return "<nil>" end
  return (s:gsub("\n", "\\n"):gsub("\t", "\\t"))
end

local function explain_diff(expected, actual)
  if expected == actual then return "no diff" end
  if expected == nil then return "expected is nil" end
  if actual == nil then return "actual is nil" end

  local n = math.min(#expected, #actual)
  for i = 1, n do
    if expected:sub(i, i) ~= actual:sub(i, i) then
      local lo = math.max(1, i - 12)
      local hi_e = math.min(#expected, i + 12)
      local hi_a = math.min(#actual, i + 12)
      return string.format(
        "first byte diff at offset %d\n        expected ...%q\n        actual   ...%q",
        i,
        visible(expected:sub(lo, hi_e)),
        visible(actual:sub(lo, hi_a))
      )
    end
  end
  if #expected ~= #actual then
    return string.format(
      "length diff: expected %d bytes, actual %d bytes (one is a prefix of the other)\n        expected tail: %q\n        actual tail:   %q",
      #expected, #actual,
      visible(expected:sub(n + 1)),
      visible(actual:sub(n + 1))
    )
  end
  return "unknown diff"
end

function M.run_all()
  local clipsweep = require("clipsweep")
  local fixtures = list_fixtures(FIXTURES_DIR)

  if #fixtures == 0 then
    print("clipsweep tests: 0 fixtures discovered in " .. FIXTURES_DIR)
    return 0, 0
  end

  local pass, fail = 0, 0
  local failures = {}

  for _, name in ipairs(fixtures) do
    local in_path  = FIXTURES_DIR .. "/" .. name .. ".in"
    local exp_path = FIXTURES_DIR .. "/" .. name .. ".expected"
    local input, ierr   = read_file(in_path)
    local expected, eerr = read_file(exp_path)

    if input == nil then
      fail = fail + 1
      table.insert(failures, { name = name, why = "read .in: " .. tostring(ierr) })
    elseif expected == nil then
      fail = fail + 1
      table.insert(failures, { name = name, why = "read .expected: " .. tostring(eerr) })
    else
      local opts = FIXTURE_OPTS[name]
      local ok, actual = pcall(clipsweep.clean, input, opts)
      if not ok then
        fail = fail + 1
        table.insert(failures, { name = name, why = "exception: " .. tostring(actual) })
      elseif actual == expected then
        pass = pass + 1
      else
        fail = fail + 1
        table.insert(failures, { name = name, why = explain_diff(expected, actual) })
      end
    end
  end

  local total = pass + fail
  print(string.format("clipsweep tests: %d/%d PASS", pass, total))
  if fail > 0 then
    for _, f in ipairs(failures) do
      print(string.format("  FAIL %s: %s", f.name, f.why))
    end
  end

  return pass, fail
end

return M
