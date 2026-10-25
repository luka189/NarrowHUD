"""Offline tests for NarrowHUD: build/narrowhud.lua run in Lua 5.1 (lupa) with a stand-in `chef` and a small fake
game (your player, Helldiver and weapons as network objects, a hand pose). Not a substitute for the game.

    python3 tools/build.py && python3 tests/run_tests.py [--png out.png]
"""
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
    g.NAMES = rt.table_from({'stalwart': type_name('521229d8'), 'crem': type_name('15f1a9f0'), 'crempack': type_name('6c17c3b1'), 'pack2': type_name('447380d4'), 'verdict': type_name('c7dfd9eb'), 'seaf': type_name('aca39ec2'), 'dog': type_name('530e19df'), 'arc': arc, 'commando': type_name('3d538455'), 'spear': type_name('83d1036e'), 'rail': type_name('26acc614'), 'rr': type_name('b2bfd847'), 'ac': type_name('7bfb2e06'), 'acfed': type_name('903649ec'), 'acpack': type_name('94ff3b20'), 'scythe': type_name('42a6b5ba'), 'c4': type_name('6b2c3bed'), 'c4pack': type_name('66d03a73'), 'laser': type_name('d100e0c8'), 'warrant': type_name('c920c2d3'), 'unk2': unk2, 'ub2': ub2[1], 'ub2id': ub2[0], 'fed': type_name('b3246bb7'), 'pack': 'raqnyi', 'ubgl': type_name('da0f356e'), 'player': type_name('803159b3') if False else 'un6y1d', 'avatar': 'vvhx8ga',
                             'arb': type_name('8fcdd35c'), 'nova': type_name('17783758'), 'de': type_name('960653cb'), 'unk': unknown_name})
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
function press(k) if k == 'wheel' then WHEEL = 1 else KEYS[k] = true end run(1 / 60) OPTS, CHANGE = { research = true }, {}   -- the F9 menu's values (the tests run with the research log on)
PAD, PADY, BLOCKED = false, false, false   -- fire on a controller; its Y pressed; Chef 1.1 refusing the reads
KEYS, WHEEL = {}, 0 run(0.3) end
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
  load_table = function() return saved end, save_table = function(n, t) saved = t end,
  watch = function() return { items = { { unit = 'U', x = 0, y = 0, z = 0 } } } end,
  camera = function() return { x = 0, y = 0, z = 1 } end,
  unit_alive = function() return true end,
  unit_position = function() return 100, 200, 10 end,
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
      if v == nil and b == ROLE.held then return true end   -- (the player's own weapons: trigger held unless a test says)
      return v
    end
    if name == 'Unit.has_animation_state_machine' or name == 'Unit.animation_has_variable' then return true end
    if name == 'Unit.animation_find_variable' then return 3 end
    if name == 'Unit.animation_get_variable' then return GRIP end
    if name == 'Application.can_get' then return GAME_FONT end
    if name == 'Network.object_info' and OBJINFO then return OBJINFO(s) end
    if name == 'Mouse.button_index' then return 0 end
    if name == 'Mouse.button' then return (FIRE and not PAD) and 1 or 0 end
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
      if pf == 'button_index' then return (pn == 1 and not PS) and (s == 'y' and 3 or 5) or nil end
      if pf == 'button' then return (s == 5 and FIRE and PAD and not NOPAD and mine) and 1 or 0 end
      if pf == 'pressed' then return s == 3 and mine and PADY == true end
    end
    if name == 'GameSession.objects_owned_by' and BLOCKED then return nil, 'refused' end
    if name == 'GameSession.game_object_is_type' and BLOCKED then return nil, 'refused' end
    if name == 'World.create_screen_gui' then GUIS = GUIS + 1 return 'G' end
    if name == 'Vector3' then return { s, a, b } end
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

    check('Keep-On-Crash header within the first 400 characters', '\n-- HD2-Keep-On-Crash: yes' in SRC[:400])
    rt.execute('run(3)')
    t = rt.eval('texts()')
    check('Arbitrator in hand (pose 10): 45 shown (44 + chamber) with x7 [%s]' % t, '45' in t and 'x7' in t)
    check('drawn in the game font', rt.eval('count("text", true)') > 0 and rt.eval('count("text", false)') == 0)
    check('one GUI made for the world', rt.eval('GUIS') == 1)
    check('grenade and stim icons with counts 4 and 5', rt.eval('count("sprite")') == 2 and '4' in t and '5' in t)
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
    rt.execute('OBJ[4].fields[ROLE.rounds] = 11 GRIP = 40 run(0.5)')
    check('stratagem in hand (pose 40): only the grenade/stim line [%s]' % rt.eval('texts()'),
          rt.eval('count("rect")') == 0 and rt.eval('count("sprite")') == 2)

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
    rt.execute('GRIP = 42 run(0.5)')
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
    rt.execute('OBJ[22].fields[ROLE.held] = false run(0.2)')
    check('released: no meter', rt.eval("(function() for _, d in ipairs(draws) do if d[1] == 'rect' and d[9] == 230 then return true end end return false end)()") is False)
    rt.execute('OBJ[22] = nil GRIP = 10 run(1.5)')

    # research: every field of the weapon in hand watched, a change logged (the Warrant's options here)
    rt.execute('''OBJ[23] = { name = NAMES.warrant, fields = {} } OBJ[23].fields[ROLE.rounds] = 5 OBJ[23].fields[ROLE.chamber] = true
      OBJ[23].fields[ROLE.magazines] = 3 OBJ[23].fields[ROLE.carry] = 0 OBJ[23].fields[ROLE.options] = 80 GRIP = 1 run(3)
      OBJ[23].fields.zzz = nil OBJ[23].fields[ROLE.options] = 84 run(0.5)''')
    check('research: known fields (options) not in the full-field log', not any(l.startswith('research c920c2d3: 31f86165') for l in rt.eval('logs').values()))
    rt.execute('OBJ[23].fields.ewxe2e = 1 GRIP = 1 run(0.5) OBJ[23].fields.ewxe2e = 2 run(0.5)')
    check('research: another field\'s change logged by its id %s' % [l for l in rt.eval('logs').values() if l.startswith('research c920')],
          any(l.startswith('research c920c2d3: ') and '1>2' in l for l in rt.eval('logs').values()))
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
    check('a charge meter about half way after 0.5 of 1 s (%s)' % meter, meter and 100 <= meter <= 160)
    rt.execute('OBJ[26] = nil GRIP = 10 run(1.5)')

    # the Commando's laser guidance
    rt.execute('''OBJ[27] = { name = NAMES.commando, fields = {} } OBJ[27].fields[ROLE.rounds] = 4 OBJ[27].fields[ROLE.magazines] = 0
      OBJ[27].fields[ROLE.chamber] = true OBJ[27].fields[ROLE.carry] = 0 OBJ[27].fields[ROLE.guide] = true GRIP = 20 run(3)
      OBJ[27].fields[ROLE.rounds] = 3 run(0.5)''')
    check('Commando: LASER [%s]' % rt.eval('texts()'), 'LASER' in rt.eval('texts()') and 'NO LASER' not in rt.eval('texts()'))
    rt.execute('OBJ[27].fields[ROLE.guide] = false run(0.3)')
    check('Commando: NO LASER [%s]' % rt.eval('texts()'), 'NO LASER' in rt.eval('texts()'))
    rt.execute('OBJ[27] = nil GRIP = 10 run(1.5)')

    # research: another carried thing (a jump pack ...) on you: its fields watched too
    rt.execute('''OBJ[28] = { name = "do356cc", fields = { of_bfv = 4 } } OBJ[28].fields[ROLE.carry] = 0 run(4)
      OBJ[28].fields.of_bfv = 3 run(0.5)''')
    check('research: a carried thing\'s field change logged', any(l.startswith('research 016ad05b: 50ac6619 4>3') for l in rt.eval('logs').values()))
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
      GRIP = 30 run(3) OBJ[61].fields[ROLE.rounds] = 9 run(0.5) OBJ[62].fields[ROLE.rounds] = 19 run(0.5)''')
    check('shield: the last fired shown [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('19 | x2'))
    rt.execute("press('1')")
    check('shield, key 1 (not learned): the other one out [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('9 | x6'))
    rt.execute("PADY = true run(1 / 60) PADY = false run(0.3)")
    check('shield, a controller\'s Y: the other one [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('19 | x2'))
    rt.execute("press('wheel')")
    check('shield, the wheel: the other one again [%s]' % rt.eval('texts()'), rt.eval('texts()').startswith('9 | x6'))
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
    rt.execute('GRIP = 41 run(0.5)')
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
    rt18.execute('CHANGE.opacity(100) CHANGE.fade(true) run(6)')
    af = int(rt18.eval(cnt % '45').split(',')[3])
    check('fade: full, not fired for 4 s: faded (%d)' % af, af < 80)
    rt18.execute('OBJ[3].fields[ROLE.rounds] = 43 run(0.3)')
    check('fade: a shot brings it back (%s)' % rt18.eval(cnt % '44'), int(rt18.eval(cnt % '44').split(',')[3]) > 200)
    rt18.execute('CHANGE.fade(false) OBJ[3].fields[ROLE.fire_mode] = 2 run(0.3) OBJ[3].fields[ROLE.fire_mode] = 1 run(0.3)')
    check('fire mode shown [%s]' % rt18.eval('texts()'), 'AUTO' in rt18.eval('texts()'))
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
