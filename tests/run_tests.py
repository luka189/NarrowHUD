"""Offline tests for NarrowHUD: build/narrowhud.lua run in Lua 5.1 (lupa) with a stand-in `chef` and a small fake
game (your player, Helldiver and weapons as network objects, a hand pose). Not a substitute for the game.

    python3 tools/build.py && python3 tests/run_tests.py [--png out.png]
"""
import math
import re
import sys
from pathlib import Path

import lupa.lua51 as lua51

ROOT = Path(__file__).resolve().parent.parent
SRC = (ROOT / 'build' / 'narrowhud.lua').read_text(encoding='utf-8')
# the tests start from nothing learned: the shipped seed is swapped out (one test puts it back)
SEEDED_SRC = SRC
SRC = re.sub(r'local SEED = \(function\(\)\n.*?\nend\)\(\)\n', 'local SEED = {}\n', SRC, count=1, flags=re.S)
assert SRC != SEEDED_SRC, 'no seed block in the build'
DATA = (ROOT / 'src' / 'data_generated.lua').read_text(encoding='utf-8')


def role_names():
    return dict(re.findall(r'(\w+) = \{ letter = "\w", id = "\w+", name = "([^"]+)" \}', DATA))


def type_name(tid):
    m = re.search(tid + r' (\S+) ', DATA)
    return m.group(1)


def an_unseeded_rounds_type():
    seeded = {'8fcdd35c', '30294946', '17b02218', 'a4eff4fa', '17783758', '56e55184', 'f94a73b3'}
    for tid, name, roles in re.findall(r'(\w{8}) (\S+) (\w*)', DATA.split('weapons =')[1].split('backpacks =')[0]):
        if tid not in seeded and 'r' in roles and 'm' in roles and 'k' not in roles and 'h' not in roles:
            return tid, name
    raise SystemExit('no test type')


def setup(rt, game_font=True, chef11=False, seeded=False):
    R = role_names()
    unknown_id, unknown_name = an_unseeded_rounds_type()
    g = rt.globals()
    g.ROLE = rt.table_from(R)
    g.DATA_ROLES = rt.table_from(dict(re.findall(r'(\w+) = \{ letter = "\w", id = "(\w+)", name = "[^"]+" \}', DATA)))
    unk2 = [n for t, n, roles in re.findall(r'(\w{8}) (\S+) (\w*)', DATA.split('weapons =')[1].split('backpacks =')[0])
            if n != unknown_name and t not in ('8fcdd35c', '17783758', '30294946', 'a4eff4fa', '56e55184', 'f94a73b3', '17b02218')
            and 'r' in roles and 'm' in roles and 'k' not in roles and 'n' in roles and 'h' not in roles][0]
    ub2 = [(t, n) for t, n, roles in re.findall(r'(\w{8}) (\S+) (\w*)', DATA.split('weapons =')[1].split('backpacks =')[0])
           if n not in (unknown_name, unk2) and 'r' in roles and 'k' in roles and 'h' not in roles
           and t not in ('8fcdd35c', '17783758', '30294946', 'a4eff4fa', '56e55184', 'f94a73b3', '17b02218')][3]
    arc = [n for t, n, roles in re.findall(r'(\w{8}) (\S+) (\w*)', DATA.split('weapons =')[1].split('backpacks =')[0])
           if 'y' in roles and 'k' in roles and not set('rahl') & set(roles)][0]
    g.NAMES = rt.table_from({'stalwart': type_name('521229d8'), 'gl': type_name('8c0aee6e'), 'rr': type_name('b2bfd847'), 'crem': type_name('15f1a9f0'), 'crempack': type_name('6c17c3b1'), 'pack2': type_name('447380d4'), 'verdict': type_name('c7dfd9eb'), 'seaf': type_name('aca39ec2'), 'dog': type_name('530e19df'), 'arc': arc, 'commando': type_name('3d538455'), 'spear': type_name('83d1036e'), 'rail': type_name('26acc614'), 'rr': type_name('b2bfd847'), 'ac': type_name('7bfb2e06'), 'acfed': type_name('903649ec'), 'acpack': type_name('94ff3b20'), 'scythe': type_name('42a6b5ba'), 'c4': type_name('6b2c3bed'), 'c4pack': type_name('66d03a73'), 'laser': type_name('d100e0c8'), 'warrant': type_name('c920c2d3'), 'unk2': unk2, 'ub2': ub2[1], 'ub2id': ub2[0], 'fed': type_name('b3246bb7'), 'pack': 'raqnyi', 'ubgl': type_name('da0f356e'), 'player': type_name('803159b3') if False else 'un6y1d', 'avatar': 'vvhx8ga',
                             'arb': type_name('8fcdd35c'), 'nova': type_name('17783758'), 'de': type_name('960653cb'), 'talon': type_name('4e87d68d'), 'unk': unknown_name})
    rt.execute(r"""
T = 0
logs, draws, saved = {}, {}, nil
GRIP = 10
GAME_FONT = true      -- the game's font resources are loaded
RENDER_W, RENDER_H = 3440, 1440
FIRE = true           -- your fire button held (the player's own shots)
WORLD = 1             -- the world's id (a new one each mission)
HOST = '0b99cf5492296d6e'   -- the session's host (you, unless a test joins someone's game)
HOSTS = {}            -- objects the host owns (in someone else's game)
GUIS = 0
OPTS, CHANGE, BINDS = { research = true }, {}, {}   -- the F9 menu's values (the tests run with the research log on)
OBJINFO = nil           -- Network.object_info, when a test gives one
PAD, PADY, BLOCKED = false, false, false   -- fire on a controller; its Y pressed; Chef 1.1 refusing the reads
KEYS, WHEEL = {}, 0   -- keys pressed this frame, the mouse wheel
function press(k) if k == 'wheel' then WHEEL = 1 else KEYS[k] = true end run(1 / 60) KEYS, WHEEL = {}, 0 run(0.6) end
OBJ = {}
OBJ[1] = { name = NAMES.player, fields = { u4d1h9a = 2 } }
OBJ[2] = { name = NAMES.avatar, fields = { du7kbt = 4, ei6_t2 = 5 } }
OBJ[3] = { name = NAMES.arb, fields = {} }        -- Arbitrator: rounds 44 + chamber, 7 magazines, carried
OBJ[3].fields[ROLE.rounds] = 44; OBJ[3].fields[ROLE.chamber] = false; OBJ[3].fields[ROLE.magazines] = 7
OBJ[3].fields[ROLE.carry] = 0; OBJ[3].fields[ROLE.fire_mode] = 1; OBJ[3].fields[ROLE.underbarrel] = 32767
OBJ[3].fields[ROLE.reload_stage] = 0
OBJ[4] = { name = NAMES.unk, fields = {} }        -- a weapon NarrowHUD has never seen: 12 rounds, 3 magazines
OBJ[4].fields[ROLE.rounds] = 12; OBJ[4].fields[ROLE.magazines] = 3; OBJ[4].fields[ROLE.chamber] = true
OBJ[4].fields[ROLE.fire_mode] = 2; OBJ[4].fields[ROLE.reload_stage] = 0
OBJ[5] = { name = NAMES.nova, fields = {} }       -- Nova: heat
OBJ[5].fields[ROLE.heat] = 5; OBJ[5].fields[ROLE.overheated] = false; OBJ[5].fields[ROLE.charging] = false
OBJ[5].fields[ROLE.carry] = 0; OBJ[5].fields[ROLE.magazines] = 0
local function rec(t) draws[#draws + 1] = t end
chef = {
  log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
  own_log = function() return true end,
  time = function() return T end, in_mission = function() return true end,
  screen = function() return 3440, 1440 end,
  world = function() return 'W' end, world_id = function() return WORLD end,
  setting = function(path)
    if path == 'screen_resolution' then return { 3440, 1440 } end
    if path == 'render_settings.render_resolution' then return { RENDER_W, RENDER_H } end
  end,
  color = function(r, g, b, a) return { r, g, b, a } end,
  rect = function(x, y, w, h, c, l) rec({ 'rect', x, y, w, h, c[1], c[2], c[3], c[4] }) end,
  triangle = function(x1, y1, x2, y2, x3, y3, c, l)
    if TRI_ROWS then return false end
    rec({ 'tri', x1, y1, x2, y2, c[1], c[2], c[3], c[4], x3 = x3, y3 = y3 }) return true end,
  text = function(x, y, s, px, c, l) rec({ 'text', x, y, s, px, c[1], c[2], c[3], c[4] }) end,
  text_width = function(s, px) return #s * 6 * px - px end,
  sprite = function(x, y, rows, cell, colors, l)
    for r, line in ipairs(rows) do
      for i = 1, #line do
        local c = colors[line:sub(i, i)]
        if c then rec({ 'cell', x + (i - 1) * cell, y + (#rows - r) * cell, cell, cell, c[1], c[2], c[3], c[4] }) end
      end
    end
    rec({ 'sprite', x, y, #rows, cell, 0, 0, 0, 0 })
  end,
  has = function(x) return x == 'menu' or x == 'bind' end, title = function() end,
  bind = function(id, key, label) return { pressed = function() return BINDS[id] == true or KEYS[key] == true end,
    down = function() return BINDS[id] == true end, key = function() return key end }, { row = id } end,
  call = BUILD_ID and function(name) if name == 'Application.build_identifier' then return BUILD_ID end end or nil,
  option = function(id, spec) if OPTS[id] ~= nil then return OPTS[id] end return spec.default end,
  on_change = function(id, f) CHANGE[id] = f end,
  key_pressed = function(k) return KEYS[k] == true end, wheel = function() return WHEEL end,
  load_table = function(n) if n == 'layout' then if LAYOUT_ERR then return nil, LAYOUT_ERR end if LAYOUT == nil then return nil, 'none saved' end return LAYOUT end return saved end,
  save_table = function(n, t) if n == 'layout' then LAYOUT = t else saved = t end end,
  watch = function(kinds)
    if kinds and kinds['16f397ca5f51f271'] then return setmetatable({}, { __index = function(t, k) if k == 'items' then return BALL and { { unit = 'B' } } or {} end end }) end
    return { items = { { unit = 'U', x = 0, y = 0, z = 0 } } }
  end,
  camera = function() return { x = 0, y = 0, z = 1, yaw = CAM_YAW or 0, fx = math.sin(CAM_YAW or 0), fy = math.cos(CAM_YAW or 0), fz = CAM_FZ or 0 } end,
  line = function(x1, y1, z1, x2, y2, z2, c) rec({ 'line', x1, y1, z1, x2, y2, c[1], c[2], c[3], c[4], z2 = z2 }) end,
  -- (BITMAP false: the texture can't be drawn, as Chef answers when it isn't loaded)
  bitmap = function(tex, x, y, w, h, c, l) if BITMAP == false then return false end rec({ 'bitmap', x, y, w, h, c[1], c[2], c[3], c[4], tex = tex }) return true end,
  texture_sizes = function(map) TEX_SIZES = map end,
  -- (a flat stand-in projection: 1000 px a metre of x over y metres ahead, from the screen's centre; nil behind)
  world_to_screen = function(x, y, z)
    if W2S == false then return nil end
    local yaw = CAM_YAW or 0
    local fx, fy = x * math.cos(yaw) - y * math.sin(yaw), x * math.sin(yaw) + y * math.cos(yaw)
    if fy <= 0.5 then return nil end
    return 1720 + fx / fy * 1000, 720 + (z - 1) / fy * 1000
  end,
  unit_alive = function() return true end,
  unit_position = function(u, node) if WPOS and WPOS[u] == false then return nil end if WPOS and WPOS[u] then return WPOS[u][1], WPOS[u][2], WPOS[u][3] end return 100, 200, 10 end,
  unit_kind = function(u) return u == 'U' and 'a57ae2a703c02899' or (u == 'B' and '16f397ca5f51f271' or 'wkind') end,
  unit_node = function(u, name) if u == 'U' and name == 'attach_hand_r' then return 42 end return nil end,
  call_kind = function(name, kind, s, a, b, c, d, e, f)
    if name == 'Network.game_session' then return 'S' end
    if name == 'Network.peer_id' then return '0b99cf5492296d6e' end
    if name == 'GameSession.game_session_host' then return HOST end
    if BLOCKED and (name == 'GameSession.objects_owned_by' or name == 'GameSession.game_object_is_type') then return nil, 'refused' end
    if name == 'GameSession.objects_owned_by' then
      local l = {}
      if a == '0b99cf5492296d6e' then for k in pairs(OBJ) do if not HOSTS[k] then l[#l + 1] = k end end
      else for k in pairs(HOSTS) do if OBJ[k] then l[#l + 1] = k end end end
      return l
    end
    if name == 'GameSession.game_object_is_type' then return OBJ[a] ~= nil and OBJ[a].name == b end
    if name == 'GameSession.game_object_exists' then return OBJ[a] ~= nil end
    if name == 'GameSession.game_object_field' then
      if OBJ[a] == nil then error('read of a gone object ' .. tostring(a)) end   -- in the game: may end it
      local v = OBJ[a].fields[b]
      if v == nil and b == ROLE.held then return FIRE == true end   -- (the player's own weapons: held as you fire, unless a test says)
      return v
    end
    if name == 'Unit.has_animation_state_machine' or name == 'Unit.animation_has_variable' then return true end
    if name == 'Unit.animation_find_variable' then return 3 end
    if name == 'Unit.animation_get_variable' then return GRIP end
    if name == 'Application.can_get' then return GAME_FONT end
    if name == 'Network.object_info' and OBJINFO then return OBJINFO(s) end
    if name == 'Mouse.button_index' then return s == 'right' and 1 or 0 end
    if name == 'Mouse.button' then if s == 1 then return AIM and 1 or 0 end return (FIRE and not PAD) and 1 or 0 end
    -- (PADN: the controller in use; NOPAD: its trigger can't be read at all)
    local pn, pf = name:match('^Pad(%d)%.(.*)$')
    if pn then
      pn = tonumber(pn)
      local mine = pn == (PADN or 1)
      -- (PADNAMES false: the pad doesn't list its buttons; PS: a PlayStation pad's names)
      if pf == 'active' then return mine end
      if pf == 'connected' then return false end
      if pf == 'num_buttons' then return PADNAMES ~= false and 6 or nil end
      if pf == 'button_name' then return (PS and { [0] = 'cross', 'circle', 'square', 'triangle', 'l2', 'r2' }
                                             or { [0] = 'a', 'b', 'x', 'y', 'left_trigger', 'right_trigger' })[s] end
      if pf == 'button_index' then return (pn == 1 and not PS) and ((s == 'y' and 3) or (s == 'right_trigger' and 5) or (s == 'left_shoulder' and 4)) or nil end
      if pf == 'button' then return (s == 5 and FIRE and PAD and not NOPAD and mine) and 1 or 0 end
      if pf == 'pressed' then return s == 3 and mine and PADY == true end
    end
    if name == 'GameSession.objects_owned_by' and BLOCKED then return nil, 'refused' end
    if name == 'GameSession.game_object_is_type' and BLOCKED then return nil, 'refused' end
    if name == 'GameSession.unit_synchronizer' then if NOSYNC then return nil, 'refused' end return 'SYNC' end
    if name == 'UnitSynchronizer.unit_to_game_object_id' then return 2 end
    if name == 'UnitSynchronizer.game_object_id_to_unit' then
      if NOSYNC then return nil end
      if OBJ[a] and OBJ[a].name == NAMES.avatar then return 'U' end
      return WUNITS and WUNITS[a] or nil
    end
    if name == 'World.create_screen_gui' then GUIS = GUIS + 1 return 'G' end
    if name == 'Vector3' then return { s, a, b } end
    if name == 'Vector3.to_elements' then if type(s) == 'table' then return s[1], s[2], s[3] end return nil end
    -- Gui.text_extents(gui, s, font, size): min and max corners
    if name == 'Gui.text_extents' then return string.format('Vector3(0, %g, 0)', -0.02 * c), string.format('Vector3(%g, %g, 0)', #a * c * 0.55, c * 0.68) end
    -- Gui.text(gui, s, font, size, material, pos, color): pos is the baseline
    if name == 'Gui.text' then
      rec({ 'text', e[1], e[2], a, math.floor(c * 0.70 / 7 + 0.5), f[1], f[2], f[3], f[4], game = true, size = c })
      return true
    end
    error('unexpected call ' .. name)
  end,
}
function run(seconds)
  local n = math.floor(seconds * 60)
  for i = 1, n do draws = {} T = T + 1 / 60 M.update(1 / 60) end
end
function texts()
  local l = {}
  for _, d in ipairs(draws) do if d[1] == 'text' then l[#l + 1] = d[4] end end
  return table.concat(l, ' | ')
end
function count(kind, game)
  local n = 0
  for _, d in ipairs(draws) do if d[1] == kind and (game == nil or (d.game == true) == game) then n = n + 1 end end
  return n
end
""")
    rt.execute('GAME_FONT = %s' % ('true' if game_font else 'false'))
    if chef11:
        rt.execute('chef.text_fit = function() end')
    rt.execute('M = (function(...) ' + (SEEDED_SRC if seeded else SRC) + ' end)(chef)')
    return unknown_id


def main():
    rt = lua51.LuaRuntime()
    unknown_id = setup(rt)
    fails = []

    def check(what, ok):
        print(('ok   ' if ok else 'FAIL ') + what)
        if not ok:
            fails.append(what)

    # every name the modules use is theirs, imported, or Lua's (tools/lint_globals.py)
    import subprocess
    lint = subprocess.run([sys.executable, str(Path(__file__).resolve().parent.parent / 'tools' / 'lint_globals.py')],
                          capture_output=True, text=True)
    check('modules: no stray globals %s' % lint.stdout.split('\n')[:3], lint.returncode == 0)
    check('Keep-On-Crash header within the first 400 characters', '\n-- HD2-Keep-On-Crash: yes' in SRC[:400])
    rt.execute('run(3)')
    t = rt.eval('texts()')
    check('Arbitrator in hand (pose 10): 45 shown (44 + chamber) with x7 [%s]' % t, '45' in t and 'x7' in t)
    check('drawn in the game font', rt.eval('count("text", true)') > 0 and rt.eval('count("text", false)') == 0)
    check('one GUI made for the world', rt.eval('GUIS') == 1)
    check('grenade and stim icons with counts 4 and 5', rt.eval('count("sprite") + count("bitmap")') == 2 and '4' in t and '5' in t)
    rt.execute('OBJ[3].fields[ROLE.rounds] = 30 run(0.5)')
    t = rt.eval('texts()')
    check('after shooting: 31 [%s]' % t, '31' in t)
    ticks = rt.eval("(function() local n = 0 for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 14 then n = n + 1 end end return n end)()")
    check('a 44-round magazine at Medium (over 33): a solid bar, %d bar rects' % ticks, ticks == 2)
    rt.execute('OBJ[3].fields[ROLE.rounds] = 0 OBJ[3].fields[ROLE.chamber] = false run(0.5)')
    t = rt.eval('texts()')
    check('magazine empty, one in the chamber: 1 [%s]' % t, t.split(' | ')[0] == '1')
    rt.execute('OBJ[3].fields[ROLE.rounds] = 44 OBJ[3].fields[ROLE.chamber] = true run(0.5)')
    check('full reload from empty: 44 [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('44 |'))
    check('magazine learned as 44, not 45', rt.eval('saved == nil or saved.mag == nil or saved.mag["8fcdd35c"] == nil or saved.mag["8fcdd35c"] == 44') is True)
    rt.execute('OBJ[3].fields[ROLE.rounds] = 30 run(0.5)')

    # an unseen weapon: not shown before its first shot, then learned
    rt.execute('GRIP = 70 run(1)')
    t = rt.eval('texts()')
    check('unknown weapon in hand (pose 70): not shown before it fires [%s]' % t, '12' not in t)
    rt.execute('OBJ[4].fields[ROLE.rounds] = 11 run(0.5)')
    logs = list(rt.eval('logs').values())
    check('learned on the first shot', any(('learned: type %s goes with hand pose 70' % unknown_id) in l for l in logs))
    t = rt.eval('texts()')
    check('then shown: 11 (its chamber is loaded) x3 [%s]' % t, t.startswith('11 | x3'))
    rt.execute('run(6)')
    check('learned table saved', rt.eval('saved ~= nil and saved.poses["%s"] == "70"' % unknown_id) is True)

    # a stratagem or grenade in hand (poses 40 and 41): no weapon bar even with an unlearned weapon on you
    rt.execute('OBJ[4].fields[ROLE.rounds] = 11 GRIP = 40 run(1)')
    check('stratagem in hand (pose 40): only the grenade/stim line [%s]' % rt.eval('texts()'),
          rt.eval('count("rect")') == 0 and rt.eval('count("sprite") + count("bitmap")') == 2)

    # Nova (seeded pose 52, rests at 5, 1.6 s charge)
    rt.execute('GRIP = 52 run(1)')
    t = rt.eval('texts()')
    check('Nova cooled to its rest (heat 5): 0%% [%s]' % t, 'HEAT' in t and '0%' in t.split(' | '))
    rt.execute('OBJ[5].fields[ROLE.charging] = true run(0.8)')
    t = rt.eval('texts()')
    pct = int([x for x in t.split(' | ') if x.endswith('%')][0][:-1])
    check('charging 0.8 s of 1.6 s: about half [%d%%]' % pct, 40 <= pct <= 60)
    a = rt.eval('texts()'); rt.execute('run(1 / 60)'); b = rt.eval('texts()')
    rt.execute('run(1 / 60)'); c = rt.eval('texts()')
    check('charging: the percentage moves every frame or two [%s / %s / %s]' % (a, b, c), a != c)
    rt.execute('run(0.9)')
    t = rt.eval('texts()')
    check('charged: 100%% [%s]' % t, '100%' in t)
    rt.execute('OBJ[5].fields[ROLE.charging] = false OBJ[5].fields[ROLE.heat] = 100 OBJ[5].fields[ROLE.overheated] = true run(0.5)')
    t = rt.eval('texts()')
    check('shot, overheated: 100%% [%s]' % t, '100%' in t)
    # cooling while still overheated (the Nova, the Quasar), the field stepping once a second: runs on between steps
    rt.execute('''OBJ[5].fields[ROLE.heat] = 90 run(1) OBJ[5].fields[ROLE.heat] = 70 run(1) OBJ[5].fields[ROLE.heat] = 50 run(1)
      OBJ[5].fields[ROLE.heat] = 30 run(0.3)''')
    a = rt.eval('texts()'); rt.execute('run(0.4)'); b = rt.eval('texts()')
    pa = int([x for x in a.split(' | ') if x.endswith('%')][0][:-1]); pb = int([x for x in b.split(' | ') if x.endswith('%')][0][:-1])
    check('overheated and cooling: moves between the field\'s steps (%d%% then %d%%)' % (pa, pb), pb < pa)
    # cools to 4 and stays: learns 4 as its rest
    rt.execute('OBJ[5].fields[ROLE.overheated] = false OBJ[5].fields[ROLE.heat] = 60 run(0.3) OBJ[5].fields[ROLE.heat] = 4 run(5.5)')
    t = rt.eval('texts()')
    check('cooled and learned the rest (4): 0%% [%s]' % t, '0%' in t.split(' | ') and rt.eval('saved.rest2["17783758"]') in (None, 4) )
    check('rest logged', any('cools down to 4.0' in l for l in rt.eval('logs').values()))

    # cooling with the field changing only twice a second: the bar moves every frame in between
    rt.execute('OBJ[5].fields[ROLE.heat] = 90 run(0.5) OBJ[5].fields[ROLE.heat] = 74 run(0.5) OBJ[5].fields[ROLE.heat] = 58 run(0.2)')
    a = rt.eval('texts()')
    rt.execute('run(0.2)')
    b = rt.eval('texts()')
    pa = int([x for x in a.split(' | ') if x.endswith('%')][0][:-1]); pb = int([x for x in b.split(' | ') if x.endswith('%')][0][:-1])
    check('cooling runs between field changes: %d%% then %d%%' % (pa, pb), pb < pa < 57)
    rt.execute('OBJ[5].fields[ROLE.heat] = 4 run(2)')

    # an expendable weapon used up: its object goes; it's never read again
    rt.execute('OBJ[6] = { name = NAMES.unk2, fields = {} } OBJ[6].fields[ROLE.rounds] = 1 OBJ[6].fields[ROLE.magazines] = 0 GRIP = 20 run(2)')
    rt.execute('OBJ[6].fields[ROLE.rounds] = 0 run(0.1) OBJ[6] = nil')
    try:
        rt.execute('run(2)')
        check('a weapon gone between reads: no read of it, no error', True)
    except Exception as e:
        check('a weapon gone between reads: no read of it, no error (%s)' % e, False)

    # a tactical reload: 44 in the magazine and one in the chamber: a 45th tick, gone after the first shot
    # (at Huge, up to 50 rounds are ticks)
    rt.execute('CHANGE.size(4) GRIP = 10 OBJ[3].fields[ROLE.rounds] = 44 OBJ[3].fields[ROLE.chamber] = false run(0.5)')
    n = rt.eval("(function() local n = 0 for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 21 then n = n + 1 end end return n end)()")
    check('Huge, tactical reload: 45 ticks for 44 + 1 (%d)' % n, n == 45)
    rt.execute('OBJ[3].fields[ROLE.rounds] = 43 run(0.5)')
    n = rt.eval("(function() local n = 0 for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 21 then n = n + 1 end end return n end)()")
    check('after its first shot: 44 ticks again (%d)' % n, n == 44)
    rt.execute('CHANGE.size(2) run(0.3)')

    # an attachment's shorter magazine (the Liberator Penetrator's 30 instead of 45): once reloaded, a full 30 reads
    # full, not 2/3 (at a mission's start it's known at once: you drop with full magazines)
    ticks = "(function() local lit, all = 0, 0 for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 14 then all = all + 1 if d[9] ~= 55 then lit = lit + 1 end end end return lit .. '/' .. all end)()"
    rt.execute('''OBJ[3].fields[ROLE.carry] = 1 OBJ[46] = { name = NAMES.arb, fields = {} } OBJ[46].fields[ROLE.rounds] = 20
      OBJ[46].fields[ROLE.chamber] = true OBJ[46].fields[ROLE.magazines] = 7 OBJ[46].fields[ROLE.carry] = 0
      OBJ[46].fields[ROLE.fire_mode] = 1 OBJ[46].fields[ROLE.underbarrel] = 32767 OBJ[46].fields[ROLE.reload_stage] = 0
      GRIP = 10 run(3)''')
    check('a 20-round magazine, size not known yet: the learned 44, a solid bar (%s)' % rt.eval(ticks), rt.eval(ticks) == '2/2')
    rt.execute('OBJ[46].fields[ROLE.rounds] = 30 run(0.5)')
    check('reloaded to 30: 30 ticks, all full (%s)' % rt.eval(ticks), rt.eval(ticks) == '30/30')
    rt.execute('OBJ[46] = nil OBJ[3].fields[ROLE.carry] = 0 run(2)')

    # a single-shot underbarrel launcher: no shell in the slot, one in the chamber: 1
    rt.execute('''OBJ[3].fields[ROLE.underbarrel] = 8 OBJ[3].fields[ROLE.fire_mode] = 8
      OBJ[8] = { name = NAMES.ubgl, fields = {} } OBJ[8].fields[ROLE.slot0] = 0 OBJ[8].fields[ROLE.slot1] = 0
      OBJ[8].fields[ROLE.selected] = 0 OBJ[8].fields[ROLE.chamber] = false OBJ[8].fields[ROLE.spare] = 4 run(2)''')
    t = rt.eval('texts()')
    check('underbarrel launcher with its shell chambered: 1 x4 [%s]' % t, t.startswith('1 | x4'))
    full = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 14 then return d[6] .. ',' .. d[9] end end end)()")
    check('its one tick full, in the normal color (%s)' % full, full == '236,235')
    rt.execute('OBJ[3].fields[ROLE.fire_mode] = 1 OBJ[3].fields[ROLE.underbarrel] = 32767 OBJ[8] = nil run(1.5)')

    # a weapon fed from its backpack (no ammo of its own): learned when the pack's ammo goes down, the pack's ammo shown
    rt.execute('''OBJ[9] = { name = NAMES.pack, fields = {} } OBJ[9].fields[ROLE.remaining] = 300 OBJ[9].fields[ROLE.carry] = 0
      OBJ[10] = { name = NAMES.fed, fields = {} } OBJ[10].fields[ROLE.carry] = 0 OBJ[10].fields[ROLE.fire_mode] = 1
      OBJ[10].fields[ROLE.reload_stage] = 0 GRIP = 50 run(2)''')
    check('fed weapon before it fires: not shown [%s]' % rt.eval('texts()'), '300' not in rt.eval('texts()'))
    rt.execute('OBJ[9].fields[ROLE.remaining] = 290 run(0.5)')
    t = rt.eval('texts()')
    check('fed weapon learned and shown with the pack\'s ammo: 290 [%s]' % t, t.startswith('290 |') or t.startswith('290'))
    check('no backpack bar beside the icons for a fed weapon', rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 then return false end end return true end)()") is True)
    check('learned log line', any('fed from the backpack' in l for l in rt.eval('logs').values()))
    # swapped to another fed weapon and its own pack on the same pose: the bar is that pack's, not the first one's
    rt.execute('''OBJ[9] = nil OBJ[10] = nil
      OBJ[36] = { name = NAMES.crempack, fields = {} } OBJ[36].fields[ROLE.remaining] = 500 OBJ[36].fields[ROLE.carry] = 0
      OBJ[37] = { name = NAMES.crem, fields = {} } OBJ[37].fields[ROLE.carry] = 0 OBJ[37].fields[ROLE.fire_mode] = 1
      OBJ[37].fields[ROLE.reload_stage] = 0 run(3) OBJ[36].fields[ROLE.remaining] = 400 run(0.5) OBJ[36].fields[ROLE.remaining] = 250 run(0.5)''')
    n = rt.eval("(function() local n = 0 for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 14 then n = n + 1 end end return n end)()")
    w = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 14 and d[9] == 235 then return d[4] end end end)()")
    check('the other fed weapon: 250 of its pack\'s 500 (%s of 260) [%s]' % (w, rt.eval('texts()')), w and abs(w / 260 - 0.5) < 0.02)
    rt.execute('OBJ[36] = nil OBJ[37] = nil GRIP = 10 run(1.5)')

    # the Stoker: its underbarrel flamethrower is an object on your body too; fired, it must not become "the weapon"
    rt.execute('''OBJ[11] = { name = NAMES.ub2, fields = {} } OBJ[11].fields[ROLE.rounds] = 100 OBJ[11].fields[ROLE.magazines] = 2
      OBJ[11].fields[ROLE.chamber] = true OBJ[11].fields[ROLE.carry] = 0
      OBJ[3].fields[ROLE.underbarrel] = 11 OBJ[3].fields[ROLE.fire_mode] = 9 OBJ[3].fields[ROLE.rounds] = 30 GRIP = 10 run(1.5)''')
    rt.execute('OBJ[11].fields[ROLE.rounds] = 90 run(0.5) OBJ[11].fields[ROLE.rounds] = 80 run(0.5)')
    t = rt.eval('texts()')
    check('firing the underbarrel: UB stays, its 80 shown [%s]' % t, '80' in t and 'UB' in t)
    check('the underbarrel never learned as a weapon', rt.eval('saved == nil or saved.grip == nil or saved.grip["%s"] == nil' % rt.eval('NAMES.ub2id')) is True)
    rt.execute('OBJ[3].fields[ROLE.fire_mode] = 1 run(0.3)')
    t = rt.eval('texts()')
    check('switched back without firing: the rifle 31 at once [%s]' % t, t.startswith('31 |'))
    rt.execute('OBJ[3].fields[ROLE.underbarrel] = 32767 OBJ[11] = nil run(1.5)')

    # fire modes and rates of fire: shown once two have been seen
    rt.execute('OBJ[3].fields[ROLE.fire_mode] = 2 run(0.3)')
    t = rt.eval('texts()')
    check('two fire modes seen: SEMI shown [%s]' % t, 'SEMI' in t)
    rt.execute('OBJ[3].fields[ROLE.fire_mode] = 1 run(0.3)')

    # the backpack bar: the one pack on you (its owner field you), how full against the most it held
    rt.execute('''OBJ[12] = { name = NAMES.pack2, fields = {} } OBJ[12].fields[ROLE.remaining] = 4 OBJ[12].fields[ROLE.carry] = 0
      OBJ[12].fields[ROLE.owner] = '0b99cf5492296d6e' run(2.5) OBJ[12].fields[ROLE.remaining] = 2 run(0.5)''')
    w = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 215 then return d[4] end end end)()")
    bg = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 45 then return d[4] end end end)()")
    check('backpack half full (2 of the 4 seen) (%s of %s)' % (w, bg), w and bg and abs(w / bg - 0.5) < 0.02)
    # another player's pack (its owner field someone else) beside it: still yours shown
    rt.execute('''OBJ[35] = { name = NAMES.pack2, fields = {} } OBJ[35].fields[ROLE.remaining] = 1 OBJ[35].fields[ROLE.carry] = 0
      OBJ[35].fields[ROLE.owner] = '2222222222222222' run(2)''')
    w = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 215 then return d[4] end end end)()")
    check('someone else\'s pack beside it: yours still shown (%s)' % w, w and abs(w / bg - 0.5) < 0.02)
    rt.execute('OBJ[35] = nil')
    rt.execute('OBJ[12] = nil run(1.5)')

    # the Laser Cannon: heats up while the trigger is held ("charging"), the field changing only every 3 s
    rt.execute('''OBJ[13] = { name = NAMES.laser, fields = {} } OBJ[13].fields[ROLE.heat] = 0 OBJ[13].fields[ROLE.overheated] = false
      OBJ[13].fields[ROLE.charging] = false OBJ[13].fields[ROLE.held] = false OBJ[13].fields[ROLE.carry] = 0
      OBJ[13].fields[ROLE.magazines] = 2 GRIP = 20 run(1.5)
      OBJ[13].fields[ROLE.charging] = true OBJ[13].fields[ROLE.held] = true run(3) OBJ[13].fields[ROLE.heat] = 30 run(3) OBJ[13].fields[ROLE.heat] = 60 run(0.2)''')
    logs = list(rt.eval('logs').values())
    check('the Laser Cannon learned by its heat going up', any('goes with hand pose 20' in l for l in logs))
    check('never taken for a charge weapon', rt.eval('saved == nil or saved.charge2 == nil or saved.charge2["d100e0c8"] == nil') is True)
    def pct():
        t = rt.eval('texts()')
        return int([x for x in t.split(' | ') if x.endswith('%')][0][:-1])
    rt.execute('OBJ[13].fields[ROLE.held] = true run(1)')
    pa = pct(); rt.execute('run(1)'); pb = pct()
    check('firing: the bar rises at 8/s between the field\'s changes (%d%% then %d%%)' % (pa, pb), 6 <= pb - pa <= 10 and pb < 90)
    # released: no drop at once, it goes down at 5/s
    rt.execute('OBJ[13].fields[ROLE.held] = false run(0.05)')
    pc = pct()
    check('released: no sudden drop (%d%% -> %d%%)' % (pb, pc), abs(pc - pb) <= 2)
    rt.execute('run(1)'); pd = pct()
    check('then cooling at 5/s (%d%% -> %d%%) %s' % (pc, pd, [l for l in rt.eval('logs').values() if 'planet' in l]), 3 <= pc - pd <= 7)
    # outlines on, cooling: the outline stays put, only the fill inside shrinks
    def outline_rects():
        return sorted(tuple(d[i] for i in range(2, 6)) for d in rt.eval('draws').values() if d[1] == 'rect' and d[9] == 190)
    rt.execute('CHANGE.outline(true) run(0.1)')
    oa = outline_rects(); rt.execute('run(1)'); ob = outline_rects()
    check('outlines, cooling: the outline stays put (%d rects)' % len(oa), len(oa) >= 4 and oa == ob)
    rt.execute('CHANGE.outline(false) run(0.1)')
    pd = pct()
    # a new field value close to the model: folded in, no jump
    rt.execute('OBJ[13].fields[ROLE.heat] = %d run(0.05)' % (pd - 3))
    pe = pct()
    check('a field value 3 off: no jump (%d%% -> %d%%)' % (pd, pe), abs(pe - pd) <= 2)
    rt.execute('OBJ[13] = nil GRIP = 10 run(1.5)')

    # the Warrant: guided / unguided on the left
    rt.execute('''OBJ[14] = { name = NAMES.warrant, fields = {} } OBJ[14].fields[ROLE.rounds] = 5 OBJ[14].fields[ROLE.chamber] = true
      OBJ[14].fields[ROLE.magazines] = 3 OBJ[14].fields[ROLE.carry] = 0 OBJ[14].fields[ROLE.options] = 0 GRIP = 1 run(3)
      OBJ[14].fields[ROLE.rounds] = 4 run(0.5)''')
    check('Warrant (named): GUIDED at once [%s]' % rt.eval('texts()'), 'GUIDED' in rt.eval('texts()'))
    rt.execute('OBJ[14].fields[ROLE.options] = 4 run(0.5)')
    check('Warrant switched to options 4 (slot value 1): UNGUIDED [%s]' % rt.eval('texts()'), 'UNGUIDED' in rt.eval('texts()'))
    rt.execute('OBJ[14].fields[ROLE.options] = 80 run(0.5)')
    check('options 80: GUIDED [%s]' % rt.eval('texts()'), 'GUIDED' in rt.eval('texts()') and 'UNGUIDED' not in rt.eval('texts()'))
    rt.execute('OBJ[14].fields[ROLE.options] = 4176 run(0.5)')
    check('the fire-mode bits (4096) are not a weapon mode: GUIDED still [%s]' % rt.eval('texts()'), 'GUIDED' in rt.eval('texts()'))
    check('research log line for its fields', any('fields c920c2d3: fire_mode=nil options=4 ' in l for l in rt.eval('logs').values()))
    rt.execute('OBJ[14] = nil GRIP = 10 run(1.5)')

    # something in hand NarrowHUD doesn't show (the C4 before it's learned): the stim and grenade line still
    rt.execute('GRIP = 42 run(2.5)')
    check('unknown thing in hand: the stim and grenade line [%s]' % rt.eval('texts()'), rt.eval('texts()') == '5 | 4')

    # the C4: one charge in the hand, the spare ones in its backpack
    rt.execute('''OBJ[15] = { name = NAMES.c4, fields = {} } OBJ[15].fields[ROLE.slot0] = 0 OBJ[15].fields[ROLE.slot1] = 0
      OBJ[15].fields[ROLE.selected] = 0 OBJ[15].fields[ROLE.chamber] = false OBJ[15].fields[ROLE.spare] = 0 OBJ[15].fields[ROLE.carry] = 0 OBJ[15].fields[ROLE.options] = 80
      OBJ[16] = { name = NAMES.c4pack, fields = {} } OBJ[16].fields[ROLE.remaining] = 6 OBJ[16].fields[ROLE.carry] = 0
      GRIP = 42 run(3) OBJ[15].fields[ROLE.chamber] = true run(0.5)
      OBJ[15].fields[ROLE.chamber] = false OBJ[16].fields[ROLE.remaining] = 5 run(0.5)''')
    t = rt.eval('texts()')
    check('C4 options 80: DEPLOY [%s]' % t, 'DEPLOY' in t)
    rt.execute('OBJ[15].fields[ROLE.options] = 336 run(0.5)')
    check('C4 options 336: DETONATE [%s]' % rt.eval('texts()'), 'DETONATE' in rt.eval('texts()'))
    rt.execute('OBJ[15].fields[ROLE.options] = 80 run(0.5)')
    check('C4 learned as reloading from the backpack', any('reloads from the backpack' in l for l in rt.eval('logs').values()))
    t = rt.eval('texts()')
    check('C4: 1 in hand, x5 in the backpack [%s]' % t, t.startswith('1 | x5'))
    rt.execute('OBJ[15] = nil OBJ[16] = nil GRIP = 10 run(1.5)')

    # the Autocannon: a backpack reload must not teach the fed type riding along (on the same pose) that it fired
    rt.execute('''OBJ[17] = { name = NAMES.ac, fields = {} } OBJ[17].fields[ROLE.slot0] = 3 OBJ[17].fields[ROLE.slot1] = 0
      OBJ[17].fields[ROLE.selected] = 0 OBJ[17].fields[ROLE.chamber] = false OBJ[17].fields[ROLE.spare] = 0
      OBJ[17].fields[ROLE.carry] = 0 OBJ[17].fields[ROLE.reload_stage] = 0
      OBJ[18] = { name = NAMES.acfed, fields = {} } OBJ[18].fields[ROLE.carry] = 0 OBJ[18].fields[ROLE.fire_mode] = 5
      OBJ[19] = { name = NAMES.acpack, fields = {} } OBJ[19].fields[ROLE.remaining] = 30 OBJ[19].fields[ROLE.carry] = 0
      GRIP = 22 run(3) OBJ[17].fields[ROLE.slot0] = 2 run(0.5)
      OBJ[17].fields[ROLE.reload_stage] = 1 OBJ[19].fields[ROLE.remaining] = 25 run(0.3)
      OBJ[17].fields[ROLE.slot0] = 7 run(0.3) OBJ[17].fields[ROLE.reload_stage] = 0 run(1)''')
    logs = list(rt.eval('logs').values())
    check('Autocannon learned as reloading from the backpack', any('7bfb2e06 reloads from the backpack' in l for l in logs))
    check('its fed partner not learned on the reload', not any('903649ec (fed' in l for l in logs))
    t = rt.eval('texts()')
    check('Autocannon after the reload: 8 x25 [%s]' % t, t.startswith('8 | x25'))
    check('research log: a reload line', any(l.startswith('reload 7bfb2e06:') for l in logs))
    rt.execute('OBJ[17] = nil OBJ[18] = nil OBJ[19] = nil GRIP = 10 run(1.5)')

    # a single-shot launcher (the Recoilless): magazine 0, one in the chamber: one full tick, normal color, HEAT
    rt.execute('''OBJ[21] = { name = NAMES.rr, fields = {} } OBJ[21].fields[ROLE.rounds] = 0 OBJ[21].fields[ROLE.magazines] = 0
      OBJ[21].fields[ROLE.chamber] = true OBJ[21].fields[ROLE.carry] = 0 OBJ[21].fields[ROLE.options] = 80
      GRIP = 20 run(3) OBJ[21].fields[ROLE.chamber] = false run(0.5) OBJ[21].fields[ROLE.chamber] = true run(0.5)
      OBJ[21].fields[ROLE.chamber] = false run(0.5)''')
    t = rt.eval('texts()')
    full = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 14 then return d[6] .. ',' .. d[9] end end end)()")
    check('Recoilless loaded: 1, HEAT, one full cream tick [%s] (%s)' % (t, full), t.startswith('1 |') and 'HEAT' in t and full == '236,235')
    rt.execute('OBJ[21] = nil GRIP = 10 run(1.5)')

    # the Railgun: a charge meter over the bar while the trigger is held, SAFE / UNSAFE on the left
    rt.execute('''OBJ[22] = { name = NAMES.rail, fields = {} } OBJ[22].fields[ROLE.rounds] = 1 OBJ[22].fields[ROLE.magazines] = 19
      OBJ[22].fields[ROLE.chamber] = true OBJ[22].fields[ROLE.carry] = 0 OBJ[22].fields[ROLE.held] = false
      OBJ[22].fields[ROLE.fire_mode] = 5 GRIP = 61 run(2) OBJ[22].fields[ROLE.held] = true run(0.3)
      OBJ[22].fields[ROLE.rounds] = 0 OBJ[22].fields[ROLE.held] = false run(0.5)
      OBJ[22].fields[ROLE.fire_mode] = 6 run(0.3) OBJ[22].fields[ROLE.held] = true run(1.5)''')
    t = rt.eval('texts()')
    meter = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[9] == 230 then return d[4] end end end)()")
    check('Railgun UNSAFE on the left [%s]' % t, 'UNSAFE' in t)
    check('charge meter half full after 1.5 of 3 s (%s of 260)' % meter, meter and 120 <= meter <= 140)
    # SAFE: the meter fills to 60 % in about 1.7 s and stays there, never red (it can't blow up)
    rt.execute('OBJ[22].fields[ROLE.held] = false run(0.3) OBJ[22].fields[ROLE.fire_mode] = 5 OBJ[22].fields[ROLE.held] = true run(3.5)')
    m2 = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[9] == 230 then return d[4] .. ',' .. d[6] end end end)()")
    check('Railgun SAFE held 3.5 s: the meter at 60 %%, not red (%s)' % m2, m2 and m2.startswith('156,') and not m2.endswith(',225'))
    rt.execute('OBJ[22].fields[ROLE.held] = false run(0.2)')
    check('released: no meter', rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[9] == 230 then return true end end return false end)()") is False)
    rt.execute('OBJ[22] = nil GRIP = 10 run(1.5)')

    rt.execute('OBJ[23] = nil GRIP = 10 run(1.5)')

    # the Spear: lock-on progress as a line over the bar, orange once locked
    rt.execute('''OBJ[24] = { name = NAMES.spear, fields = {} } OBJ[24].fields[ROLE.rounds] = 0 OBJ[24].fields[ROLE.magazines] = 0
      OBJ[24].fields[ROLE.chamber] = true OBJ[24].fields[ROLE.carry] = 0 OBJ[24].fields[ROLE.lock] = 0
      OBJ[24].fields[ROLE.locked] = false GRIP = 20 run(3) OBJ[24].fields[ROLE.chamber] = false run(0.5)
      OBJ[24].fields[ROLE.chamber] = true run(0.5) OBJ[24].fields[ROLE.chamber] = false run(0.5) OBJ[24].fields[ROLE.lock] = 0.5 run(0.1)''')
    meter = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[9] == 230 then return d[4] .. ',' .. d[6] end end end)()")
    check('lock-on half way: a half line, cream (%s)' % meter, meter and meter.startswith('130,236'))
    rt.execute('OBJ[24].fields[ROLE.lock] = 1 OBJ[24].fields[ROLE.locked] = true run(0.1)')
    meter = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[9] == 230 then return d[4] .. ',' .. d[6] end end end)()")
    check('locked: full and orange (%s)' % meter, meter == '260,240')
    rt.execute('OBJ[24] = nil GRIP = 10 run(1.5)')

    # a guard dog's weapon: fires on its own (trigger never held): never the weapon in hand, its ammo in the backpack bar
    rt.execute('''OBJ[25] = { name = NAMES.dog, fields = {} } OBJ[25].fields[ROLE.rounds] = 80 OBJ[25].fields[ROLE.magazines] = 2
      OBJ[25].fields[ROLE.chamber] = true OBJ[25].fields[ROLE.carry] = 0 OBJ[25].fields[ROLE.held] = false GRIP = 10 run(3)
      FIRE = false for i = 1, 6 do OBJ[25].fields[ROLE.rounds] = 80 - i * 5 run(0.6) end FIRE = true''')
    logs = list(rt.eval('logs').values())
    check('the dog weapon: fires without your fire button, not yours', any('type 530e19df fires without your fire button' in l for l in logs))
    check('never learned as a hand weapon', rt.eval('saved.poses["530e19df"]') is None and rt.eval('saved.grip["530e19df"]') is None)
    rt.execute('OBJ[25] = nil GRIP = 10 run(1.5)')

    # an Arc Thrower (no ammo of its own): learned when its trigger is held at a pose nothing has, a 1 s charge meter
    rt.execute('''OBJ[26] = { name = NAMES.arc, fields = {} } OBJ[26].fields[ROLE.carry] = 0 OBJ[26].fields[ROLE.held] = false
      OBJ[26].fields[ROLE.fire_mode] = 1 GRIP = 33 run(3) OBJ[26].fields[ROLE.held] = true run(0.5)''')
    logs = list(rt.eval('logs').values())
    check('no-ammo weapon learned on its trigger', any('(no ammo of its own) goes with hand pose 33' in l for l in logs))
    meter = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[9] == 230 then return d[4] end end end)()")
    check('a charge meter about half way after 0.5 of 1 s (%s)' % meter, meter and 75 <= meter <= 160)  # (not yet shown: read every other read, so its trigger seen up to a read late)
    rt.execute('OBJ[26] = nil GRIP = 10 run(1.5)')

    # the Commando's laser guidance
    rt.execute('''OBJ[27] = { name = NAMES.commando, fields = {} } OBJ[27].fields[ROLE.rounds] = 4 OBJ[27].fields[ROLE.magazines] = 0
      OBJ[27].fields[ROLE.chamber] = true OBJ[27].fields[ROLE.carry] = 0 OBJ[27].fields[ROLE.guide] = true GRIP = 20 run(3)
      OBJ[27].fields[ROLE.rounds] = 3 run(0.5)''')
    check('Commando: LASER [%s]' % rt.eval('texts()'), 'LASER' in rt.eval('texts()') and 'NO LASER' not in rt.eval('texts()'))
    rt.execute('OBJ[27].fields[ROLE.guide] = false run(0.3)')
    check('Commando: NO LASER [%s]' % rt.eval('texts()'), 'NO LASER' in rt.eval('texts()'))
    rt.execute('OBJ[27] = nil GRIP = 10 run(1.5)')

    rt.execute('OBJ[28] = nil run(1.5)')

    # the warp pack: its heat in the backpack bar, orange past 15
    rt.execute('''OBJ[29] = { name = "c_abhh", fields = { heat = 33 } } OBJ[29].fields[ROLE.carry] = 0 GRIP = 10 run(4)''')
    w = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 215 then return d[4] .. ',' .. d[6] end end end)()")
    check('warp pack heat 33: a third of the bar, orange (%s)' % w, w and w.endswith(',240'))
    rt.execute('OBJ[29] = nil run(1.5)')

    # as host you own the SEAF troops' rifles too: one firing while you don't press fire is never yours
    rt.execute('''OBJ[30] = { name = NAMES.seaf, fields = {} } OBJ[30].fields[ROLE.rounds] = 30 OBJ[30].fields[ROLE.magazines] = 5
      OBJ[30].fields[ROLE.chamber] = true OBJ[30].fields[ROLE.carry] = 0
      GRIP = 10 run(3) FIRE = false run(0.5) for i = 1, 4 do OBJ[30].fields[ROLE.rounds] = 30 - i run(0.6) end FIRE = true''')
    logs = list(rt.eval('logs').values())
    check('a SEAF rifle firing without your fire button: not yours, never learned',
          not any('learned: type aca39ec2 goes' in l for l in logs) and any('type aca39ec2 fires without your fire button' in l for l in logs))
    check('the Arbitrator still shown [%s] %s' % (rt.eval('texts()'), [l for l in rt.eval('logs').values()][-8:]), rt.eval('texts()').startswith('31 |'))
    rt.execute('OBJ[30] = nil run(1.5)')

    # the jump pack: 15 s recharge from the jump
    rt.execute('''OBJ[31] = { name = "ddb66ra", fields = { c4zfiq = false } } OBJ[31].fields[ROLE.carry] = 0 run(3)
      OBJ[31].fields.c4zfiq = true run(0.5) OBJ[31].fields.c4zfiq = false run(7)''')
    w = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 180 then return d[4] end end end)()")
    bg = rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 45 then return d[4] end end end)()")
    check('jump pack 7.5 s after a jump: about half recharged (%s of %s)' % (w, bg), w and bg and 0.4 < w / bg < 0.6)
    rt.execute('OBJ[31] = nil run(1.5)')

    # someone else's game: your weapon owned by the host, its owner field says you; the host's own isn't yours
    rt.execute('''HOST = '1111111111111111' OBJ[33] = { name = NAMES.verdict, fields = {} } OBJ[33].fields[ROLE.rounds] = 10
      OBJ[33].fields[ROLE.magazines] = 6 OBJ[33].fields[ROLE.chamber] = true OBJ[33].fields[ROLE.carry] = 0
      OBJ[33].fields[ROLE.owner] = '0b99cf5492296d6e'
      OBJ[34] = { name = NAMES.verdict, fields = {} } OBJ[34].fields[ROLE.rounds] = 3 OBJ[34].fields[ROLE.magazines] = 1
      OBJ[34].fields[ROLE.chamber] = true OBJ[34].fields[ROLE.carry] = 0 OBJ[34].fields[ROLE.owner] = '1111111111111111'
      HOSTS[33] = true HOSTS[34] = true GRIP = 36 run(3) OBJ[33].fields[ROLE.rounds] = 9 run(0.5)''')
    t = rt.eval('texts()')
    check('in someone else\'s game: your Verdict (owned by the host) shown, theirs not [%s]' % t, t.startswith('9 | x6'))
    check('a session line logged once a mission %s' % [l for l in rt.eval('logs').values() if l.startswith('session')],
          any(l.startswith('session: you 0b99cf5492296d6e, host 0b99cf5492296d6e') for l in rt.eval('logs').values()))
    rt.execute("OBJ[33] = nil OBJ[34] = nil HOSTS = {} HOST = '0b99cf5492296d6e' GRIP = 10 run(1.5)")

    # a new mission: object ids start over; an id that was nothing of ours last mission is our weapon now
    rt.execute('''OBJ[60] = { name = 'nothing60', fields = {} } run(3)
      WORLD = 2 OBJ[60] = { name = NAMES.verdict, fields = {} } OBJ[60].fields[ROLE.rounds] = 10 OBJ[60].fields[ROLE.magazines] = 6
      OBJ[60].fields[ROLE.chamber] = true OBJ[60].fields[ROLE.carry] = 0 GRIP = 36 run(3) OBJ[60].fields[ROLE.rounds] = 9 run(1)''')
    t = rt.eval('texts()')
    check('new mission, a reused id: our Verdict found and shown [%s]' % t, t.startswith('9 | x6'))
    rt.execute('OBJ[60] = nil GRIP = 10 run(3)')

    # a shield: two one-handed weapons share its pose (30); the swap keys and the wheel say which is out
    rt.execute('''OBJ[3].fields[ROLE.carry] = 1
      OBJ[61] = { name = NAMES.verdict, fields = {} } OBJ[61].fields[ROLE.rounds] = 10 OBJ[61].fields[ROLE.magazines] = 6
      OBJ[61].fields[ROLE.chamber] = true OBJ[61].fields[ROLE.carry] = 0
      OBJ[62] = { name = NAMES.unk2, fields = {} } OBJ[62].fields[ROLE.rounds] = 20 OBJ[62].fields[ROLE.magazines] = 2
      OBJ[62].fields[ROLE.chamber] = true OBJ[62].fields[ROLE.carry] = 0
      GRIP = 30 run(3) OBJ[61].fields[ROLE.rounds] = 9 run(1.2) OBJ[62].fields[ROLE.rounds] = 19 run(0.5)''')
    check('shield: the last fired shown [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('19 | x2'))
    rt.execute("press('1')")
    check('shield, key 1 (not learned): the other one out [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('9 | x6'))
    rt.execute("PADY = true run(1 / 60) PADY = false run(0.6)")
    check('shield, a controller\'s Y: the other one [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('19 | x2'))
    rt.execute("press('wheel')")
    check('shield, the wheel: the other one again [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('9 | x6'))
    # the wheel with the weapon options key held (R): the scope's zoom or the light, no swap (the AMR, a player's report)
    rt.execute("BINDS.weapon_menu = true press('wheel') BINDS.weapon_menu = false run(0.3)")
    check('the wheel with R held: no swap [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('9 | x6'))
    # the wheel set to not swap (bound to something else in the game): nothing changes; up only: down does nothing
    rt.execute("CHANGE.swap_wheel(4) press('wheel')")
    check('the wheel off: no swap [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('9 | x6'))
    rt.execute("CHANGE.swap_wheel(2) WHEEL = -1 run(1 / 60) WHEEL = 0 run(0.3)")
    check('the wheel up only, scrolled down: no swap [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('9 | x6'))
    rt.execute("CHANGE.swap_wheel(1) press('wheel')")
    check('the wheel both ways again: swaps [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('19 | x2'))
    rt.execute("press('wheel')")
    # without the shield their poses differ: the keys are learned there
    rt.execute('''GRIP = 71 run(0.5) OBJ[62].fields[ROLE.rounds] = 18 run(0.5) GRIP = 1 run(0.5) OBJ[61].fields[ROLE.rounds] = 8 run(0.5)
      press('2') GRIP = 71 run(1.5) press('1') GRIP = 1 run(0.5)''')
    check('swap keys learned %s' % [l for l in rt.eval('logs').values() if 'swap key' in l],
          rt.eval('saved.slot and saved.slot["c7dfd9eb"]') == 1
          and sum(1 for l in rt.eval('logs').values() if 'swap key 2' in l) == 1)
    rt.execute("GRIP = 30 run(0.5) press('2')")
    check('shield, key 2 (learned): its weapon [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('18 | x2'))
    rt.execute("press('2')")
    check('shield, key 2 again: stays [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('18 | x2'))
    rt.execute("press('1')")
    check('shield, key 1 (learned): the Verdict [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('8 | x6'))
    # two of your weapons on one pose, one fired much more (proven yours): the keys still swap between them; a wrong
    # key learned (key 3 for the Verdict) is corrected by the other one firing just after
    rt.execute('''for i = 1, 4 do OBJ[61].fields[ROLE.rounds] = 8 - i run(0.3) end
      saved.slot["c7dfd9eb"] = 3 press('3')''')
    check('shield, a wrong key learned: key 3 takes the Verdict [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('4 | x6'))
    rt.execute("press('2')")
    check('shield, the Verdict fired most: key 2 still swaps [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('18 | x2'))
    rt.execute("press('3') OBJ[62].fields[ROLE.rounds] = 17 run(0.5)")
    check('a shot from the other one after key 3: key 3 is its [%s]' % [l for l in rt.eval('logs').values() if 'fired after the key' in l],
          rt.eval('saved.slot["c7dfd9eb"]') is None and any('fired after the key' in l for l in rt.eval('logs').values()))
    rt.execute('OBJ[61] = nil OBJ[62] = nil OBJ[3].fields[ROLE.carry] = 0 GRIP = 10 run(3)')

    # a grenade in hand: only the grenade line
    rt.execute('GRIP = 41 run(1)')
    check('grenade in hand: only icons [%s]' % rt.eval('texts()'), rt.eval('texts()') == '5 | 4')

    rt.execute('GRIP = 0 run(0.5)')
    check('nothing in hand: only icons', rt.eval('count("rect")') == 0)

    # a carried weapon taken off your body (dropped): not shown any more
    rt.execute('GRIP = 10 OBJ[3].fields[ROLE.carry] = 1 run(2)')
    check('dropped Arbitrator: not shown', '31' not in rt.eval('texts()'))
    rt.execute('OBJ[3].fields[ROLE.carry] = 0 run(2)')

    # the game font missing: the pixel font
    rt2 = lua51.LuaRuntime()
    setup(rt2, game_font=False)
    rt2.execute('run(3)')
    check('no game font: pixel font [%s]' % rt2.eval('texts()'),
          rt2.eval('count("text", false)') > 0 and rt2.eval('count("text", true)') == 0 and '45' in rt2.eval('texts()'))
    check('logged the fallback', any('game font off' in l for l in rt2.eval('logs').values()))

    # below native render scale on Chef 1.0.x: the pixel font
    rt4 = lua51.LuaRuntime()
    setup(rt4)
    rt4.execute('RENDER_W, RENDER_H = 2656, 1112 run(3)')
    check('render scale 0.77: the game font for now (to judge it) [%s]' % rt4.eval('texts()'),
          rt4.eval('GUIS') == 1 and rt4.eval('count("text", true)') > 0)

    # planet: the Scythe cooling at 12.75/s (x1.5 of the wiki's 8.5) is a cold planet; the model then cools that fast
    rt5 = lua51.LuaRuntime()
    setup(rt5)
    rt5.execute('''OBJ[20] = { name = NAMES.scythe, fields = {} } OBJ[20].fields[ROLE.heat] = 90 OBJ[20].fields[ROLE.overheated] = false
      OBJ[20].fields[ROLE.charging] = false OBJ[20].fields[ROLE.held] = false OBJ[20].fields[ROLE.carry] = 0
      OBJ[20].fields[ROLE.magazines] = 3 GRIP = 10 run(2)
      for i = 1, 5 do OBJ[20].fields[ROLE.heat] = 90 - i * 12.75 run(1) end''')
    check('cold planet measured: x1.5 %s' % [l for l in rt5.eval('logs').values() if 'planet' in l],
          any('planet cooling x1.50 (cold)' in l for l in rt5.eval('logs').values()))

    # the Scythe's heat sinks move where it overheats (60, 100, 150; a player's report): taken from each overheat, per
    # weapon, and kept for the type
    r = lua51.LuaRuntime()
    setup(r, seeded=True)
    r.execute('''OBJ[3] = nil OBJ[20] = { name = NAMES.scythe, fields = {} } local f = OBJ[20].fields f[ROLE.heat] = 0
      f[ROLE.overheated] = false f[ROLE.charging] = false f[ROLE.held] = false f[ROLE.carry] = 0 GRIP = 10 run(3)
      f[ROLE.heat] = 60 f[ROLE.overheated] = true run(1)''')
    r.execute('''local f = OBJ[20].fields f[ROLE.overheated] = false f[ROLE.heat] = 30 run(0.3)''')
    r.execute('''local f = OBJ[20].fields f[ROLE.heat] = 0 run(8) f[ROLE.heat] = 150 f[ROLE.overheated] = true run(0.3)
      f[ROLE.overheated] = false f[ROLE.heat] = 75 run(0.3)''')
    r.execute('run(6)')
    s150 = r.eval('saved and saved.heat and saved.heat["42a6b5ba"]')
    logs = [l for l in r.eval('logs').values() if 'overheats at' in l]
    check('Scythe overheating at 60, then at 150: each taken, the last kept (%s) %s' % (s150, logs),
          len(logs) == 2 and 'at 60 (was 100' in logs[0] and 'at 150 (was 60' in logs[1] and s150 == 150)
    # a heat weapon with a backpack on (a supply pack): no magazines shown (the Nova showed the pack's 7 as x7)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil OBJ[50] = { name = NAMES.pack2, fields = {} } OBJ[50].fields[ROLE.remaining] = 7
      OBJ[50].fields[ROLE.carry] = 0 GRIP = 52 run(3)''')
    t = r.eval('texts()')
    check('the Nova with a supply pack on: no x7 [%s]' % t, 'HEAT' in t and 'x7' not in t)
    # a weapon reloading from its own magazines as a backpack goes down (a supply pack used): never a backpack weapon,
    # and one learned so wrongly before is unlearned (the Railgun showed a supply pack's 6-8)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''saved = { packres = { ["8fcdd35c"] = true } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[50] = { name = NAMES.pack2, fields = {} } OBJ[50].fields[ROLE.remaining] = 8 OBJ[50].fields[ROLE.carry] = 0
      run(3) OBJ[3].fields[ROLE.rounds] = 40 run(0.5)
      OBJ[3].fields[ROLE.rounds] = 44 OBJ[3].fields[ROLE.magazines] = 6 OBJ[50].fields[ROLE.remaining] = 7 run(0.5)
      OBJ[3].fields[ROLE.rounds] = 40 run(0.5)
      OBJ[3].fields[ROLE.rounds] = 44 OBJ[3].fields[ROLE.magazines] = 5 OBJ[50].fields[ROLE.remaining] = 6 run(2)''')
    logs = list(r.eval('logs').values())
    t = r.eval('texts()')
    check('reloading from its own magazines as a pack goes down: unlearned, not learned again, x5 [%s]' % t,
          any('8fcdd35c reloads from its own magazines' in l for l in logs)
          and not any('8fcdd35c reloads from the backpack' in l for l in logs) and 'x5' in t)
    # the shipped seed: a weapon it knows (the Verdict, at pose 36) shows before its first shot
    rt6 = lua51.LuaRuntime()
    setup(rt6, seeded=True)
    rt6.execute('''OBJ[3] = nil OBJ[40] = { name = NAMES.verdict, fields = {} } OBJ[40].fields[ROLE.rounds] = 10
      OBJ[40].fields[ROLE.magazines] = 6 OBJ[40].fields[ROLE.chamber] = true OBJ[40].fields[ROLE.carry] = 0 GRIP = 36 run(3)''')
    check('seeded: the Verdict shown before its first shot [%s]' % rt6.eval('texts()'), rt6.eval('texts()').startswith('10 | x6'))
    # Extreme Cold: the rate field reads 0.9 of the setting; the setting is shown
    rt6.execute('''OBJ[41] = { name = NAMES.stalwart, fields = {} } OBJ[41].fields[ROLE.rounds] = 200 OBJ[41].fields[ROLE.magazines] = 3
      OBJ[41].fields[ROLE.chamber] = true OBJ[41].fields[ROLE.carry] = 0 OBJ[41].fields[ROLE.fire_mode] = 1
      OBJ[41].fields[ROLE.rpm] = 630 GRIP = 10 OBJ[40] = nil run(3) OBJ[41].fields[ROLE.rounds] = 199 run(0.5)''')
    t = rt6.eval('texts()')
    check('cold: the Stalwart\'s field 630 shown as its 700 setting [%s]' % t, '700 RPM' in t)
    rt6.execute('OBJ[41].fields[ROLE.rpm] = 850 run(0.3)')
    check('warm again: 850 as it is [%s]' % rt6.eval('texts()'), '850 RPM' in rt6.eval('texts()'))

    # a controller: its right trigger is the fire button (the mouse untouched)
    rt7 = lua51.LuaRuntime()
    setup(rt7)
    rt7.execute('PAD = true GRIP = 70 run(3) OBJ[4].fields[ROLE.rounds] = 11 run(0.5) OBJ[4].fields[ROLE.rounds] = 10 run(0.5) OBJ[4].fields[ROLE.rounds] = 9 run(0.5) OBJ[4].fields[ROLE.rounds] = 8 run(0.5)')
    t = rt7.eval('texts()')
    check('controller: a weapon fired with the right trigger learned and shown [%s]' % t, t.startswith('8 |'))
    check('controller: not taken for someone else\'s', not any('not yours' in l for l in rt7.eval('logs').values()))
    # a type with no owner field (an object a host owns, from a player's log): never learned to the hand pose
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil OBJ[70] = { name = '%s', fields = {} } OBJ[70].fields[ROLE.rounds] = 30 OBJ[70].fields[ROLE.magazines] = 3
      OBJ[70].fields[ROLE.chamber] = true GRIP = 10 run(3) for i = 1, 4 do OBJ[70].fields[ROLE.rounds] = 30 - i run(0.5) end''' % type_name('e45066e4'))
    check('no owner field: not learned [%s]' % r.eval('texts()'), not any('learned: type e45066e4' in l for l in r.eval('logs').values()) and '26' not in r.eval('texts()'))
    # as host: a SEAF soldier's gun of the same kind as yours fires as you fire: yours stays shown; one that keeps
    # firing with your fire button while yours does nothing (a swap NarrowHUD didn't see) takes over
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''run(3) OBJ[80] = { name = OBJ[3].name, fields = {} } OBJ[80].fields[ROLE.rounds] = 30 OBJ[80].fields[ROLE.magazines] = 3
      OBJ[80].fields[ROLE.chamber] = true OBJ[80].fields[ROLE.carry] = 0 run(1)
      for i = 1, 5 do OBJ[3].fields[ROLE.rounds] = 44 - i run(0.1) OBJ[80].fields[ROLE.rounds] = 30 - i run(0.2) end''')
    t = r.eval('texts()')
    logs = list(r.eval('logs').values())
    check('SEAF gun firing with yours: yours kept [%s]' % t, t.startswith('40 |'))
    check('SEAF gun firing with yours: logged (research)', any('kept the weapon in hand' in l for l in logs))
    r.execute('for i = 1, 3 do OBJ[80].fields[ROLE.rounds] = 25 - i run(0.3) end')
    t = r.eval('texts()')
    check('the other one firing, yours not: it takes over [%s]' % t, t.startswith('23 |') or t.startswith('22 |'))
    check('research: the switch logged with both objects', any('switched from' in l and 'object 80' in l for l in r.eval('logs').values()))
    # as host: a SEAF rifle (its own type) firing at the same moment as your weapon in hand: never learned for the pose
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''run(3) OBJ[81] = { name = NAMES.seaf, fields = {} } OBJ[81].fields[ROLE.rounds] = 30 OBJ[81].fields[ROLE.magazines] = 5
      OBJ[81].fields[ROLE.chamber] = true OBJ[81].fields[ROLE.carry] = 0 run(1)
      for i = 1, 5 do OBJ[3].fields[ROLE.rounds] = 44 - i OBJ[81].fields[ROLE.rounds] = 30 - i run(0.2) end''')
    logs = list(r.eval('logs').values())
    check('SEAF rifle firing with yours: not learned, and logged (research)', not any('learned: type aca39ec2' in l for l in logs)
          and any('not learned from aca39ec2' in l for l in logs) and r.eval('texts()').startswith('40 |'))
    # the fire button seen once: the weapon shown firing on its own later is someone else's, never "a controller
    # NarrowHUD can't read" (a SEAF gun shown by mistake set that off in a 1.0.2 log)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''run(3) FIRE = false run(25) for i = 1, 3 do OBJ[3].fields[ROLE.rounds] = 44 - i run(0.6) end''')
    check('fire button seen once: never blind', not any("shots aren't checked from now on" in l for l in r.eval('logs').values()))
    # a type learned for 4 hand poses (a SEAF gun, from an older version's learned file): never shown
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil saved = { poses = { aca39ec2 = '70,52,1,10' } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[82] = { name = NAMES.seaf, fields = {} } OBJ[82].fields[ROLE.rounds] = 30 OBJ[82].fields[ROLE.magazines] = 5
      OBJ[82].fields[ROLE.chamber] = true OBJ[82].fields[ROLE.carry] = 0 GRIP = 10 run(3)
      for i = 1, 4 do OBJ[82].fields[ROLE.rounds] = 30 - i run(0.3) end''')
    logs = list(r.eval('logs').values())
    check('4 poses learned (not shipped): never shown, said once [%s]' % r.eval('texts()'), not r.eval('texts()').startswith('2')
          and sum(1 for l in logs if 'learned for 4 hand poses' in l) == 1 and not any('learned: type aca39ec2' in l for l in logs))
    # a SEAF gun holding its trigger while you don't fire (a 2026-10-26 log: held=true with no input): not yours, and
    # the hand pose it taught taken back
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''run(3) OBJ[83] = { name = NAMES.seaf, fields = {} } local f = OBJ[83].fields f[ROLE.rounds] = 30
      f[ROLE.magazines] = 5 f[ROLE.chamber] = true f[ROLE.carry] = 0 f[ROLE.held] = true GRIP = 20 run(3)
      for i = 1, 2 do f[ROLE.rounds] = 30 - i run(0.3) end''')
    taught = any('learned: type aca39ec2 goes with hand pose 20' in l for l in r.eval('logs').values())
    r.execute('FIRE = false run(1.5)')
    logs = list(r.eval('logs').values())
    check('SEAF gun holding its trigger alone: not yours, its pose taken back (taught first: %s)' % taught,
          taught and any('aca39ec2 holds its trigger without your fire button: not yours' in l for l in logs)
          and any('aca39ec2: hand pose 20 forgotten' in l for l in logs) and r.eval('saved.poses.aca39ec2') is None)
    r.execute('FIRE = true GRIP = 20 run(2.5) OBJ[83].fields[ROLE.rounds] = 20 run(0.5)')
    check('then never shown [%s]' % r.eval('texts()'), not r.eval('texts()').startswith('20'))
    # one firing with yours a lot and without it now and then (10 with, 6 without took the HUD in that log): not yours
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''run(3) OBJ[84] = { name = NAMES.seaf, fields = {} } local f = OBJ[84].fields f[ROLE.rounds] = 30
      f[ROLE.magazines] = 5 f[ROLE.chamber] = true f[ROLE.carry] = 0 f[ROLE.held] = false run(1)
      for i = 1, 8 do f[ROLE.rounds] = 30 - i run(0.3) end FIRE = false run(0.6)
      for i = 1, 3 do f[ROLE.rounds] = 22 - i run(0.6) end''')
    check('8 shots with your fire button, 3 without: not yours',
          any('aca39ec2 fires without your fire button: not yours' in l for l in r.eval('logs').values()))
    # a charge weapon shown charging (the Quasar, here the Nova): a gun firing then on its pose isn't learned for it
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil GRIP = 52 run(3) OBJ[85] = { name = NAMES.seaf, fields = {} } local f = OBJ[85].fields
      f[ROLE.rounds] = 30 f[ROLE.magazines] = 5 f[ROLE.chamber] = true f[ROLE.carry] = 0 f[ROLE.held] = true run(1)
      OBJ[5].fields[ROLE.charging] = true run(0.2) for i = 1, 3 do f[ROLE.rounds] = 30 - i run(0.3) end''')
    logs = list(r.eval('logs').values())
    check('Nova charging: a gun firing on its pose not learned', not any('learned: type aca39ec2' in l for l in logs)
          and any('not learned from aca39ec2' in l for l in logs))
    # the Nova cooling from its shot (can't fire): a SEAF gun firing then, as you hold fire, isn't learned for its pose
    # (as host, a 2026-10-26 log)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil GRIP = 52 run(3) OBJ[85] = { name = NAMES.seaf, fields = {} } local f = OBJ[85].fields
      f[ROLE.rounds] = 30 f[ROLE.magazines] = 5 f[ROLE.chamber] = true f[ROLE.carry] = 0 f[ROLE.held] = true run(1)
      OBJ[5].fields[ROLE.charging] = false OBJ[5].fields[ROLE.held] = false OBJ[5].fields[ROLE.heat] = 80 run(1)
      for i = 1, 4 do f[ROLE.rounds] = 30 - i run(0.3) end''')
    logs = list(r.eval('logs').values())
    check('Nova cooling: a gun firing on its pose not learned', not any('learned: type aca39ec2' in l for l in logs)
          and any('not learned from aca39ec2' in l for l in logs))
    # the Scythe overheated: the same (it overheated, a SEAF gun fired as you held fire, and took the HUD a moment later)
    r = lua51.LuaRuntime()
    setup(r, seeded=True)
    r.execute('''OBJ[3] = nil OBJ[20] = { name = NAMES.scythe, fields = {} } local g = OBJ[20].fields g[ROLE.heat] = 100
      g[ROLE.overheated] = true g[ROLE.charging] = false g[ROLE.held] = false g[ROLE.carry] = 0 GRIP = 10 run(3)
      OBJ[86] = { name = NAMES.seaf, fields = {} } local f = OBJ[86].fields
      f[ROLE.rounds] = 30 f[ROLE.magazines] = 5 f[ROLE.chamber] = true f[ROLE.carry] = 0 f[ROLE.held] = false run(1)
      for i = 1, 4 do f[ROLE.rounds] = 30 - i g[ROLE.heat] = 100 - i * 3 run(0.3) end''')
    logs = list(r.eval('logs').values())
    check('Scythe overheated: a gun firing on its pose not learned', not any('learned: type aca39ec2' in l for l in logs)
          and any('not learned from aca39ec2' in l for l in logs))
    # the Scythe's heat reading 0 as it overheats (that log: "overheats at 0", the bar wrong from then on): not a point;
    # one under 30 already learned is dropped at load
    r = lua51.LuaRuntime()
    setup(r, seeded=True)
    r.execute('''OBJ[3] = nil saved = { heat = { ["42a6b5ba"] = 0 } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[20] = { name = NAMES.scythe, fields = {} } local f = OBJ[20].fields f[ROLE.heat] = 0
      f[ROLE.overheated] = false f[ROLE.charging] = false f[ROLE.held] = false f[ROLE.carry] = 0 GRIP = 10 run(3)
      f[ROLE.heat] = 50 run(0.2) h50 = texts()
      f[ROLE.heat] = 0 run(2) f[ROLE.overheated] = true run(1) f[ROLE.overheated] = false run(0.5) f[ROLE.heat] = 50 run(6)''')
    logs = [l for l in r.eval('logs').values() if 'overheats at' in l]
    sv = r.eval('saved and saved.heat and saved.heat["42a6b5ba"]')
    check('Scythe heat 0 as it overheats: no point taken (%s, saved %s); a learned 0 dropped: 50 of 100 [%s]' % (logs, sv, r.eval('h50')),
          not logs and r.eval('h50').startswith('50%') and (sv is None or sv >= 30))
    # research: every field of your own objects (game_object_field_batched): each type's field list once, each object's
    # values once, then the changes; a field changing at almost every read (here the time) left out, said once
    r = lua51.LuaRuntime()
    r.execute('''BATCHED = {} stingray = { GameSession = { game_object_field_batched = function(s, id, l)
        BATCHED[#BATCHED + 1] = id
        local o = OBJ[id] if not o then return nil end
        if o.name == NAMES.avatar then
          -- (the Helldiver: 70 fields, the first 63 as a list in place 64, as the game gives them)
          local inner = {} for i = 1, 63 do inner[i] = i end inner[5] = HP or 125
          local v = { [64] = inner } for i = 65, 70 do v[i] = i * 10 end return v
        end
        return { o.fields[ROLE.rounds] or 0, T, { 1, 2, x = 3 } } end } }''')
    setup(r)
    r.execute('''OBJINFO = function(name)
        if name == NAMES.avatar then local f = {} for i = 1, 70 do f[i] = { id = string.format('%08x', i) } end f[5] = { id = 'cb0453ea' } return { fields = f } end
        return { fields = { { id = string.gsub(DATA_ROLES.rounds, '^0+', ''), type = 1, min = 0,
        max = 255, bits = 8, tolerance = 0 }, { id = 'abc', type = 2 }, { id = 'def', type = 0 } } } end
      run(16) OBJ[3].fields[ROLE.rounds] = 40 HP = 90 run(1)''')
    logs = [l for l in r.eval('logs').values() if 'all fields' in l]
    check('all fields: the Helldiver\'s packed list unpacked, a named field\'s change %s' % [l for l in logs if 'Helldiver' in l][:4],
          any('your Helldiver' in l and '#1 1=1, #2 2=2' in l for l in logs)
          and any('#5 cb0453ea=health=125' in l for l in logs) and any('#65 41=650' in l for l in logs)
          and any('#5 cb0453ea=health 125>90' in l for l in logs) and any('come as a list in place 64' in l for l in logs))
    ids = set(r.eval('BATCHED').values())
    check('all fields: the type\'s list, the values, a change, the time left out (%d lines) %s' % (len(logs), logs[:3]),
          any('type 8fcdd35c: #1 ' in l and 'rounds_remaining (kind 1 0..255 8b)' in l for l in logs)
          and any('weapon in hand 8fcdd35c (object 3): #1 ' in l and 'rounds_remaining=44' in l and '#3 def={1 2 x=3}' in l for l in logs)
          and any('#2 abc changes all the time, left out' in l for l in logs)
          and any('rounds_remaining 44>40' in l for l in logs) and ids <= set(r.eval('(function() local l = {} for k in pairs(OBJ) do l[#l + 1] = k end return l end)()').values()))
    # health and stamina (1.1.0): Under draws them over the bar; health always, stamina while not full; a hit's
    # trail in red; nothing while dead; Custom from its default layout at the same place; no weapon needed
    r = lua51.LuaRuntime()
    r.execute('OPTS_X = true')
    setup(r)
    r.execute('''function rects_at(y) local l = {} for _, d in ipairs(draws) do if d[1] == 'rect' and d[3] == y then l[#l + 1] = d end end return l end
      function fill_at(y, cr) for _, d in ipairs(draws) do if d[1] == 'rect' and d[3] == y and d[6] == cr[1] and d[7] == cr[2] and d[8] == cr[3] then return d[4] end end return nil end
      OPTS.health, OPTS.stamina = 2, 3 M = (function(...) ''' + SRC + ''' end)(chef)
      local f = OBJ[2].fields f.health, f.max_health, f.stamina = 125, 125, 1 run(2)''')
    hw = r.eval('fill_at(614, {236, 229, 206})')
    st0 = len(r.eval('rects_at(622)'))
    r.execute('OBJ[2].fields.stamina = 0.5 run(0.5)')
    sw = r.eval('fill_at(622, {130, 190, 235})')
    r.execute('OBJ[2].fields.health = 50 run(0.2)')
    hw2, trail = r.eval('fill_at(614, {240, 170, 90})'), r.eval('fill_at(614, {225, 75, 60})')
    r.execute('run(2)')
    trail2 = r.eval('fill_at(614, {225, 75, 60})')
    r.execute('GRIP = 0 run(0.5)')
    nw = r.eval('fill_at(614, {240, 170, 90})')
    r.execute('OBJ[2].fields.health = 0 run(0.5)')
    dead = len(r.eval('rects_at(614)'))
    check('health and stamina under the bar: full health %s, no stamina while full (%d rects), half stamina %s, 50 of 125 orange %s with a trail %s, gone %s, with no weapon %s, dead nothing (%d)'
          % (hw, st0, sw, hw2, trail, trail2, nw, dead),
          hw == 260 and st0 == 0 and sw == 130 and hw2 == 104 and trail and trail > 100 and trail2 is None and nw == 104 and dead == 0)
    r.execute('''OBJ[2].fields.health = 125 OPTS.position = 4 LAYOUT = nil M = (function(...) ''' + SRC + ''' end)(chef) run(2)''')
    check('Custom: health from the default layout at the same place (%s)' % r.eval('fill_at(614, {236, 229, 206})'), r.eval('fill_at(614, {236, 229, 206})') == 260)
    r.execute('''OPTS.position = 1 OPTS.health = 3 M = (function(...) ''' + SRC + ''' end)(chef) run(4)''')
    check('health "when hurt": hidden at full health', r.eval('fill_at(614, {236, 229, 206})') is None)
    # 1.2.0: hidden while calling in a stratagem (95c46304 non-zero) and while emoting (active_emote set), back after
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('run(3)')
    t0 = r.eval('texts()')
    r.execute('OBJ[2].fields.ww3bwxa = 3 run(0.3) OBJ[2].fields.ww3bwxa = 4 run(0.3)')
    t_aim = r.eval('texts()')
    r.execute('OBJ[2].fields.ww3bwxa = 0 BINDS.strat_key = true run(0.5)')
    t1 = r.eval('texts()')
    r.execute('BINDS.strat_key = false run(0.2)')
    t2 = r.eval('texts()')
    r.execute('OBJ[2].fields.active_emote = 198334139 run(0.5)')
    t3 = r.eval('texts()')
    r.execute('OBJ[2].fields.active_emote = 0 run(0.2)')
    t4 = r.eval('texts()')
    r.execute('OPTS.hide_strat = false M = (function(...) ' + SRC + ''' end)(chef) run(3) BINDS.strat_key = true run(0.5) BINDS.strat_key = false''')
    t5 = r.eval('texts()')
    check('hidden while the stratagem key is held and for an emote, not while aiming (3, 4) [%s / aiming %s / %s / %s / %s / %s; F9 off: %s]' % (t0, t_aim, t1, t2, t3, t4, t5),
          t0.startswith('45') and t_aim.startswith('45') and t1 == '' and t2.startswith('45') and t3 == '' and t4.startswith('45') and t5.startswith('45'))
    # the stim timer: a stim used (the count down) shows a green line shrinking over 4 s; 6 s with an armour that has
    # the Med-Kit passive (the CM-09 Bonesnapper, 1c6c05fa, from HD2Runtime's armour catalog)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''function fill_at(y, cr) for _, d in ipairs(draws) do if d[1] == 'rect' and d[3] == y and d[6] == cr[1] and d[7] == cr[2] and d[8] == cr[3] then return d[4] end end return nil end
      OPTS.stim_timer = true OPTS.health = 1 OPTS.stamina = 1 M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[1].fields.armor_set = 1594318277 local f = OBJ[2].fields f.health, f.max_health, f.stamina = 125, 125, 1 run(3)
      f.ei6_t2 = 4 run(2)''')
    w2 = r.eval('fill_at(614, {120, 215, 140})')
    r.execute('run(2.5)')
    w4 = r.eval('fill_at(614, {120, 215, 140})')
    r.execute('OBJ[1].fields.armor_set = 476841466 run(2) OBJ[2].fields.ei6_t2 = 3 run(5)')
    w5 = r.eval('fill_at(614, {120, 215, 140})')
    r.execute('run(1.5)')
    w6 = r.eval('fill_at(614, {120, 215, 140})')
    check('stim timer: half way at 2 s (%s), gone after 4 s (%s); with the Bonesnapper still on at 5 s (%s), gone after 6 (%s)' % (w2, w4, w5, w6),
          w2 and 120 <= w2 <= 145 and w4 is None and w5 and w5 < 60 and w6 is None)
    # 1.2.0: warnings: the health bar pulses under a quarter
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OPTS.warn, OPTS.health = true, 2 M = (function(...) ''' + SRC + ''' end)(chef)
      local f = OBJ[2].fields f.health, f.max_health, f.stamina = 20, 125, 1 run(3) al = {}
      for i = 1, 8 do run(1 / 16) for _, d in ipairs(draws) do if d[1] == 'rect' and d[3] == 614 and d[6] == 225 then al[#al + 1] = d[9] end end end''')
    al = list(r.eval('al').values())
    check('low health: the bar pulses %s' % al, len(al) >= 6 and max(al) - min(al) > 60)
    # 1.2.0: reload progress: the first reload is timed (2 s), the second shows a line over the bar filling over it
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OPTS.reload_line = true M = (function(...) ''' + SRC + ''' end)(chef) run(3)
      local f = OBJ[3].fields f[ROLE.rounds] = 30 run(0.3) f[ROLE.reload_stage] = 1 run(2) f[ROLE.rounds] = 45 f[ROLE.reload_stage] = 0 run(1)
      f[ROLE.rounds] = 30 run(0.3) f[ROLE.reload_stage] = 1 run(1)''')
    rl = r.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[3] == 608 and d[6] == 236 and d[9] == 230 then return d[4] end end end)()")
    lr = [l for l in r.eval('logs').values() if 'research: reload' in l]
    check('reload progress: timed %s, half way on the second (%s px)' % (lr, rl), lr and 'took 2.' in lr[0] and rl and 110 <= rl <= 150)
    # 1.2.1: a layout pasted into the learned file (a player's report): moved to the layout file, said on screen, and
    # the learned file written back as learned knowledge
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''LAYOUT = nil saved = { _v = 1, elements = { bar = { x = 5, style = 'vertical' } } }
      M = (function(...) ''' + SRC + ''' end)(chef) run(1)''')
    moved = r.eval('LAYOUT and LAYOUT.elements and LAYOUT.elements.bar and LAYOUT.elements.bar.x')
    t = r.eval('texts()')
    r.execute('run(6)')
    back = r.eval('saved and saved.elements == nil and saved.grip ~= nil')
    check('a layout in the learned file: moved (%s), said [%s], the learned file written back (%s)' % (moved, t, back),
          moved == 5 and 'moved to the layout file' in t and back is True)
    # 1.2.1: the read key pressed while Position isn't Custom: read, and said that only Custom uses it
    r = lua51.LuaRuntime()
    setup(r)
    r.execute("run(2) BINDS.reload_layout = true run(1 / 60) BINDS.reload_layout = false run(0.5)")
    t = r.eval('texts()')
    check('read key, not Custom: said [%s]' % t, 'Position: Custom' in t)
    # 1.2.2: a grenade's pose hides the weapon at once again (no half-second wait); the mark key writes a numbered line
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('run(3) GRIP = 41 run(0.15)')
    tg = r.eval('texts()')
    r.execute("GRIP = 10 run(1) BINDS.log_mark = true run(1 / 60) BINDS.log_mark = false run(0.2)")
    mk = [l for l in r.eval('logs').values() if 'MARK 1' in l]
    check('grenade pose: hidden at once [%s]; mark key: %s [%s]' % (tg, mk, r.eval('texts()')),
          not tg.startswith('45') and mk and 'shown: 8fcdd35c' in mk[0] and 'mark 1 in the log' in r.eval('texts()'))
    # 1.2.3: the Halt's ammo switched with the quick weapon wheel several times (held reads true for a moment each
    # time, no fire button): never taken for someone else's gun (three switches hid it for the rest of the mission)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil OBJ[95] = { name = '%s', fields = {} } local f = OBJ[95].fields
      f[ROLE.slot0] = 6 f[ROLE.slot1] = 6 f[ROLE.selected] = 0 f[ROLE.spare] = 20 f[ROLE.chamber] = true f[ROLE.carry] = 0
      f[ROLE.held] = false GRIP = 80 run(3) f[ROLE.slot0] = 5 run(0.5) FIRE = false run(1)
      for i = 1, 5 do f[ROLE.held] = true f[ROLE.selected] = i %% 2 run(0.4) f[ROLE.held] = false run(1.5) end
      for i = 1, 4 do f[ROLE.held] = true run(0.4) f[ROLE.held] = false run(1) end''' % type_name('9c06f074'))
    t = r.eval('texts()')
    check('the Halt: five ammo switches and four short holds, still shown [%s]' % t,
          'x20' in t and not any('aren\'t yours' in l or 'not yours' in l for l in r.eval('logs').values()))
    # 1.2.4: the Nova's charge let go before it fired (no shot, no heat): a SEAF gun firing just after, as you held
    # fire, isn't learned for its pose and doesn't take the HUD (a 2026-10-27 log, mark 4)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil GRIP = 52 run(3) OBJ[87] = { name = NAMES.seaf, fields = {} } local f = OBJ[87].fields
      f[ROLE.rounds] = 30 f[ROLE.magazines] = 5 f[ROLE.chamber] = true f[ROLE.carry] = 0 f[ROLE.held] = true run(1)
      local n = OBJ[5].fields n[ROLE.held] = false n[ROLE.charging] = true run(0.8) n[ROLE.charging] = false run(0.1)
      for i = 1, 3 do f[ROLE.rounds] = 30 - i run(0.15) end run(1)''')
    logs = list(r.eval('logs').values())
    check('Nova charge let go: a gun firing just after not learned [%s]' % r.eval('texts()'),
          not any('learned: type aca39ec2' in l for l in logs) and 'HEAT' in r.eval('texts()'))
    # 1.2.5: a gun that aims by itself (the aim field 6f3ab277 off 0, as SEAF soldiers' rifles do) is someone else's at
    # once, even firing as you hold the Scythe's beam; a pose its type had learned (from a saved file) is forgotten
    r = lua51.LuaRuntime()
    setup(r, seeded=True)
    r.execute('''OBJ[3] = nil saved = { poses = { aca39ec2 = '10' } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[20] = { name = NAMES.scythe, fields = {} } local g = OBJ[20].fields g[ROLE.heat] = 10 g[ROLE.overheated] = false
      g[ROLE.charging] = false g[ROLE.held] = false g[ROLE.carry] = 0 GRIP = 10 run(3)
      OBJ[88] = { name = NAMES.seaf, fields = {} } local f = OBJ[88].fields f[ROLE.rounds] = 30 f[ROLE.magazines] = 5
      f[ROLE.chamber] = true f[ROLE.carry] = 0 f[ROLE.held] = true f.h_maw9a = 0.31 run(0.3) f.h_maw9a = 0.35 run(0.3)
      f.h_maw9a = 0.29 run(0.4)
      g[ROLE.held] = true g[ROLE.charging] = true
      for i = 1, 6 do f[ROLE.rounds] = 30 - i g[ROLE.heat] = 10 + i * 3 f.h_maw9a = 0.3 + i * 0.01 run(0.3) end''')
    logs = list(r.eval('logs').values())
    t = r.eval('texts()')
    r.execute('run(6)')
    check('a self-aiming gun: not yours at once, never shown, its pose forgotten [%s] %s' % (t, [l for l in logs if 'aims by itself' in l][:1]),
          'HEAT' in t and any('aims by itself' in l for l in logs) and any('hand poses and key forgotten' in l for l in logs)
          and r.eval('saved.poses.aca39ec2') is None)
    # 1.3.0: your map pin on the screen (map_marker_type off 0, map_marker_position; z 0 on the map: drawn at your
    # height) with its distance; out of view (behind you), an arrow at the screen's edge; gone with the pin
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''function tris() local n = 0 for _, d in ipairs(draws) do if d[1] == 'tri' then n = n + 1 end end return n end
      function text_like(p) for _, d in ipairs(draws) do if d[1] == 'text' and string.find(d[4], p) then return d end end return nil end
      OPTS.map_pin = true M = (function(...) ''' + SRC + ''' end)(chef)
      local f = OBJ[2].fields f.position = { 0, 0, 1 } f.map_marker_type = 0 f.map_marker_goid = 32767 run(2)
      n0 = tris() f.map_marker_type = 1 f.map_marker_position = { 30, 40, 0 } run(0.5)''')
    n0, n1 = r.eval('n0'), r.eval('tris()')
    t = r.eval('text_like("50 m")')
    check('a map pin 50 m ahead: drawn (%d triangles, was %d) with its distance at x %s' % (n1, n0, t and t[2]),
          n1 >= n0 + 1 and t is not None and 1720 + 600 < t[2] < 1720 + 900)
    r.execute('OBJ[2].fields.map_marker_position = { 0, -40, 0 } run(0.5)')
    t = r.eval('text_like("40 m")')
    check('the pin behind you: an arrow at the bottom edge, the distance by it (y %s)' % (t and t[3]), t is not None and t[3] < 120)
    r.execute('CAM_YAW = math.pi / 2 run(0.5)')       # (facing east: the pin to the south is on the right)
    t = r.eval('text_like("40 m")')
    check('turned east: the arrow at the right edge (x %s)' % (t and t[2]), t is not None and t[2] > 3440 - 200)
    r.execute('CAM_YAW = nil OBJ[2].fields.map_marker_type = 0 run(0.5)')
    check('the pin removed: nothing drawn', r.eval('text_like(" m")') is None)
    # the death marker: your position as the health reaches 0, kept while the avatar is gone; a new life 2 m from it
    # takes it away; 3 minutes do too
    r.execute('''OPTS.death_mark = true OPTS.map_pin = false M = (function(...) ''' + SRC + ''' end)(chef)
      local f = OBJ[2].fields f.position = { 0, 0, 1 } f.health = 125 run(2) f.position = { 10, 60, 1 } run(0.3) f.health = 0 run(0.3)
      OBJ[2] = nil run(2) OBJ[2] = { name = NAMES.avatar, fields = { du7kbt = 4, ei6_t2 = 5, health = 125, position = { 0, 0, 1 } } } run(1)''')
    t = r.eval('text_like("61 m")')
    check('died 61 m away: a red diamond with its distance from the new life (%s) %s' % (t and t[2], [l for l in r.eval('logs').values() if 'died' in l]),
          t is not None and 1720 < t[2] < 1720 + 400 and t[6] == 225)
    r.execute('OBJ[2].fields.position = { 10, 59, 1 } run(0.5)')
    check('back at the spot: the marker gone', r.eval('text_like(" m")') is None)
    r.execute('''local f = OBJ[2].fields f.position = { 0, 0, 1 } run(0.3) f.health = 0 run(0.3) f.health = 125 f.position = { 0, 50, 1 } run(1)''')
    check('a death at the spawn: shown (%s)' % (r.eval('text_like("50 m")') is not None), r.eval('text_like("50 m")') is not None)
    r.execute('run(185)')
    check('3 minutes later: gone', r.eval('text_like(" m")') is None)
    # 1.4.0: the drop line: a grenade launcher's shot drawn as world lines from the view, bending down, a mark at
    # 50 and 100 m; a rifle's shot drops too little for one; "while aiming" needs the weapon's stance field at 4
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''function lines() local l = {} for _, d in ipairs(draws) do if d[1] == 'line' then l[#l + 1] = d end end return l end
      OPTS.drop_line = 3 OPTS.drop_thick = 1 WPOS = { U = { 0.4, 3, 0.4 } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[3] = nil OBJ[90] = { name = NAMES.gl, fields = {} } local f = OBJ[90].fields f[ROLE.rounds] = 10 f[ROLE.magazines] = 3
      f[ROLE.chamber] = true f[ROLE.carry] = 0 saved = { grip = { ["8c0aee6e"] = 51 } } M = (function(...) ''' + SRC + ''' end)(chef)
      GRIP = 51 run(3)''')
    ls = list(r.eval('lines()').values())
    zs = [l[4] for l in ls if l[7] == 236 and l[10] == 170]
    check('GL-21 in hand: a drop line of %d segments, from z %.1f down to %.1f' % (len(zs), zs[0] if zs else 0, zs[-1] if zs else 0),
          len(zs) >= 15 and 0.3 < zs[0] < 0.7 and max(zs) < 1.5 and zs[-1] < -10 and all(zs[i] >= zs[i + 1] for i in range(5, len(zs) - 1)))
    n1 = len(ls)
    r.execute('CHANGE.drop_thick(2) run(0.2)')
    n2 = len(r.eval('lines()'))
    check('thickness Medium: the line drawn twice (%d, was %d)' % (n2, n1), n2 == 2 * n1)
    r.execute('CHANGE.drop_thick(1) run(0.2)')
    # from the right hand (0.4 m right, 3 m ahead of the camera, 0.4 up... the mock's unit position), toward the
    # point 100 m along the camera's line: the first segment by the hand, x back near 0 by 100 m
    first = min(l[3] for l in ls)
    near100 = [l for l in ls if l[10] == 170 and 90 <= l[3] <= 110]
    check('the line starts past the hand (%.1f m out, x %.1f: a hand\'s width left of 0.4) and converges on the crosshair (x %.2f at 100 m)' % (first, ls[0][2], near100[0][2] if near100 else 9),
          12 <= first <= 15 and 0.2 < ls[0][2] <= 0.35 and near100 and abs(near100[0][2]) < 0.1)
    r.execute('WPOS = { U = false } run(0.5)')
    first = min(l[3] for l in r.eval('lines()').values())
    check('with no hand position (the unit can\'t be asked): from the view, %.1f m out' % first, 9 <= first <= 12)
    ys = [l[3] for l in ls]
    check('the line runs along the aim (y up to %.0f)' % max(ys), max(ys) > 40 and min(l[2] for l in ls) > -2)
    r.execute('OPTS.drop_line = 2 M = (function(...) ' + SRC + ' end)(chef) GRIP = 51 run(2)')
    n_hip = len(r.eval('lines()'))
    r.execute('AIM = true run(0.5)')
    n_ads = len(r.eval('lines()'))
    r.execute('AIM = false run(0.5)')
    n_after = len(r.eval('lines()'))
    check('while aiming: no line from the hip (%d), the line while the aim button is held (%d), gone after (%d)' % (n_hip, n_ads, n_after), n_hip == 0 and n_ads >= 15 and n_after == 0)
    r.execute('''OPTS.drop_line = 3 OBJ[90] = nil OBJ[41] = { name = NAMES.stalwart, fields = {} } local f = OBJ[41].fields f[ROLE.rounds] = 250
      f[ROLE.magazines] = 3 f[ROLE.carry] = 0 saved = { grip = { ["521229d8"] = 10 } } M = (function(...) ''' + SRC + ''' end)(chef) GRIP = 10 run(3)''')
    check('a Stalwart: no drop line (%d)' % len(r.eval('lines()')), len(r.eval('lines()')) == 0 and r.eval('texts()').startswith('250'))
    # a swap from a weapon with a line to one without: one empty line for a few frames (Chef keeps showing the last
    # lines dispatched otherwise), then none
    r.execute('''OBJ[90] = { name = NAMES.gl, fields = {} } local f = OBJ[90].fields f[ROLE.rounds] = 10 f[ROLE.magazines] = 3
      f[ROLE.chamber] = true f[ROLE.carry] = 0 saved = { grip = { ["8c0aee6e"] = 51, ["521229d8"] = 10 } } M = (function(...) ''' + SRC + ''' end)(chef)
      GRIP = 51 run(2) GRIP = 10 run(1 / 60) run(1 / 60)''')
    ls = list(r.eval('lines()').values())
    clear = [l for l in ls if l[10] == 0 and l[2] == l[5] and l[3] == l[6]]
    r.execute('run(0.6)')
    check('swapped to the Stalwart: a line of nothing takes the old one away (%d, alpha 0), none later (%d)' % (len(clear), len(r.eval('lines()'))),
          len(ls) == 1 and len(clear) == 1 and len(r.eval('lines()')) == 0)
    # the flight itself: without drag the drop is g t^2 / 2 (an Eruptor-like round at 180 m/s, gravity x0.3: 1.0 m at 150 m)
    pts = r.eval('M.debug_fly({ d = 15, m = 100, v = 180, drag = 0, g = 0.3 }, 0, 150)')
    last = pts[len(pts)]
    check('no drag: 150 m in %.2f s, dropped %.2f m (expected about 1.02)' % (last[1] / 180, -last[2]), 0.9 < -last[2] < 1.15)
    pts = r.eval('M.debug_fly({ d = 40, m = 50, v = 100, drag = 1.2, g = 1 }, 0, 150)')
    last = pts[len(pts)]
    check('a grenade (40 mm, 50 g, 100 m/s, drag 1.2): %.0f m of path, down %.0f m' % (last[3], -last[2]), 149 <= last[3] <= 155 and 40 < -last[2] < 90)
    # 1.5.0: throw lines: a grenade out (hand pose 40) draws an arc from the hand; a stratagem ball in reach with the
    # fire button held draws one from the ball; C4 in DEPLOY draws one while the stance field reads an aim; none off
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''function lines() local l = {} for _, d in ipairs(draws) do if d[1] == 'line' then l[#l + 1] = d end end return l end
      OPTS.throw_line = true OPTS.drop_thick = 1 WPOS = { U = { 0, 2, 0 } } M = (function(...) ''' + SRC + ''' end)(chef)
      GRIP = 10 run(2) n_gun = #lines() GRIP = 41 run(0.5)''')
    ls = list(r.eval('lines()').values())
    top = max(l[4] for l in ls) if ls else 0
    check('a grenade out: an arc of %d segments from the hand (y %.1f), rising to %.1f then down (%d from a gun)' % (
          len(ls), ls[0][3] if ls else 0, top, r.eval('n_gun')),
          r.eval('n_gun') == 0 and len(ls) > 30 and 1.5 < ls[0][3] < 2.5 and top > 0.5 and ls[-1][4] < -10)
    r.execute('GRIP = 0 run(0.15)')     # (the hand pose is read every 0.1 s)
    clear = [l for l in r.eval('lines()').values() if l[10] == 0]
    r.execute('run(0.5)')
    check('the grenade put away: a line of nothing (%d), then none (%d)' % (len(clear), len(r.eval('lines()'))), len(clear) == 1 and len(r.eval('lines()')) == 0)
    r.execute('GRIP = 40 BALL = true WPOS.B = { 0.4, 2.3, 1.2 } FIRE = false run(0.5)')
    ls = list(r.eval('lines()').values())
    r.execute('BALL = nil run(0.6)')
    ls2 = list(r.eval('lines()').values())
    check('a stratagem ball in hand: the arc all the while, from the ball (%d, from y %.1f); with no ball unit found, from the hand (%d, y %.1f)' % (
          len(ls), ls[0][3] if ls else 0, len(ls2), ls2[0][3] if ls2 else 0),
          len(ls) > 30 and 2.2 < ls[0][3] < 3.5 and len(ls2) > 30 and 1.5 < ls2[0][3] < 2.5)
    r.execute('''FIRE = false BALL = nil OBJ[3] = nil OBJ[95] = { name = NAMES.c4, fields = {} } local f = OBJ[95].fields f[ROLE.rounds] = 1 f[ROLE.magazines] = 3
      f[ROLE.options] = 0 f[ROLE.carry] = 0 saved = { grip = { ["6b2c3bed"] = 42 } } M = (function(...) ''' + SRC + ''' end)(chef) GRIP = 42 run(2)''')
    n_c4 = len(r.eval('lines()'))
    r.execute('AIM = true run(0.5)')
    n_aim = len(r.eval('lines()'))
    r.execute('OBJ[95].fields[ROLE.options] = 256 run(0.5)')
    n_det = len(r.eval('lines()'))
    r.execute('AIM = false')
    check('C4 in DEPLOY: an arc aimed or not (%d, %d); none with the detonator (%d) [%s]' % (n_c4, n_aim, n_det, r.eval('texts()')),
          n_c4 > 30 and n_aim > 30 and n_det == 0)
    # the stim icon as a texture (its size ladder told to Chef once), the pixel sprite when it can't be drawn: the
    # test's way (no menu row since 1.5.13: M.debug_cfg sets it)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('M.debug_cfg("icon_tex", 2) run(2)')
    bm = [d for d in r.eval('draws').values() if d[1] == 'bitmap']
    sp = [d for d in r.eval('draws').values() if d[1] == 'sprite']
    ladder = r.eval('TEX_SIZES')
    check('the stim drawn as a texture (%d bitmaps, %d sprites; ladder %s)' % (len(bm), len(sp), ladder is not None),
          len(bm) == 1 and len(sp) == 1 and ladder is not None and bm[0][4] == bm[0][5])
    r.execute('BITMAP = false run(0.2)')
    bm = [d for d in r.eval('draws').values() if d[1] == 'bitmap']
    sp = [d for d in r.eval('draws').values() if d[1] == 'sprite']
    check('the texture refused: both sprites again (%d, %d) %s' % (len(bm), len(sp), [l for l in r.eval('logs').values() if 'icons:' in l]),
          len(bm) == 0 and len(sp) == 2 and any('not drawn' in l for l in r.eval('logs').values()))
    r.execute('BITMAP = nil')
    # 1.2.7: the Talon (semi-automatic laser, 15 heat a shot from the wiki): each press of fire adds 15 at once; the
    # field's step (15.66, a read later) confirms it without a jump; it cools at 10 a second otherwise
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil OBJ[70] = { name = NAMES.talon, fields = {} } local f = OBJ[70].fields f[ROLE.heat] = 0
      f[ROLE.overheated] = false f[ROLE.charging] = false f[ROLE.held] = false f[ROLE.carry] = 0 f[ROLE.rpm] = 750
      f[ROLE.fire_mode] = 2 f[ROLE.magazines] = 3 FIRE = false GRIP = 9 run(3)
      function tap() FIRE = true f[ROLE.held] = true run(1 / 60) FIRE = false f[ROLE.held] = false end
      tap() f[ROLE.heat] = 15.66 run(0.5) f[ROLE.heat] = 0.1 run(3)     -- (the first shot: learned for the pose)
      tap() run(0.05) h1 = texts() f[ROLE.heat] = 15.66 run(0.4) h2 = texts()
      tap() run(1 / 60) tap() run(1 / 60) tap() run(0.05) h3 = texts() f[ROLE.heat] = 62.75 run(0.3) h4 = texts() run(2) h5 = texts()''')
    h = [r.eval(k) for k in ('h1', 'h2', 'h3', 'h4', 'h5')]
    pct = [int(x.split(' | ')[0][:-1]) if x.split(' | ')[0].endswith('%') else -1 for x in h]
    check('Talon: a tap 15 at once (%d%%), confirmed (%d%%), three more about 60 (%d%%, %d%%), 2 s later about 40 (%d%%)' % tuple(pct),
          13 <= pct[0] <= 17 and 13 <= pct[1] <= 18 and 55 <= pct[2] <= 62 and 55 <= pct[3] <= 65 and 35 <= pct[4] <= 48)
    # 1.2.8: the field's rises refine the wiki's heat a shot (the 1.2.7 log: the Talon's rises were 12 a shot, not 15,
    # and the bar ran ahead); a shot and a fall hidden inside the dead band don't measure the planet; the heat read just
    # before an overheat (84.8) is within the band of the known point (100): the point stays
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil OBJ[70] = { name = NAMES.talon, fields = {} } local f = OBJ[70].fields f[ROLE.heat] = 0
      f[ROLE.overheated] = false f[ROLE.charging] = false f[ROLE.held] = false f[ROLE.carry] = 0 f[ROLE.rpm] = 750
      f[ROLE.fire_mode] = 2 f[ROLE.magazines] = 3 FIRE = false GRIP = 9 run(3)
      function tap() FIRE = true f[ROLE.held] = true run(1 / 60) FIRE = false f[ROLE.held] = false run(0.2) end   -- (the trigger field's flicker mostly unread)
      tap() tap() f[ROLE.heat] = 23.9 run(0.5) tap() tap() f[ROLE.heat] = 42.5 run(0.5) tap() tap() tap() f[ROLE.heat] = 69.7 run(0.5)
      -- (three falls of a band each with a shot inside each, 3 s apart: 5.2 a second if taken for cooling alone)
      run(1.5) tap() run(1.3) f[ROLE.heat] = 54.0 run(1.5) tap() run(1.3) f[ROLE.heat] = 38.3 run(1.5) tap() run(1.3) f[ROLE.heat] = 22.6 run(0.5)
      tap() tap() f[ROLE.heat] = 38.9 run(0.5) tap() tap() f[ROLE.heat] = 62.3 run(0.5) tap() tap() f[ROLE.heat] = 84.8 run(0.5)
      tap() tap() f[ROLE.heat] = 0 f[ROLE.overheated] = true run(1) f[ROLE.overheated] = false f[ROLE.heat] = 0 run(6)''')
    logs = list(r.eval('logs').values())
    shot = r.eval('saved and saved.shot and saved.shot["4e87d68d"]')
    heat = r.eval('saved and saved.heat and saved.heat["4e87d68d"]')
    check('Talon: heat a shot refined from the field (%s, the wiki 15)' % shot, shot is not None and 11 <= shot <= 14.5)
    check('Talon: no planet from a fall with a shot in it %s' % [l for l in logs if 'planet' in l],
          not any('planet cooling' in l for l in logs))
    check('Talon: the overheat point stays 100 from a last read of 84.8 (%s) %s' % (heat, [l for l in logs if 'overheats at' in l]),
          heat in (None, 100) and not any('overheats at' in l for l in logs))
    # an unnamed shot laser learns its heat a shot from the field's rises over the shots
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil OBJ[80] = { name = NAMES.de, fields = {} } local f = OBJ[80].fields f[ROLE.heat] = 0
      f[ROLE.overheated] = false f[ROLE.charging] = false f[ROLE.held] = false f[ROLE.carry] = 0 f[ROLE.rpm] = 600
      f[ROLE.fire_mode] = 2 f[ROLE.magazines] = 3 FIRE = false GRIP = 15 run(3)
      function tap() FIRE = true f[ROLE.held] = true run(0.12) FIRE = false f[ROLE.held] = false run(0.1) end
      f[ROLE.heat] = 10 run(0.5)
      for k = 1, 5 do tap() tap() tap() tap() f[ROLE.heat] = 10 + k * 14 run(0.3) end''')
    logs = [l for l in r.eval('logs').values() if 'heats' in l and 'a shot' in l]
    check('shot heat learned from the rows %s' % logs[:2], any('learned: type 960653cb heats' in l for l in logs))
    # key 3 pressed while the primary's pose is still up, a Stalwart (lying on the map, yours as host) on the same pose
    # and learned on key 3: never shown on the way to the support weapon (the AMR, a 2026-10-26 log)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''saved = { slot = { ["521229d8"] = 3, ["8fcdd35c"] = 1 }, grip = { ["521229d8"] = 10 } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[41] = { name = NAMES.stalwart, fields = {} } OBJ[41].fields[ROLE.rounds] = 250 OBJ[41].fields[ROLE.magazines] = 3
      OBJ[41].fields[ROLE.carry] = 0 GRIP = 10 run(3) OBJ[3].fields[ROLE.rounds] = 43 run(0.5)
      seen = {} KEYS['3'] = true run(1 / 60) KEYS = {}
      for i = 1, 4 do run(0.1) seen[#seen + 1] = texts() end GRIP = 52 for i = 1, 6 do run(0.1) seen[#seen + 1] = texts() end''')
    seen = list(r.eval('seen').values())
    check('key 3 on a shared pose before the pose changes: no Stalwart on the way %s' % seen[:5],
          not any(t.startswith('250') for t in seen) and seen[-1].endswith('| 5 | 4') and 'HEAT' in seen[-1])
    # a rate that's 0.9 of the last (Extreme Cold), or in another mission: not a rate of fire setting (the Sightliner's
    # 40 and 36); one learned so before is dropped at the start
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''saved = { rpmadj = { ["30294946"] = true }, rpmbase = { ["30294946"] = "40" } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[3].fields[ROLE.rpm] = 40 run(3) WORLD = 2 run(1) OBJ[3].fields[ROLE.rpm] = 36 run(3)''')
    t = r.eval('texts()')
    check('rates 40 then 36 (cold, another mission): no RPM shown, no setting learned [%s]' % t,
          'RPM' not in t and not any('has a rate of fire setting' in l for l in r.eval('logs').values()))
    # a part placed after another: the magazines right after the count, however wide it grows ("100%" ran over them)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''run(3) CHANGE.position(4) run(0.5)''')
    def after_gap():
        tx = {d[4]: (d[2], d[5]) for d in r.eval('draws').values() if d[1] == 'text'}
        cnt = [k for k in tx if k not in ('x7',) and k[0].isdigit() and k not in ('5', '4')]
        return tx, cnt
    tx, cnt = after_gap()
    rect_x = [d[2] for d in r.eval('draws').values() if d[1] == 'rect' and d[4] <= 3 and d[5] >= 20]
    cx = tx[cnt[0]][0]
    w = r.eval("chef.text_width('%s', 4)" % cnt[0]) if False else None
    r.execute('OBJ[3].fields[ROLE.rounds] = 4 run(0.5)')
    rect_x2 = [d[2] for d in r.eval('draws').values() if d[1] == 'rect' and d[4] <= 3 and d[5] >= 20]
    check('Under\'s look in Custom: the magazines follow the count (divider at %s for 45, %s for 5)' % (rect_x, rect_x2),
          rect_x and rect_x2 and rect_x[0] > cx and rect_x2[0] < rect_x[0])
    # F9's offsets move a Custom layout only when its file says use_offsets = true
    def bar_xy(r):
        b = [d for d in r.eval('draws').values() if d[1] == 'rect' and d[4] == 260 and d[5] == 14]
        return (b[0][2], b[0][3]) if b else None
    r = lua51.LuaRuntime()
    setup(r)
    r.execute("OPTS.off_x = 10 OPTS.off_y = 10 M = (function(...) " + SRC + " end)(chef) run(3) CHANGE.position(4) run(0.5)")
    plain = bar_xy(r)
    r.execute("LAYOUT.use_offsets = true BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false run(0.3)")
    moved = bar_xy(r)
    check('Custom: the offsets ignored (%s), then used with use_offsets (%s)' % (plain, moved),
          plain == (1590, 590) and moved == (1590 + 344, 590 + 144))
    # a weapon picked up during the mission (its carry field to on-body): the one in hand on its pose, before it fires
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[41] = { name = NAMES.stalwart, fields = {} } OBJ[41].fields[ROLE.rounds] = 250 OBJ[41].fields[ROLE.magazines] = 3
      OBJ[41].fields[ROLE.carry] = 1 saved = { grip = { ["521229d8"] = 10 } } M = (function(...) ''' + SRC + ''' end)(chef)
      GRIP = 10 run(3) OBJ[3].fields[ROLE.rounds] = 43 run(1) OBJ[41].fields[ROLE.carry] = 0 run(1.5)''')
    check('a Stalwart picked up on the Arbitrator\'s pose: shown [%s]' % r.eval('texts()'),
          r.eval('texts()').startswith('250') and any('picked up' in l for l in r.eval('logs').values()))
    # 1.2.8: a support weapon out of its hellpod keeps a stray aim value (0.012, never moving) as you hold it: still
    # yours (the 1.2.7 log hid a weapon for it); one whose aim moves isn't
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[41] = { name = NAMES.stalwart, fields = {} } OBJ[41].fields[ROLE.rounds] = 250 OBJ[41].fields[ROLE.magazines] = 3
      OBJ[41].fields[ROLE.carry] = 1 OBJ[41].fields.h_maw9a = 0.012 saved = { grip = { ["521229d8"] = 10 } } M = (function(...) ''' + SRC + ''' end)(chef)
      GRIP = 10 run(3) OBJ[3].fields[ROLE.rounds] = 43 run(1) OBJ[41].fields[ROLE.carry] = 0 run(3)''')
    check('a picked-up weapon with a stray aim value that never moves: still shown [%s]' % r.eval('texts()'),
          r.eval('texts()').startswith('250') and not any('aims by itself' in l for l in r.eval('logs').values()))
    r.execute('OBJ[41].fields.h_maw9a = 0.2 run(0.3) OBJ[41].fields.h_maw9a = 0.3 run(0.3) OBJ[41].fields.h_maw9a = 0.25 run(1)')
    check('its aim moving: not yours', any('aims by itself' in l for l in r.eval('logs').values()))
    # a heat weapon's heat sinks: shown, 0 too once it has carried some (the Laser Cannon)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''saved = { grip = { d100e0c8 = 20 } } M = (function(...) ''' + SRC + ''' end)(chef)
      OBJ[3] = nil OBJ[13] = { name = NAMES.laser, fields = {} } local f = OBJ[13].fields f[ROLE.heat] = 0
      f[ROLE.overheated] = false f[ROLE.charging] = false f[ROLE.held] = false f[ROLE.carry] = 0 f[ROLE.magazines] = 2
      GRIP = 20 run(3)''')
    t2 = r.eval('texts()')
    r.execute('OBJ[13].fields[ROLE.magazines] = 0 run(0.5)')
    t0 = r.eval('texts()')
    check('heat sinks: x2, then x0 when used up [%s] [%s]' % (t2, t0), 'x2' in t2 and 'x0' in t0)
    # a pose with no weapon on it that isn't a grenade's or stratagem's (vaulting, a stim): the weapon shown stays 2 s
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('run(3) GRIP = 15 run(1)')
    t1 = r.eval('texts()')
    r.execute('run(1.5)')
    t2 = r.eval('texts()')
    r.execute('GRIP = 10 run(0.5) press("2") GRIP = 15 run(0.5)')
    t3 = r.eval('texts()')
    check('pose 15 for 1 s: still shown [%s]; after 2 s: not [%s]; after a swap key: not at once [%s]' % (t1, t2, t3),
          t1.startswith('45 |') and not t2.startswith('45') and not t3.startswith('45'))
    # research log: where the time goes, once a minute
    r.execute('GRIP = 10 run(61)')
    tl = [l for l in r.eval('logs').values() if l.startswith('time a frame')]
    check('research: a timing line a minute %s' % tl[:1], len(tl) == 1 and 'weapons' in tl[0] and 'fields' in tl[0])
    # someone else's game: the host's own player and Helldiver are in the list too: your grenades and stims shown,
    # never theirs (a 2026-10-25 log: they flicked between 3 and 5)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''HOST = '1111111111111111' OBJ[90] = { name = NAMES.player, fields = { u4d1h9a = 91 } }
      OBJ[91] = { name = NAMES.avatar, fields = { du7kbt = 9, ei6_t2 = 8 } } HOSTS[90] = true HOSTS[91] = true run(3)''')
    seen = set()
    for i in range(12):
        r.execute('run(0.5)')
        t = r.eval('texts()')
        seen.add(t.split(' | ')[-2:].__str__())
    check('joined: your grenades and stims, never the host\'s %s' % sorted(seen), seen == {str(['5', '4'])})
    # 1.5.13: Position: Curved pair, the built-in layout: no file read or written, the bar a ) right of the crosshair
    # (triangles), stims and grenades left of it, the count right, and F9's offsets move it
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('run(3) CHANGE.position(5) run(0.5)')
    logs = list(r.eval('logs').values())
    tri = [d for d in r.eval('draws').values() if d[1] == 'tri']
    spr = [d for d in r.eval('draws').values() if d[1] == 'sprite']
    cnt = [d for d in r.eval('draws').values() if d[1] == 'text' and d[4] == '45']
    check('curved pair: no layout file touched %s' % [l for l in logs if 'layout' in l], not any('layout file' in l for l in logs) and r.eval('LAYOUT') is None)
    check('curved pair: curved bars (%d triangles), the items left of the middle (%s), the count right (%s)' % (len(tri), [s_[2] for s_ in spr], [c[2] for c in cnt]),
          len(tri) > 10 and len(spr) == 2 and all(s_[2] < 1720 for s_ in spr) and cnt and all(c[2] > 1720 for c in cnt))
    r.execute('CHANGE.off_x(10) run(0.5)')
    spr2 = [d for d in r.eval('draws').values() if d[1] == 'sprite']
    check('curved pair: F9\'s offset moves it (%s)' % [s_[2] for s_ in spr2], len(spr2) == 2 and all(abs(b[2] - a[2] - 344) < 2 for a, b in zip(spr, spr2)))
    # Position: Custom, no layout file yet: one with Under's look written, and drawn from it
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('run(3) CHANGE.position(4) run(0.5)')
    logs = list(r.eval('logs').values())
    rects = [d for d in r.eval('draws').values() if d[1] == 'rect']
    bar = [d for d in rects if d[4] == 260 and d[5] == 14]
    check('custom, no file: Under\'s look written and read %s' % [l for l in logs if 'layout' in l],
          any('none yet' in l for l in logs) and r.eval('LAYOUT and LAYOUT.elements and LAYOUT.elements.bar.y') == -9)
    check('custom, no file: the bar under the crosshair (%s)' % [(b[2], b[3]) for b in bar], bar and bar[0][2] == 1590 and bar[0][3] == 590)
    t = r.eval('texts()')
    check('custom, no file: count, magazines, items [%s]' % t, '45' in t and 'x7' in t and r.eval('count("sprite")') == 2)
    # a layout of your own: a vertical bar bottom left, the count top right, the magazines as squares, no stims;
    # read with the reload key
    r.execute('''LAYOUT = { _v = 1, elements = {
        bar = { anchor = 'bottom_left', x = 2, y = 10, align = 'bottom_left', style = 'vertical', length = 100, thickness = 6 },
        count = { anchor = 'top_right', x = -5, y = -5, align = 'top_right', size = 2 },
        mags = { anchor = 'top_right', x = -5, y = -10, align = 'top_right', style = 'squares' },
        stims = { on = false }, grenades = { anchor = 'center', x = 0, y = 0, opacity = 50 } } }
      BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false run(0.3)''')
    dr = list(r.eval('draws').values())
    vbar = [d for d in dr if d[1] == 'rect' and d[4] == 6 and d[5] >= 90]
    check('custom: a vertical bar bottom left (%s)' % [(b[2], b[3], b[4], b[5]) for b in vbar[:2]],
          vbar and vbar[0][2] == 29 and vbar[0][3] == 144)
    cnt = [d for d in dr if d[1] == 'text' and d[4] == '45']
    check('custom: the count, twice the size, by the top right (%s)' % [(c[2], c[3], c.size) for c in cnt],
          cnt and cnt[0][2] > 3000 and cnt[0][3] > 1200 and cnt[0].size == 80)
    sq = [d for d in dr if d[1] == 'rect' and d[4] == d[5] == 6]
    check('custom: 7 magazine squares (%d)' % len(sq), len(sq) == 7)
    spr = [d for d in dr if d[1] == 'sprite']
    check('custom: no stims, the grenade at the middle (%s)' % [(s_[2], s_[3]) for s_ in spr], len(spr) == 1 and abs(spr[0][2] - 1720) < 5)
    check('custom: read again with the key', any('layout file: read (the reload key)' in l for l in r.eval('logs').values()))
    # values that don't fit: left at their defaults, counted
    r.execute('''LAYOUT = { _v = 1, elements = { bar = { length = 'long', size = 99, anchor = 'middle', thickness = 10 }, count = 5 } }
      BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false run(0.3)''')
    logs = list(r.eval('logs').values())
    bar = [d for d in r.eval('draws').values() if d[1] == 'rect' and d[4] == 260 and d[5] == 10]
    check('custom: 4 values that didn\'t fit dropped, the rest used %s' % [l for l in logs if 'didn' in l][-1:],
          any('4 values that didn\'t fit' in l for l in logs) and len(bar) >= 1)
    # a file that can't be read (a typo in a hand edit): never written over, Under's look meanwhile, said on screen
    r.execute('''LAYOUT_ERR = '[string "layout"]:3: unexpected symbol' LAYOUT = 'kept'
      BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false run(0.3)''')
    t = r.eval('texts()')
    check('custom, a broken file: kept, Under\'s look, said [%s]' % t, r.eval('LAYOUT') == 'kept' and "can't be read" in t)
    r.execute("LAYOUT_ERR = nil LAYOUT = { _v = 1, elements = {} } BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false run(0.3)")
    # every part off in F9: nothing drawn here either
    r.execute('''for _, id in ipairs({ 'show_bar', 'show_count', 'show_mags', 'show_heat', 'show_mode', 'show_fmode', 'show_rpm',
      'show_charge', 'show_stims', 'show_grenades', 'pack' }) do CHANGE[id](false) end run(3.5)''')
    check('custom, everything off in F9: nothing drawn (%s)' % [list(d.values()) for d in r.eval('draws').values()][:2], len(r.eval('draws')) == 0)
    # custom, a heat weapon (the Nova): its bar vertical with the heat marks, HEAT in the modes, stacked
    r.execute('''for _, id in ipairs({ 'show_bar', 'show_count', 'show_mags', 'show_heat', 'show_mode', 'show_fmode', 'show_rpm',
      'show_charge', 'show_stims', 'show_grenades', 'pack' }) do CHANGE[id](true) end
      LAYOUT = { _v = 1, elements = { bar = { style = 'vertical', length = 80 }, modes = { style = 'stacked', x = 10 } } }
      BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false GRIP = 52 run(3)''')
    tx = {d[4]: (d[2], d[3]) for d in r.eval('draws').values() if d[1] == 'text'}
    check('custom, the Nova: 0%% and HEAT shown %s' % tx, '0%' in tx and 'HEAT' in tx)
    # curved bars: the Nova's heat bar as a ")", then a "("; where Chef draws triangles as rows of rects: vertical
    def tri_pts():
        pts = []
        for d in r.eval('draws').values():
            if d[1] == 'tri': pts += [(d[2], d[3]), (d[4], d[5]), (d.x3, d.y3)]
        return pts
    def bulge(pts):   # how far the middle sticks out right of the ends (+ a ")", - a "(")
        ys = [p[1] for p in pts]; y0, y1 = min(ys), max(ys); mid = (y0 + y1) / 2
        ends = [p[0] for p in pts if p[1] < y0 + 3 or p[1] > y1 - 3]
        middle = [p[0] for p in pts if abs(p[1] - mid) < (y1 - y0) / 4]
        return (max(middle) - max(ends)) if middle and ends else 0, y1 - y0
    r.execute('''LAYOUT = { _v = 1, elements = { bar = { style = 'curved_right', length = 260, radius = 150, thickness = 14 } } }
      BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false OBJ[5].fields[ROLE.heat] = 50 run(0.5)''')
    b_, hgt = bulge(tri_pts())
    # 260 along a 150 radius: 99 degrees, so the ends are 150 * (1 - cos 49.7) = 53 left of the middle, 2 * 157 * sin 49.7 tall
    check('custom, curved right: a ")" (bulge %.0f, height %.0f)' % (b_, hgt), 45 < b_ < 62 and 225 < hgt < 250)
    ntri = sum(1 for d in r.eval('draws').values() if d[1] == 'tri')
    check('custom, curved right: few triangles (%d a frame; each costs in game)' % ntri, 0 < ntri <= 30)
    r.execute('''LAYOUT.elements.bar.style = 'curved_left' BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false run(0.3)''')
    pts = tri_pts()
    b_, hgt = bulge([(-x_, y_) for x_, y_ in pts])
    check('custom, curved left: a "(" (bulge %.0f)' % b_, 45 < b_ < 62)
    r.execute('TRI_ROWS = true BINDS.reload_layout = true run(0.1) BINDS.reload_layout = false run(0.3)')
    dr = list(r.eval('draws').values())
    check('custom, curved where Chef draws triangles as rects: vertical, logged',
          not tri_pts() and [d for d in dr if d[1] == 'rect' and d[4] == 14 and d[5] >= 200] and
          any('curved bars' in l for l in r.eval('logs').values()))
    # the Halt: two loaded ammo types (slot0 flechette, slot1 stun), chosen by the selected field: each named, each its
    # own magazine (a switch isn't a reload)
    r = lua51.LuaRuntime()
    setup(r)
    r.execute('''OBJ[3] = nil OBJ[95] = { name = '%s', fields = {} } local f = OBJ[95].fields
      f[ROLE.slot0] = 6 f[ROLE.slot1] = 6 f[ROLE.selected] = 0 f[ROLE.spare] = 20 f[ROLE.chamber] = true f[ROLE.carry] = 0
      GRIP = 80 run(3) f[ROLE.slot0] = 5 run(0.5)''' % type_name('9c06f074'))
    t = r.eval('texts()')
    check('the Halt on flechette: learned, FLECHETTE shown [%s]' % t, 'FLECHETTE' in t and t.startswith('5 |'))
    r.execute('OBJ[95].fields[ROLE.selected] = 1 run(0.3) OBJ[95].fields[ROLE.slot1] = 5 run(0.3)')
    t = r.eval('texts()')
    check('the Halt on stun: STUN, its own count [%s]' % t, 'STUN' in t and t.startswith('5 |') and 'FLECHETTE' not in t)
    # a controller that isn't the first one the engine has (Pad3)
    rt7b = lua51.LuaRuntime()
    setup(rt7b)
    rt7b.execute('PAD = true PADN = 3 GRIP = 70 run(3) for i = 1, 4 do OBJ[4].fields[ROLE.rounds] = 12 - i run(0.5) end')
    t = rt7b.eval('texts()')
    check('controller on Pad3: its trigger read, the weapon shown [%s]' % t, t.startswith('8 |'))
    # a PlayStation pad (R2), and a pad that doesn't list its buttons (the Xbox names on Pad1)
    for label, setup_lua in (('PlayStation pad on Pad2 (R2)', 'PS = true PADN = 2'), ('unlisted buttons', 'PADNAMES = false')):
        r = lua51.LuaRuntime()
        setup(r)
        r.execute('PAD = true ' + setup_lua + ' GRIP = 70 run(3) for i = 1, 4 do OBJ[4].fields[ROLE.rounds] = 12 - i run(0.5) end')
        t = r.eval('texts()')
        check('controller, %s: the weapon shown [%s]' % (label, t), t.startswith('8 |'))
        check('controller, %s: logged once' % label, sum(1 for l in r.eval('logs').values() if l.find('controller: Pad') >= 0) == 1)
    # a controller NarrowHUD can't read at all: the weapon in hand (known from the seed) keeps showing as it fires
    rt7c = lua51.LuaRuntime()
    setup(rt7c, seeded=True)
    rt7c.execute('''PAD = true NOPAD = true OBJ[3] = nil OBJ[40] = { name = NAMES.verdict, fields = {} } OBJ[40].fields[ROLE.rounds] = 10
      OBJ[40].fields[ROLE.magazines] = 6 OBJ[40].fields[ROLE.chamber] = true OBJ[40].fields[ROLE.carry] = 0 GRIP = 36 run(3)
      for i = 1, 6 do OBJ[40].fields[ROLE.rounds] = 10 - i run(0.6) end''')
    t = rt7c.eval('texts()')
    logs = list(rt7c.eval('logs').values())
    check('unreadable controller: still shown after 6 shots [%s]' % t, t.startswith('4 |'))
    check('unreadable controller: logged once', sum(1 for l in logs if "shots aren't checked from now on" in l) == 1)
    check('unreadable controller: not taken for someone else\'s', not any('not yours' in l for l in logs))
    # beside the crosshair (compact): a vertical bar right of the middle, the count right of it, the magazines as
    # squares under it, labels under those
    rt7.execute('CHANGE.position(2) GRIP = 10 run(1)')
    rects = [d for d in rt7.eval('draws').values() if d[1] == 'rect']
    tx = {d[4]: (d[2], d[3]) for d in rt7.eval('draws').values() if d[1] == 'text'}
    xs = [d[2] for d in rects]
    check('beside: everything right of the middle (%s)' % (min(xs) if xs else None), xs and min(xs) > 1720)
    bar = [d for d in rects if d[5] > d[4] * 5]
    check('beside: a vertical bar (%s)' % bar[:2], len(bar) >= 1)
    squares = [d for d in rects if d[4] == d[5] and d[4] == 8]
    check('beside: 7 magazines as squares (%d)' % len(squares), len(squares) == 7)
    # the empty ones as an outline, or hidden
    rt7.execute('for _, o in pairs(OBJ) do if o.fields[ROLE.magazines] == 7 then o.fields[ROLE.magazines] = 4 end end CHANGE.mags_empty(2) run(0.3)')
    full = len([d for d in rt7.eval('draws').values() if d[1] == 'rect' and d[4] == d[5] and d[4] == 8])
    check('beside, empty hidden: only the full ones (%d of 7)' % full, 0 < full < 7)
    rt7.execute('CHANGE.mags_empty(1) CHANGE.outline(true) run(0.3)')
    rs = [d for d in rt7.eval('draws').values() if d[1] == 'rect']
    sq = len([d for d in rs if d[4] == d[5] and d[4] == 8])
    edges = len([d for d in rs if (d[4] == 8 and d[5] == 1) or (d[4] == 1 and d[5] == 6)])
    check('beside, empty as outlines: %d full, %d edges' % (sq, edges), sq == full and edges == 4 * (7 - full))
    rt7.execute('CHANGE.outline(false) for _, o in pairs(OBJ) do if o.fields[ROLE.magazines] == 4 then o.fields[ROLE.magazines] = 7 end end run(0.3)')
    rt7.execute('GRIP = 52 run(1)')
    tx = {d[4]: (d[2], d[3]) for d in rt7.eval('draws').values() if d[1] == 'text'}
    check('beside: the Nova\'s HEAT label under its count %s' % tx, 'HEAT' in tx and '0%' in tx and tx['HEAT'][1] < tx['0%'][1])
    # in a screen corner, with the bar, items and backpack off and the magazines as a number: the count, xN and modes
    rt7.execute('CHANGE.position(3) CHANGE.show_bar(false) CHANGE.show_stims(false) CHANGE.show_grenades(false) CHANGE.pack(false) CHANGE.mags(2) GRIP = 10 run(1)')
    dr = list(rt7.eval('draws').values())
    xs = [d[2] for d in dr]
    t = rt7.eval('texts()')
    check('corner: drawn by the left edge (%s..%s)' % (min(xs), max(xs)), min(xs) == int(3440 * 0.02) and max(xs) < 600)
    check('corner: no icons, one rect (the | before xN) [%s]' % t, not any(d[1] == 'sprite' for d in dr)
          and sum(1 for d in dr if d[1] == 'rect') == 1 and 'x7' in t)
    rt7.execute('CHANGE.off_x(78) CHANGE.off_y(30) run(0.3)')
    xs = [d[2] for d in rt7.eval('draws').values()]
    check('corner: moved by the offsets (%s)' % min(xs), min(xs) == int(3440 * 0.8))
    # with the bar back on: drawn in the corner too (the toggles apply everywhere)
    rt7.execute('CHANGE.off_x(0) CHANGE.off_y(0) CHANGE.show_bar(true) run(0.3)')
    bars = [d for d in rt7.eval('draws').values() if d[1] == 'rect' and d[5] > d[4] * 5]
    check('corner, the bar on: its vertical bar at the corner (%s)' % [b[2] for b in bars[:1]], bars and bars[0][2] == int(3440 * 0.02))
    # everything off: nothing drawn
    rt7.execute('''for _, id in ipairs({ 'show_bar', 'show_count', 'show_mags', 'show_heat', 'show_mode', 'show_fmode', 'show_rpm',
      'show_charge', 'show_stims', 'show_grenades', 'pack' }) do CHANGE[id](false) end''')
    for pos in (1, 2, 3):
        rt7.execute('CHANGE.position(%d) GRIP = 10 run(0.3)' % pos)
        n10 = len(rt7.eval('draws'))
        rt7.execute('GRIP = 52 run(0.3)')
        check('everything off, position %d: nothing drawn (%d, %d)' % (pos, n10, len(rt7.eval('draws'))), n10 == 0 and len(rt7.eval('draws')) == 0)
    rt7.execute('''for _, id in ipairs({ 'show_bar', 'show_count', 'show_mags', 'show_heat', 'show_mode', 'show_fmode', 'show_rpm',
      'show_charge', 'show_stims', 'show_grenades', 'pack' }) do CHANGE[id](true) end CHANGE.mags(1)''')
    # under the crosshair, 10 % right and 5 % up: 344 px right, 72 px higher at 3440 x 1440
    rt7.execute('CHANGE.position(1) GRIP = 10 run(0.3)')
    b0 = [d for d in rt7.eval('draws').values() if d[1] == 'rect'][0]
    rt7.execute('CHANGE.off_x(10) CHANGE.off_y(5) run(0.3)')
    b1 = [d for d in rt7.eval('draws').values() if d[1] == 'rect'][0]
    check('under, offset 10 / 5: moved %s, %s px' % (b1[2] - b0[2], b1[3] - b0[3]), b1[2] - b0[2] == 344 and b1[3] - b0[3] == 72)
    rt7.execute('CHANGE.off_x(0) CHANGE.off_y(0) CHANGE.position(2) GRIP = 52 run(1)')
    rt7.execute('CHANGE.position(1) run(1)')
    tx = {d[4]: (d[2], d[3]) for d in rt7.eval('draws').values() if d[1] == 'text'}
    check('under the crosshair again: HEAT left of the bar %s' % tx, 'HEAT' in tx and tx['HEAT'][0] < 1720 - 130)

    # the research log is off unless turned on in the menu
    rt8 = lua51.LuaRuntime()
    setup(rt8)
    rt8.execute('OPTS.research = nil logs = {}')
    rt8.execute('M = (function(...) ' + SRC + ' end)(chef) run(3)')
    check('research log off by default', not any('research log on' in l for l in rt8.eval('logs').values()))

    # Chef 1.1 refusing the reads: a message on screen for the first seconds of a mission, then nothing
    rt9 = lua51.LuaRuntime()
    setup(rt9)
    rt9.execute('BLOCKED = true run(8)')
    t = rt9.eval('texts()')
    check('reads refused: the message shown [%s]' % t, 'blocks the reads' in t)
    check('reads refused: logged once', sum(1 for l in rt9.eval('logs').values() if 'refused' in l) == 1)
    rt9.execute('run(20)')
    check('reads refused: the message gone after 25 s [%s]' % rt9.eval('texts()'), 'blocks the reads' not in rt9.eval('texts()'))

    # a backpack lying on the map reads as carried (0): one there from the mission's start isn't yours until you've
    # moved it (dropped 2, picked up 0) or it went down with your use
    rt10 = lua51.LuaRuntime()
    setup(rt10)
    packbar = "(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 215 then return d[4] end end end)()"
    rt10.execute('''OBJ[50] = { name = NAMES.pack2, fields = {} } OBJ[50].fields[ROLE.remaining] = 4 OBJ[50].fields[ROLE.carry] = 0
      OBJ[50].fields[ROLE.owner] = '0b99cf5492296d6e' run(4)''')
    check('a backpack on the map from the start: no backpack bar', rt10.eval(packbar) is None)
    # 1.2.8: a jump pack there from the start the same (the 1.2.7 log showed a recharge bar with no pack on): no bar
    # until it's used (its flag moves)
    jumpbar = "(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 7 and d[9] == 180 then return d[4] end end end)()"
    rt10.execute('''OBJ[52] = { name = "ddb66ra", fields = { c4zfiq = false } } OBJ[52].fields[ROLE.carry] = 0 run(4)''')
    check('a jump pack on the map from the start: no recharge bar', rt10.eval(jumpbar) is None)
    rt10.execute('OBJ[52].fields.c4zfiq = true run(0.5) OBJ[52].fields.c4zfiq = false run(1)')
    check('the same jump pack used: its bar shown', rt10.eval(jumpbar) is not None)
    rt10.execute('OBJ[52] = nil run(1)')
    rt10.execute('OBJ[50].fields[ROLE.carry] = 2 run(1.5) OBJ[50].fields[ROLE.carry] = 0 run(1.5)')
    check('the same backpack dropped and picked up: its bar shown', rt10.eval(packbar) is not None)
    # one from a hellpod later in the mission: in its pod (1), then worn (0)
    rt10.execute('''OBJ[50] = nil run(25) OBJ[51] = { name = NAMES.pack2, fields = {} } OBJ[51].fields[ROLE.remaining] = 4
      OBJ[51].fields[ROLE.carry] = 0 OBJ[51].fields[ROLE.owner] = '0b99cf5492296d6e' run(3)''')
    check('a backpack first seen worn later in the mission: its bar shown', rt10.eval(packbar) is not None)
    rt10.execute('CHANGE.show_stims(false) CHANGE.show_grenades(false) run(0.5)')
    check('grenades and stims off: the backpack bar still shown, no icons', rt10.eval(packbar) is not None and rt10.eval('count("sprite")') == 0)
    rt10.execute('CHANGE.pack(false) run(0.5)')
    check('the backpack bar off too: none', rt10.eval(packbar) is None)
    rt10.execute('CHANGE.show_grenades(true) CHANGE.pack(true) run(0.5)')
    check('grenades on, stims off: one icon', rt10.eval('count("sprite")') == 1)
    rt10.execute('CHANGE.show_stims(true) run(0.5)')

    # two weapons on one pose at a mission's start, none fired yet: the one on swap key 1 (the primary)
    rt11 = lua51.LuaRuntime()
    setup(rt11)
    rt11.execute('''OBJ[4] = nil saved = { slot = { ['%s'] = 3, ['8fcdd35c'] = 1 }, poses = { ['%s'] = '10' } }
      OBJ[45] = OBJ[3]
      OBJ[3] = { name = NAMES.stalwart, fields = {} } OBJ[3].fields[ROLE.rounds] = 249 OBJ[3].fields[ROLE.magazines] = 3
      OBJ[3].fields[ROLE.chamber] = true OBJ[3].fields[ROLE.carry] = 0
      M = (function(...) ''' % ('521229d8', '521229d8') + SRC + ''' end)(chef) run(3)''')
    t = rt11.eval('texts()')
    check('mission start, the Arbitrator and a Stalwart on pose 10: the Arbitrator (key 1) shown [%s]' % t, t.startswith('45 |'))

    # a key that isn't the weapon's brings its pose up (the Solo Silo's remote, on key 3, held like the Warrant on key
    # 2): the Warrant isn't shown until its own key, or it fires
    rt13 = lua51.LuaRuntime()
    setup(rt13)
    rt13.execute('''OBJ[90] = { name = NAMES.verdict, fields = {} } OBJ[90].fields[ROLE.rounds] = 10 OBJ[90].fields[ROLE.magazines] = 6
      OBJ[90].fields[ROLE.chamber] = true OBJ[90].fields[ROLE.carry] = 0
      GRIP = 1 run(3) OBJ[90].fields[ROLE.rounds] = 9 run(6) saved.slot["c7dfd9eb"] = 2
      GRIP = 10 run(1) press('3') GRIP = 1 run(1)''')
    t = rt13.eval('texts()')
    check('key 3 brings up the Warrant\'s pose: its ammo not shown [%s]' % t, not t.startswith('9 |'))
    rt13.execute("run(4)")
    check('still not, a few seconds on [%s]' % rt13.eval('texts()'), not rt13.eval('texts()').startswith('9 |'))
    rt13.execute("press('2')")
    check('its own key 2: shown again [%s]' % rt13.eval('texts()'), rt13.eval('texts()').startswith('9 |'))

    # the Double-Edge Sickle: heat runs to 200 and hurts from 100: the bar to 200, the % as the heat is, red past 100
    rt12 = lua51.LuaRuntime()
    setup(rt12)
    rt12.execute('''OBJ[3] = nil OBJ[80] = { name = NAMES.de, fields = {} } OBJ[80].fields[ROLE.heat] = 0 OBJ[80].fields[ROLE.overheated] = false
      OBJ[80].fields[ROLE.charging] = false OBJ[80].fields[ROLE.carry] = 0 OBJ[80].fields[ROLE.magazines] = 3 GRIP = 15 run(2)
      for i = 1, 15 do OBJ[80].fields[ROLE.heat] = i * 10 run(0.1) end OBJ[80].fields[ROLE.held] = false run(0.05)''')
    t = rt12.eval('texts()')
    pct = [int(x[:-1]) for x in t.split(' | ') if x.endswith('%')]
    check('Double-Edge Sickle at 150 heat: about 150 %% [%s]' % t, pct and 130 <= pct[0] <= 160)
    tone = "(function() for _, d in ipairs(draws) do if d[1] == 'text' and d[4]:sub(-1) == '%' then return d[6] .. ',' .. d[7] end end end)()"
    check('Double-Edge Sickle past 100: the count orange (%s)' % rt12.eval(tone), rt12.eval(tone) == '240,170')
    marks = rt12.eval("(function() local n = 0 for _, d in ipairs(draws) do if d[1] == 'rect' and d[5] == 18 then n = n + 1 end end return n end)()")
    check('three marks: 50, 100, 180 (%s)' % marks, marks == 3)
    rt12.execute('for i = 16, 19 do OBJ[80].fields[ROLE.heat] = i * 10 run(0.1) end OBJ[80].fields[ROLE.held] = false run(0.6)')
    check('past 180: red (%s) [%s]' % (rt12.eval(tone), rt12.eval('texts()')), rt12.eval(tone) == '225,75')

    # the game's version: unknown to NarrowHUD's data: off, with a message; the option runs it anyway
    rt14 = lua51.LuaRuntime()
    rt14.execute("BUILD_ID = 'stingray:99999 0000'")
    setup(rt14)
    rt14.execute('run(3)')
    t = rt14.eval('texts()')
    check('another game version: off, the message shown [%s]' % t, 'game was updated' in t and '45' not in t)
    check('logged', any('not the one NarrowHUD' in l for l in rt14.eval('logs').values()))
    rt14.execute("CHANGE.any_build(true) run(3)")
    check('run anyway (the option): shown [%s]' % rt14.eval('texts()'), '45' in rt14.eval('texts()'))
    # another game version, with Network.object_info (Chef 1.2): the data checked; a type whose rounds field moved
    # (the Arbitrator) left out, the rest run
    rt14b = lua51.LuaRuntime()
    rt14b.execute("BUILD_ID = 'stingray:99999 0000'")
    setup(rt14b)
    rt14b.execute('''OBJINFO = function(name)
        local f = { { id = '0f27c68e' }, { id = 'd92082f9' }, { id = '5f8eb478' }, { id = '35ff0b52' }, { id = 'faaa8598' } }
        for role, r in pairs(DATA_ROLES) do
          if not (name == NAMES.arb and role == 'rounds') then f[#f + 1] = { id = string.gsub(r, '^0+', '') } end
        end
        return { priority = 0, fields = f }
      end
      GRIP = 52 run(6)''')
    t = rt14b.eval('texts()')
    check('another version, checked: running, the Nova shown [%s]' % t, 'HEAT' in t and 'game was updated' not in t)
    check('the check logged %s' % [l for l in rt14b.eval('logs').values() if 'version check' in l],
          any('game version check: done' in l and '1 left out' in l for l in rt14b.eval('logs').values()))
    rt14b.execute('GRIP = 10 run(2)')
    check('the Arbitrator (its rounds field moved) not shown [%s]' % rt14b.eval('texts()'), '45' not in rt14b.eval('texts()'))

    rt15 = lua51.LuaRuntime()
    rt15.execute("BUILD_ID = 'stingray:46659 e176252a3ac4eb5436b25e7cef665a8c71afa243'")
    setup(rt15)
    rt15.execute('run(3)')
    check('the game version it was made for: shown [%s]' % rt15.eval('texts()'), '45' in rt15.eval('texts()'))

    # the learned file: entries that don't fit dropped (a damaged file), saved with its version
    rt16 = lua51.LuaRuntime()
    setup(rt16)
    rt16.execute('''logs = {} saved = { grip = { ['8fcdd35c'] = 'ten', zz = 3, ['12345678'] = 10 }, poses = 5, mag = { ['8fcdd35c'] = 0/0 } }
      M = (function(...) ''' + SRC + ''' end)(chef) run(3)''')
    check('a damaged learned file: what fits kept, the rest dropped %s' % [l for l in rt16.eval('logs').values() if 'learned file' in l],
          any("entries kept, 4 that didn't fit dropped" in l for l in rt16.eval('logs').values()) and '45' in rt16.eval('texts()'))
    rt16.execute('OBJ[3].fields[ROLE.rounds] = 40 run(6)')
    check('saved with its version (%s)' % rt16.eval('saved._v'), rt16.eval('saved._v') == 1)
    # forgetting: the weapon in hand (its pose gone: not shown till it fires), everything (pressed twice)
    rt16.execute("OBJ[4] = nil BINDS.forget_weapon = true run(1 / 60) BINDS.forget_weapon = false run(1)")
    check('forgot the weapon in hand: logged, the message [%s]' % rt16.eval('texts()'),
          any('forgot what was learned about type 8fcdd35c' in l for l in rt16.eval('logs').values()) and 'forgot this weapon' in rt16.eval('texts()'))
    rt16.execute("BINDS.forget_all = true run(1 / 60) BINDS.forget_all = false run(0.5)")
    check('forget everything, first press: asks again [%s]' % rt16.eval('texts()'), 'press again' in rt16.eval('texts()'))
    rt16.execute("BINDS.forget_all = true run(1 / 60) BINDS.forget_all = false run(0.5)")
    check('second press: forgotten', any('forgot everything learned' in l for l in rt16.eval('logs').values()))

    # beside: the magazines as squares up to the most carried (grey ones), or as a number after the count
    rt17 = lua51.LuaRuntime()
    setup(rt17)
    rt17.execute('CHANGE.position(2) GRIP = 10 run(2) OBJ[3].fields[ROLE.magazines] = 5 run(1)')
    sq = [d for d in rt17.eval('draws').values() if d[1] == 'rect' and d[4] == d[5] == 8]
    grey = [d for d in sq if d[6] == 150]
    check('5 of 7 magazines: 7 squares, 2 grey (%d, %d)' % (len(sq), len(grey)), len(sq) == 7 and len(grey) == 2)
    rt17.execute('CHANGE.mags(2) run(1)')
    tx = {d[4]: (d[2], d[3]) for d in rt17.eval('draws').values() if d[1] == 'text'}
    sq = [d for d in rt17.eval('draws').values() if d[1] == 'rect' and d[4] == d[5] == 8]
    check('as a number: x5 after the count, no squares %s' % tx, 'x5' in tx and not sq and tx['x5'][0] > tx['45'][0])

    # options: colours, opacity, fade, text toggles, the fire button, beside up / down
    rt18 = lua51.LuaRuntime()
    setup(rt18)
    cnt = "(function() for _, d in ipairs(draws) do if d[1] == 'text' and d[4] == '%s' then return d[6] .. ',' .. d[7] .. ',' .. d[8] .. ',' .. d[9] end end end)()"
    rt18.execute('GRIP = 10 run(2)')
    std = rt18.eval(cnt % '45')
    rt18.execute('CHANGE.palette(2) run(0.3)')
    check('colourblind palette: the count white (%s, was %s)' % (rt18.eval(cnt % '45'), std), rt18.eval(cnt % '45').startswith('240,240,240'))
    rt18.execute('CHANGE.palette(1) CHANGE.opacity(50) run(0.3)')
    a50 = int(rt18.eval(cnt % '45').split(',')[3])
    check('opacity 50 %%: half the alpha (%d)' % a50, 115 <= a50 <= 125)
    # idle: nothing changed (and fire not pressed) for 4 s: dimmed to a quarter; a change brings it back at once
    rt18.execute('CHANGE.opacity(100) FIRE = false CHANGE.idle(2) run(3)')
    a3 = int(rt18.eval(cnt % '45').split(',')[3])
    rt18.execute('run(3)')
    af = int(rt18.eval(cnt % '45').split(',')[3])
    check('idle dimmed: shown at 3 s (%d), dimmed after 4 s (%d)' % (a3, af), a3 > 200 and 50 <= af <= 65)
    rt18.execute('OBJ[3].fields[ROLE.rounds] = 43 run(0.3)')
    check('idle: a shot brings it back (%s)' % rt18.eval(cnt % '44'), int(rt18.eval(cnt % '44').split(',')[3]) > 200)
    rt18.execute('run(6)')
    rt18.execute('FIRE = true run(0.1) FIRE = false run(0.1)')
    check('idle: pressing fire alone brings it back (%s)' % rt18.eval(cnt % '44'), int(rt18.eval(cnt % '44').split(',')[3]) > 200)
    rt18.execute('CHANGE.idle(3) CHANGE.idle_secs(2) run(3.5)')
    check('idle hidden, after 2 s: nothing drawn (%d)' % len(rt18.eval('draws')), len(rt18.eval('draws')) == 0)
    rt18.execute('OBJ[3].fields[ROLE.magazines] = 5 run(0.3)')
    check('idle hidden: a magazine change brings it back [%s]' % rt18.eval('texts()'), 'x5' in rt18.eval('texts()'))
    rt18.execute('CHANGE.idle(1) CHANGE.idle_secs(4) FIRE = true run(8)')
    check('idle shown: never dimmed (%s)' % rt18.eval(cnt % '44'), int(rt18.eval(cnt % '44').split(',')[3]) > 200)
    rt18.execute('OBJ[3].fields[ROLE.fire_mode] = 2 run(0.3) OBJ[3].fields[ROLE.fire_mode] = 1 run(0.3)')
    check('fire mode shown [%s]' % rt18.eval('texts()'), 'AUTO' in rt18.eval('texts()'))
    # modes in their own colours (the option): AUTO blue, SEMI cream; off: both cream
    rt18.execute('CHANGE.mode_colors(true) run(0.3)')
    auto = rt18.eval(cnt % 'AUTO')
    rt18.execute('OBJ[3].fields[ROLE.fire_mode] = 2 run(0.3)')
    semi = rt18.eval(cnt % 'SEMI')
    check('mode colours: AUTO %s, SEMI %s' % (auto, semi), auto and semi and auto.startswith('86,180,233') and semi.startswith('236,229,206'))
    rt18.execute('OBJ[3].fields[ROLE.fire_mode] = 1 run(0.3)')
    rt18.execute('CHANGE.mode_colors(false) run(0.3)')
    check('mode colours off: AUTO cream (%s)' % rt18.eval(cnt % 'AUTO'), rt18.eval(cnt % 'AUTO').startswith('236,229,206'))
    rt18.execute('CHANGE.show_fmode(false) run(0.3)')
    check('fire mode toggled off [%s]' % rt18.eval('texts()'), 'AUTO' not in rt18.eval('texts()') and '44' in rt18.eval('texts()'))
    rt18.execute('CHANGE.show_fmode(true)')
    # beside, 5 % up: the bar 72 px higher at 1440
    rt18.execute('CHANGE.position(2) run(0.3)')
    y0 = [d[3] for d in rt18.eval('draws').values() if d[1] == 'rect' and d[5] > d[4] * 5][0]
    rt18.execute('CHANGE.off_y(5) run(0.3)')
    y1 = [d[3] for d in rt18.eval('draws').values() if d[1] == 'rect' and d[5] > d[4] * 5][0]
    check('beside 5 %% up: 72 px higher (%s to %s)' % (y0, y1), y1 - y0 == 72)
    # fire on a keyboard key: shots with it are yours, the mouse doesn't count
    rt19 = lua51.LuaRuntime()
    setup(rt19)
    rt19.execute('''CHANGE.fire(6) FIRE = false BINDS.fire_key = true GRIP = 70 run(3)
      for i = 1, 4 do OBJ[4].fields[ROLE.rounds] = 12 - i run(0.5) end''')
    check('fire on a key: learned and shown [%s]' % rt19.eval('texts()'), rt19.eval('texts()').startswith('8 |')
          and not any('not yours' in l for l in rt19.eval('logs').values()))

    # Chef 1.1 (chef.text is the game font): its text, no GUI of our own
    rt3 = lua51.LuaRuntime()
    setup(rt3, chef11=True)
    rt3.execute('run(3)')
    check('Chef 1.1: chef.text used, no own GUI [%s]' % rt3.eval('texts()'),
          rt3.eval('GUIS') == 0 and rt3.eval('count("text", false)') > 0 and '45' in rt3.eval('texts()'))

    if '--png' in sys.argv:
        rt.execute('GRIP = 10 OBJ[3].fields[ROLE.carry] = 0 OBJ[3].fields[ROLE.rounds] = 26 run(2)')
        a = list(rt.eval('draws').values())
        rt.execute('GRIP = 52 OBJ[5].fields[ROLE.heat] = 63 OBJ[5].fields[ROLE.overheated] = false run(1)')
        b = list(rt.eval('draws').values())
        picture([[x[i] for i in range(1, 10)] for x in a], [[x[i] for i in range(1, 10)] for x in b], sys.argv[sys.argv.index('--png') + 1])
    print('%d failed' % len(fails))
    sys.exit(1 if fails else 0)


def picture(ammo, heat, path):
    """The two states drawn as the game would place them (bottom-left origin), cropped around the crosshair."""
    from PIL import Image, ImageDraw, ImageFont
    W, H = 3440, 1440
    img = Image.new('RGB', (W, H), (52, 44, 52))
    d = ImageDraw.Draw(img, 'RGBA')
    for i, draws in enumerate((ammo, heat)):
        dy = -260 if i == 0 else 0
        d.ellipse((W / 2 - 6, H / 2 - 6 + dy, W / 2 + 6, H / 2 + 6 + dy), outline=(230, 230, 230), width=2)
        for x in draws:
            kind = x[0]
            col = (int(x[5]), int(x[6]), int(x[7]), int(x[8]))
            if kind == 'sprite':
                continue
            if kind in ('rect', 'cell'):
                _, X, Y, w, h = x[:5]
                d.rectangle((X, H - Y - h + dy, X + w - 1, H - Y - 1 + dy), fill=col)
            else:
                _, X, Y, s, px = x[:5]
                font = ImageFont.load_default(size=int(px * 8))
                d.text((X, H - Y - 7 * px + dy), s, fill=col, font=font)
    img.crop((W / 2 - 520, H / 2 - 420, W / 2 + 520, H / 2 + 160)).convert('RGB').save(path)
    print('picture:', path)


if __name__ == '__main__':
    main()
