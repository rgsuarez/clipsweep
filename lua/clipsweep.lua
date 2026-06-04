-- clipsweep v0.4.2
-- Pure-Lua clipboard cleanup transformer.
-- Unwraps cosmetic terminal-wrap line breaks, including hard-wrapped list
-- items and blockquotes; dedents 1-3 space gutters; folds smart quotes to
-- ASCII (default on); preserves Markdown, code, diff, log, stack-trace,
-- table, URL, and CJK structure. Optional em/en dash conversion. Designed to
-- be loaded by the Hammerspoon pasteboard snippet but has no Hammerspoon
-- dependency.

local M = {}

M.defaults = {
  convert_dashes       = false,  -- em/en dash -> ASCII hyphen, off in v1
  normalize_quotes     = true,   -- smart quotes -> ASCII ' and ", on by default
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

-- True if `line` ends with an unbalanced open `(` or `[` (open count > close
-- count). Used as a per-iteration breaker so wrapped Markdown link/image
-- syntax like `[label](\nhttps://...)` does not get a space injected inside
-- the parens. Conservative: over-preserves on prose with literal unbalanced
-- parens; never under-preserves (never injects a corruption).
local function ends_unbalanced_open_bracket(line)
  local open_paren = 0
  for _ in line:gmatch("%(") do open_paren = open_paren + 1 end
  for _ in line:gmatch("%)") do open_paren = open_paren - 1 end
  if open_paren > 0 then return true end
  local open_brack = 0
  for _ in line:gmatch("%[") do open_brack = open_brack + 1 end
  for _ in line:gmatch("%]") do open_brack = open_brack - 1 end
  return open_brack > 0
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

-- Matches a bare exception-class header at column 0, e.g. "ValueError: x",
-- "RuntimeError: nope", "NullPointerException:", "DeprecationWarning: ...",
-- "MyApp.ParseError: ...", and the Node-style bare "Error: ENOENT...".
-- Used to keep these lines from being joined into following prose.
-- Java-style lowercase-prefix FQNs ("java.lang.NullPointerException") are a
-- known limitation: the leading lowercase fails the [A-Z] anchor here.
local function looks_like_exception_class(line)
  if line:match("^[A-Z][%w_%.]*[eE]rror:") then return true end
  if line:match("^[A-Z][%w_%.]*[eE]xception:") then return true end
  if line:match("^[A-Z][%w_%.]*[wW]arning:") then return true end
  if line:match("^[A-Z][%w_%.]*[fF]ault:") then return true end
  -- Bare forms (Node.js style).
  if line:match("^Error:%s") then return true end
  if line:match("^Exception:%s") then return true end
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
  -- ATX heading: 1+ `#` then whitespace or end-of-line. The trailing-space
  -- requirement is load-bearing: prose that starts with `#42` (a PR/issue ref)
  -- or `#launch` (a hashtag) is NOT a heading and must stay free to join its
  -- wrapped continuation. `^#` alone stranded those lines as fake headings.
  if line:match("^#+%s") or line:match("^#+$") then return true end
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
  if looks_like_exception_class(line) then return true end
  return false
end

-- True if `line` is a list item or blockquote marker that begins prose which
-- may have been hard-wrapped across several physical lines. Unlike every other
-- should_preserve_before starter (heading, code, log, table, stack frame, ...),
-- these SEED a join in join_wraps_pass: their marker-less continuation lines
-- fold back up into the marker line. The patterns are byte-identical to the
-- bullet / numbered-list / blockquote arms of should_preserve_before, so a
-- marker still BREAKS an ongoing join when it appears as lineB; one list item
-- never absorbs the next. Headings are deliberately excluded: they rarely wrap
-- in a terminal, and merging a heading into the line below it (when no blank
-- line separates them) is a high-cost corruption.
local function starts_list_or_quote(line)
  if line:match("^[%-%*%+]%s") then return true end
  if line:match("^%d+%.%s") then return true end
  if line:match("^>") then return true end
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
  -- Tracks whether the most recently emitted non-blank line was a `|` table
  -- row OR a cell-wrap continuation. Resets on blank lines and on emit of
  -- any other structural preserve (heading, code, log, etc.). Used to
  -- preserve cell-wrap continuation lines that lack a leading `|` but
  -- semantically belong inside the table cell above them.
  local prev_was_table_row = false

  local i = 1
  while i <= #lines do
    local line = lines[i]

    if is_fence_line(line) then
      in_fence = not in_fence
      prev_was_table_row = false
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    if in_fence then
      prev_was_table_row = false
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
      prev_was_table_row = false
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    local is_list_quote = starts_list_or_quote(line)

    -- Structural preserves that are NOT list/quote markers (heading, code,
    -- log, table, exception class, etc.) are emitted standalone and never seed
    -- a join. A `|` table row keeps table-continuation mode active; any other
    -- such preserve exits it. List/quote markers fall through to the join loop
    -- below so their hard-wrapped continuation lines fold back up into the
    -- marker line.
    if not is_list_quote
       and (should_preserve_before(line, in_diff) or is_short_single_word(line)) then
      prev_was_table_row = (line:sub(1, 1) == "|")
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    -- Cell-wrap continuation: a non-`|`, non-blank, non-preserved line that
    -- immediately follows a `|` row (or another cell-wrap continuation) is
    -- treated as wrapped cell content and preserved verbatim. Conservative:
    -- a real paragraph that follows a table without a blank-line separator
    -- (CommonMark spec violation but common) will also be preserved instead
    -- of joined. Failure mode is over-preservation, never corruption. A
    -- list/quote marker is exempt: it begins a new list item, not wrapped cell
    -- text, so it resets table-continuation mode (below) instead of extending it.
    if prev_was_table_row and not is_list_quote then
      table.insert(result, line)
      i = i + 1
      goto continue_outer
    end

    -- A list/quote marker seeds the join loop and clears table-continuation
    -- mode. The inner loop's should_preserve_before(lineB) breaker stops the
    -- join at the next marker, a blank line, or any other structural element,
    -- so only the within-item terminal wrap collapses.
    if is_list_quote then
      prev_was_table_row = false
    end

    local acc = line
    local j = i + 1
    while j <= #lines do
      local lineB = lines[j]
      if is_blank(lineB) then break end
      if ends_shell_continuation(acc) then break end
      if ends_unbalanced_open_bracket(acc) then break end

      -- Indented continuation of a list/quote item. A wrapped line aligned
      -- under the marker text arrives indented (the terminal gutter plus the
      -- list's hanging indent commonly total 4+ spaces), which
      -- `starts_with_code_indent` would otherwise read as an indented code
      -- block and refuse to join. When THIS join was seeded by a list/quote
      -- marker, dedent such a line and absorb it as continuation; only break
      -- if it is still structural after the dedent (a nested bullet or
      -- numbered item, a fence, a table row, a heading, a log line, etc.).
      -- Scoped to list/quote seeds, so a standalone indented code block (whose
      -- own first line is the indented-code lineA preserve) is never touched.
      if is_list_quote and starts_with_code_indent(lineB) then
        local dedented = lineB:gsub("^[ \t]+", "")
        if should_preserve_before(dedented, in_diff) then break end
        lineB = dedented
      elseif should_preserve_before(lineB, in_diff) then
        break
      end

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

-- Fold the four common "smart" quotes to their ASCII equivalents:
--   U+2018 ' and U+2019 ' -> '   (LEFT/RIGHT SINGLE QUOTATION MARK)
--   U+201C " and U+201D " -> "   (LEFT/RIGHT DOUBLE QUOTATION MARK)
-- Deliberately NOT fence-aware (unlike convert_dashes_pass): smart quotes
-- break shell and code parsing wherever they appear, including inside code
-- fences, and are almost never intentional in clipboard-cleanup content.
-- Runs as the first flag-gated pass, on the whole text, before any
-- structure-aware pass. The high bytes (0xE2 0x80 0x9X) carry no Lua-pattern
-- magic, so they match literally.
local function normalize_quotes_pass(text)
  text = text:gsub("\xE2\x80\x98", "'"):gsub("\xE2\x80\x99", "'")
  text = text:gsub("\xE2\x80\x9C", '"'):gsub("\xE2\x80\x9D", '"')
  return text
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

  if cfg.normalize_quotes then
    text = normalize_quotes_pass(text)
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
