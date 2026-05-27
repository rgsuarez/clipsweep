-- clipsweep v0.1.0
-- Pure-Lua clipboard cleanup transformer.
-- Unwraps cosmetic terminal-wrap line breaks; dedents 1-3 space gutters;
-- preserves Markdown, code, diff, log, stack-trace, table, URL, and CJK
-- structure. Optional em/en dash conversion. Designed to be loaded by the
-- Hammerspoon pasteboard snippet but has no Hammerspoon dependency.

local M = {}

M.defaults = {
  convert_dashes       = false,  -- em/en dash -> ASCII hyphen, off in v1
  join_wraps           = true,   -- core unwrap pass
  collapse_blank_lines = true,   -- 3+ blank lines -> 1 blank line
  strip_trailing_ws    = true,   -- per-line trailing space/tab strip
  strip_gutter         = true,   -- dedent 1-3 leading spaces from non-structural lines
}

-- UTF-8 helpers ---------------------------------------------------------

local function utf8_codepoint_at(s, i)
  if not i or i < 1 or i > #s then return nil end
  local b = s:byte(i)
  if not b then return nil end
  if b < 0x80 then
    return b
  elseif b < 0xC0 then
    return nil
  elseif b < 0xE0 then
    local b2 = s:byte(i + 1) or 0
    return ((b - 0xC0) * 64) + (b2 - 0x80)
  elseif b < 0xF0 then
    local b2 = s:byte(i + 1) or 0
    local b3 = s:byte(i + 2) or 0
    return ((b - 0xE0) * 4096) + ((b2 - 0x80) * 64) + (b3 - 0x80)
  else
    local b2 = s:byte(i + 1) or 0
    local b3 = s:byte(i + 2) or 0
    local b4 = s:byte(i + 3) or 0
    return ((b - 0xF0) * 262144) + ((b2 - 0x80) * 4096) + ((b3 - 0x80) * 64) + (b4 - 0x80)
  end
end

local function last_utf8_start(s)
  local n = #s
  while n >= 1 do
    local b = s:byte(n)
    if b < 0x80 or b >= 0xC0 then return n end
    n = n - 1
  end
  return nil
end

local function is_cjk(cp)
  if not cp then return false end
  if cp >= 0x3000 and cp <= 0x9FFF then return true end
  if cp >= 0xFF00 and cp <= 0xFFEF then return true end
  return false
end

-- Line splitting that preserves trailing-newline count ------------------

local function split_lines(text)
  local trailing = 0
  local s = text
  while s:sub(-1) == "\n" do
    trailing = trailing + 1
    s = s:sub(1, -2)
  end
  local lines = {}
  for line in (s .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  return lines, trailing
end

local function join_lines_back(lines, trailing)
  return table.concat(lines, "\n") .. string.rep("\n", trailing)
end

-- Line predicates -------------------------------------------------------

local function is_blank(line)
  return line:match("^%s*$") ~= nil
end

local function is_fence_line(line)
  local stripped = line:gsub("^%s+", "")
  return stripped:sub(1, 3) == "```" or stripped:sub(1, 3) == "~~~"
end

local function starts_with_code_indent(line)
  -- "Indented code" per the plan: 4+ leading spaces, or a leading tab.
  -- 1-3 leading spaces are stripped by strip_gutter_pass before this is
  -- consulted (when the gutter pass is enabled).
  if #line == 0 then return false end
  if line:sub(1, 1) == "\t" then return true end
  if line:sub(1, 4) == "    " then return true end
  return false
end

local function ends_shell_continuation(line)
  if #line == 0 then return false end
  local last1 = line:sub(-1)
  local last2 = line:sub(-2)
  if last1 == "\\" then return true end
  if last2 == "&&" then return true end
  if last2 == "||" then return true end
  if last1 == "|" then return true end
  if last1 == ";" then return true end
  return false
end

local function ends_hyphen_word(line)
  if #line < 2 then return false end
  return line:sub(-1) == "-"
end

local function ends_in_url(line)
  local last_token = line:match("(%S+)$")
  if not last_token then return false end
  if not last_token:find("://", 1, true) then return false end
  local last = line:sub(-1)
  if last == "." or last == "," or last == ";" or last == "!"
     or last == "?" or last == ")" or last == "]" then
    return false
  end
  return true
end

local function has_two_plus_tabs(line)
  local n = 0
  for _ in line:gmatch("\t") do
    n = n + 1
    if n >= 2 then return true end
  end
  return false
end

local function is_ascii_only(s)
  for i = 1, #s do
    if s:byte(i) >= 0x80 then return false end
  end
  return true
end

local function is_short_single_word(line)
  if #line >= 40 then return false end
  if not is_ascii_only(line) then return false end
  return line:find(" ", 1, true) == nil
end

local LOG_LEVELS = { "DEBUG", "INFO", "WARN", "WARNING", "ERROR", "TRACE", "FATAL" }

local function looks_like_log(line)
  if line:match("^%[%d%d%d%d%-") then return true end
  if line:match("^%d%d%d%d%-%d%d%-%d%d") then return true end
  if line:match("^%a+%s+%d+%s+%d+:%d+:%d+") then return true end
  if line:match("^%[%d+%]") then return true end
  for _, lvl in ipairs(LOG_LEVELS) do
    if line:match("^%[" .. lvl .. "%]") then return true end
    if line:match("^" .. lvl .. ":") then return true end
  end
  return false
end

local function looks_like_stack_frame(line)
  if line:match("^%s+at %S+%(") then return true end
  if line:match('^%s+File "') then return true end
  if line:match("^%s+%S+%.go:%d+") then return true end
  if line:match("^%s+%d+:%s+%S+") then return true end
  if line:match("^panic:") then return true end
  if line:match("^Traceback") then return true end
  return false
end

local function looks_like_diff_marker(line, in_diff)
  if line:sub(1, 3) == "+++" then return true end
  if line:sub(1, 3) == "---" then return true end
  if line:sub(1, 2) == "@@" then return true end
  if in_diff then
    local c = line:sub(1, 1)
    if c == "+" or c == "-" or c == " " then return true end
  end
  return false
end

local function should_preserve_before(line, in_diff)
  if starts_with_code_indent(line) then return true end
  if looks_like_diff_marker(line, in_diff) then return true end
  if line:match("^#") then return true end
  if line:match("^[%-%*%+]%s") then return true end
  if line:match("^%d+%.%s") then return true end
  if line:match("^>") then return true end
  if is_fence_line(line) then return true end
  if line:sub(1, 1) == "|" then return true end
  if line:match("^%-%-%-+$") then return true end
  if line:match("^===+$") then return true end
  if line:sub(1, 1) == "[" then return true end
  if line:sub(1, 1) == "<" then return true end
  if line:sub(1, 2) == "$ " then return true end
  if looks_like_log(line) then return true end
  if looks_like_stack_frame(line) then return true end
  return false
end

-- Passes ----------------------------------------------------------------

local function strip_trailing_ws_pass(text)
  local lines, trailing = split_lines(text)
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("[ \t]+$", "")
  end
  return join_lines_back(lines, trailing)
end

-- Strip 1-3 leading spaces from each non-blank line, skipping lines where
-- the leading whitespace is semantically meaningful: diff markers, stack
-- frames, fenced code block interior. 4+ leading spaces and tabs are also
-- left alone (indented code per the plan). Run BEFORE join_wraps so the
-- structural starters (bullets, headings, numbered lists, blockquotes,
-- tables, code fences, etc.) are visible at column 0 by the time the join
-- pass inspects them.
local function strip_gutter_pass(text)
  local lines, trailing = split_lines(text)
  local in_fence = false
  local in_diff = false
  local prev_was_shell_continuation = false

  for i, line in ipairs(lines) do
    if is_fence_line(line) then
      in_fence = not in_fence
      prev_was_shell_continuation = false
      -- Fence transition: do not modify the fence line itself.
    elseif in_fence then
      prev_was_shell_continuation = false
      -- Interior of a fenced code block: do not modify.
    else
      if line:sub(1, 2) == "@@" then
        in_diff = true
      elseif is_blank(line) then
        in_diff = false
      end

      local preserve = looks_like_diff_marker(line, in_diff)
                       or looks_like_stack_frame(line)
                       or prev_was_shell_continuation

      if not preserve and not is_blank(line) then
        local lws = line:match("^( +)")
        if lws and #lws >= 1 and #lws <= 3 then
          lines[i] = line:sub(#lws + 1)
        end
      end

      if is_blank(line) then
        prev_was_shell_continuation = false
      else
        prev_was_shell_continuation = ends_shell_continuation(lines[i])
      end
    end
  end

  return join_lines_back(lines, trailing)
end

local function join_wraps_pass(text)
  local lines, trailing = split_lines(text)
  local result = {}
  local in_fence = false
  local in_diff = false

  local i = 1
  while i <= #lines do
    local line = lines[i]

    if is_fence_line(line) then
      in_fence = not in_fence
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    if in_fence then
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    if line:sub(1, 2) == "@@" then
      in_diff = true
    elseif is_blank(line) then
      in_diff = false
    end

    if is_blank(line) then
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    if should_preserve_before(line, in_diff) or is_short_single_word(line) then
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    local acc = line
    local j = i + 1
    while j <= #lines do
      local lineB = lines[j]
      if is_blank(lineB) then break end
      if ends_shell_continuation(acc) then break end
      if should_preserve_before(lineB, in_diff) then break end
      if has_two_plus_tabs(acc) and has_two_plus_tabs(lineB) then break end

      local sep = " "
      local cp_a = utf8_codepoint_at(acc, last_utf8_start(acc))
      local cp_b = utf8_codepoint_at(lineB, 1)

      if ends_hyphen_word(acc) then
        local first = lineB:sub(1, 1)
        if first:match("%l") then
          sep = ""
        end
      elseif ends_in_url(acc) then
        local first = lineB:sub(1, 1)
        if not first:match("%u") then
          sep = ""
        end
      elseif is_cjk(cp_a) or is_cjk(cp_b) then
        sep = ""
      end

      acc = acc .. sep .. lineB
      j = j + 1
    end

    table.insert(result, acc)
    i = j

    ::continue_outer::
  end

  return join_lines_back(result, trailing)
end

local function convert_dashes_pass(text)
  local lines, trailing = split_lines(text)
  local in_fence = false
  for idx, line in ipairs(lines) do
    if is_fence_line(line) then
      in_fence = not in_fence
      -- Fence lines themselves are transitions; do not convert dashes on them.
    elseif not in_fence then
      line = line:gsub("\xE2\x80\x94", "-"):gsub("\xE2\x80\x93", "-")
      lines[idx] = line
    end
  end
  return join_lines_back(lines, trailing)
end

local function collapse_blank_lines_pass(text)
  local lines, trailing = split_lines(text)
  local result = {}
  local blank_run = 0
  for _, line in ipairs(lines) do
    if is_blank(line) then
      blank_run = blank_run + 1
      if blank_run <= 1 then
        table.insert(result, line)
      end
    else
      blank_run = 0
      table.insert(result, line)
    end
  end
  while #result > 0 and is_blank(result[#result]) do
    table.remove(result, #result)
  end
  return join_lines_back(result, trailing)
end

-- Public API ------------------------------------------------------------

function M.clean(text, opts)
  if text == nil or text == "" then
    return text or ""
  end

  -- Pass 0: normalize line endings up front. CRLF and bare CR fold to LF.
  -- Unconditional (no opt-out flag). Output is always LF-only. This runs
  -- before all flag-gated passes so downstream logic never has to consider
  -- \r as a line break or as trailing whitespace.
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

  local cfg = {}
  for k, v in pairs(M.defaults) do
    cfg[k] = v
  end
  if opts then
    for k, v in pairs(opts) do
      cfg[k] = v
    end
  end

  if cfg.strip_trailing_ws then
    text = strip_trailing_ws_pass(text)
  end
  if cfg.strip_gutter then
    text = strip_gutter_pass(text)
  end
  if cfg.join_wraps then
    text = join_wraps_pass(text)
  end
  if cfg.convert_dashes then
    text = convert_dashes_pass(text)
  end
  if cfg.collapse_blank_lines then
    text = collapse_blank_lines_pass(text)
  end

  return text
end

return M
