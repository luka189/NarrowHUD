-- NarrowHUD, the crash trace (3.0.14; the idea is HUDdle 0.7.5's "freeze trace", the code our own). F9 Testing "Crash
-- trace", off by default, for a player whose game crashes or hangs with the mod on.
-- Why: Chef's own trace names a call only the first time a kind of call is made, so a crash in the five-hundredth
-- read of a field says "ended without a clean shutdown" and nothing more. With this on, the name of every call into
-- the game is written over the one line of narrowhud_lastcall.txt (beside narrowhud.log) just before the call is
-- made, unbuffered; when the frame's work is done the line says so ("idle"); a clean quit says "clean quit". The
-- next launch reads the line into narrowhud.log: the call the game died in, or that it died outside any call of
-- this mod — which is as much worth knowing.
-- How: `chef` (the one upvalue every module calls through) is swapped for a stand-in whose functions write the line
-- and then call Chef's; off, it is Chef's own table again and nothing here runs. Level 2 "Reads" names the reads
-- (engine calls through chef.call_kind, the unit helpers, the camera, the watches); level 3 the draws as well
-- (hundreds a frame: slower). A call named the same as the last one written is not written again.
-- The cost is a file write a call (some milliseconds a frame): for a test session, not for play.
local cfg = N.cfg
local FILE = 'narrowhud_lastcall.txt'
local WIDTH = 150                                -- (every line this wide, so a short one leaves nothing of a long one)
-- never traced: no call into the game (the clock, the menu's rows, the log, the saved tables)
local SKIP = { time = true, bind = true, on_change = true, option = true, has = true, own_log = true, log = true,
               save_table = true, load_table = true, set = true, on = true, title = true }
-- the draws (level 3 only)
local DRAW = { rect = true, line = true, triangle = true, bitmap = true, bitmap_uv = true, text = true, text_width = true,
               text_fit = true, sprite = true, color = true, texture_sizes = true, world_to_screen = true, screen = true }
local tr = { f = nil, level = 1, last = nil, real = chef, proxy = nil, path = nil, lines = {}, writes = 0, said = nil }
N.trace = tr

local function path_of()
  if tr.path == nil then
    local dir = chef.log_directory
    tr.path = type(dir) == 'string' and (dir .. '\\' .. FILE) or false
  end
  return tr.path
end
local function fixed(text)                       -- (not string.format: Lua 5.1 takes a width of two digits at most)
  text = string.sub(text, 1, WIDTH)
  return text .. string.rep(' ', WIDTH - #text) .. '\n'
end
-- the line written (over the last one). A failed write ends the trace: it must never be the thing that breaks
local function put(line)
  if line == tr.last then return end
  tr.last = line
  local f = tr.f
  if not f then return end
  local ok = pcall(f.seek, f, 'set', 0)
  if ok then ok = pcall(f.write, f, line) end
  if ok and not tr.nobuf then ok = pcall(f.flush, f) end
  tr.writes = tr.writes + 1
  if not ok then
    tr.f = nil
    pcall(f.close, f)
    log('crash trace: a write to %s failed: off', FILE)
  end
end
local function line_of(name, kind)
  local key = kind and (name .. '  [' .. tostring(kind) .. ']') or name
  local l = tr.lines[key]
  if not l then l = fixed('in ' .. key) tr.lines[key] = l end
  return l
end

-- Chef's table with the line written before each call. The functions are looked up in Chef's table each time
-- (chef.log is rebound by chef.own_log; a test swaps functions too)
local function make_proxy()
  local real = tr.real
  local made = {}
  return setmetatable({}, {
    __index = function(_, k)
      local v = real[k]
      if type(v) ~= 'function' or SKIP[k] then return v end
      if DRAW[k] and tr.level < 3 then return v end
      local w = made[k]
      if not w then
        if k == 'call_kind' then
          w = function(name, kind, ...) if tr.f then put(line_of(name, kind)) end return real.call_kind(name, kind, ...) end
        elseif k == 'call' then
          w = function(name, ...) if tr.f then put(line_of(name)) end return real.call(name, ...) end
        else
          local l = line_of('chef.' .. k)
          w = function(...) if tr.f then put(l) end return real[k](...) end
        end
        made[k] = w
      end
      return w
    end,
    __newindex = function(_, k, v) real[k] = v end,
  })
end

-- what the last launch left in the file, said once in narrowhud.log
local function last_launch(path)
  local ok, f = pcall(io.open, path, 'r')
  if not ok or not f then return nil end
  local _, line = pcall(f.read, f, '*l')
  pcall(f.close, f)
  if type(line) ~= 'string' then return nil end
  return (string.gsub(line, '%s+$', ''))
end
local function report(line)
  if not line or line == '' or string.sub(line, 1, 3) == 'off' then return end
  if string.sub(line, 1, 10) == 'clean quit' then
    log('crash trace: the last launch quit cleanly')
  elseif string.sub(line, 1, 4) == 'idle' then
    log('crash trace: the last launch ended OUTSIDE any call of NarrowHUD (%s)', line)
  elseif string.sub(line, 1, 3) == 'in ' then
    log('crash trace: the last launch ended INSIDE this call (a crash or a hang): %s', string.sub(line, 4))
  else
    log('crash trace: the last launch left: %s', line)
  end
end

local function open(level)
  local path = path_of()
  if not path or type(io) ~= 'table' then log('crash trace: no folder to write in: off') return end
  if not tr.said then tr.said = true report(last_launch(path)) end
  local ok, f = pcall(io.open, path, 'w')
  if not ok or not f then log('crash trace: %s could not be opened (%s): off', FILE, tostring(f)) return end
  tr.f, tr.last, tr.level = f, nil, level
  tr.nobuf = pcall(f.setvbuf, f, 'no') == true
  tr.proxy = make_proxy()
  chef = tr.proxy
  put(fixed('idle (the trace just switched on)'))
  log('crash trace: on (%s): every call into the game named in %s before it is made', level >= 3 and 'reads and draws' or 'reads', FILE)
end
local function close(why)
  local f = tr.f
  chef = tr.real
  tr.proxy, tr.level = nil, 1
  if not f then return end
  put(fixed(why))
  tr.f = nil
  pcall(f.close, f)
end
-- the setting followed (at the start, and when it is changed in F9)
local function sync()
  local want = cfg.crash_trace or 1
  if want == tr.level and tr.said and (want == 1 or tr.f) then return end
  if tr.f then close('off (switched in F9)') end
  if want > 1 then
    open(want)
    if not tr.f then tr.level = want end         -- (it could not be opened: said once, not tried every frame)
  elseif not tr.said then
    -- off at the start: a line an earlier, traced launch left must not be read as the last launch's later on
    tr.said = true
    local path = path_of()
    local line = path and type(io) == 'table' and last_launch(path)
    if line and line ~= '' and string.sub(line, 1, 3) ~= 'off' then
      local ok, f = pcall(io.open, path, 'w')
      if ok and f then pcall(f.write, f, fixed('off (the crash trace was off in the launch after this line: ' .. string.sub(line, 1, 60) .. ')')) pcall(f.close, f) end
    end
  end
end

local update, shutdown, on_stop = M.update, M.shutdown, M.on_stop
function M.update(dt)
  if (cfg.crash_trace or 1) ~= tr.level or not tr.said then sync() end
  update(dt)
  if tr.f then
    tr.last = nil
    put(fixed(string.format('idle (the frame\'s work done; frame %d, %.1f s in, world %s)', N.frame or 0, N.now or 0, tostring(N.wid))))
  end
end
function M.shutdown()
  if shutdown then shutdown() end
  close('clean quit')
end
function M.on_stop()
  if on_stop then on_stop() end
  close('clean quit (the mod stopped in F9)')
end
function M.debug_trace_names() local l = {} for k in pairs(tr.lines) do l[#l + 1] = k end return l end   -- (tests: the calls named so far)
function M.debug_trace() return { level = tr.level, on = tr.f ~= nil, writes = tr.writes, proxied = chef ~= tr.real } end   -- (tests)
