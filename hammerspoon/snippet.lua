-- BEGIN clipsweep
-- clipsweep v0.1.0 hotkey bindings for ~/.hammerspoon/init.lua.
-- Paste this block at the end of init.lua. Pathwatcher (if enabled) will
-- pick the change up automatically. Otherwise, reload Hammerspoon from
-- the menu bar.

do
  local home = os.getenv("HOME")
  local clipsweep_lua_dir = home .. "/projects/clipsweep/lua/?.lua"
  if not package.path:find(clipsweep_lua_dir, 1, true) then
    package.path = package.path .. ";" .. clipsweep_lua_dir
  end

  -- Drop any cached module so a save-triggered reload (pathwatcher re-running
  -- init.lua) picks up edits to lua/clipsweep.lua instead of reusing the stale
  -- bytecode from package.loaded.
  package.loaded.clipsweep = nil
  local ok, clipsweep = pcall(require, "clipsweep")
  if not ok then
    hs.alert.show("clipsweep: failed to load module (" .. tostring(clipsweep) .. ")")
    return
  end

  local previous_clipboard = nil

  local function count_lines(s)
    if not s or s == "" then return 0 end
    local n = 1
    for _ in s:gmatch("\n") do n = n + 1 end
    return n
  end

  local function transform()
    local current = hs.pasteboard.getContents()
    if current == nil or current == "" then
      hs.alert.show("clipsweep: empty clipboard", 0.8)
      return
    end

    previous_clipboard = current
    local cleaned = clipsweep.clean(current)

    if cleaned == current then
      hs.alert.show("clipsweep: 0 changes", 0.8)
      return
    end

    hs.pasteboard.setContents(cleaned)

    local line_delta = count_lines(current) - count_lines(cleaned)
    local char_delta = #current - #cleaned
    -- Positive delta means content shrank (cleanup removed lines/chars), shown as "-N".
    -- Negative delta means content grew, shown as "+N".
    local function format_delta(n)
      if n >= 0 then return "-" .. n else return "+" .. (-n) end
    end
    hs.alert.show(
      string.format(
        "clipsweep: %s lines, %s chars",
        format_delta(line_delta), format_delta(char_delta)
      ),
      0.8
    )
  end

  local function restore()
    if previous_clipboard == nil then
      hs.alert.show("clipsweep: nothing to restore", 0.8)
      return
    end
    hs.pasteboard.setContents(previous_clipboard)
    hs.alert.show("clipsweep: restored", 0.8)
  end

  hs.hotkey.bind({ "cmd", "shift", "alt" }, "v", transform)
  hs.hotkey.bind({ "cmd", "shift", "alt" }, "z", restore)
end
-- END clipsweep
