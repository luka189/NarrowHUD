"""Copy the built-in layouts (src/modules/10_custom.lua: DEFAULT_LAYOUT, VERTICAL_LAYOUT, ARCS_LAYOUT, HORIZONTAL_LAYOUT, BLOCK_LAYOUT) into the editor's
UNDER and PRESETS tables (editor/editor.html), so the editor's presets are the mod's, field for field.

    python3 tools/sync_presets.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = (ROOT / 'src' / 'modules' / '10_custom.lua').read_text(encoding='utf-8')
ED = ROOT / 'editor' / 'editor.html'
JS = ED.read_text(encoding='utf-8')

NAMES = { 'DEFAULT_LAYOUT': 'UNDER', 'VERTICAL_LAYOUT': 'Vertical pair', 'ARCS_LAYOUT': 'Arcs', 'HORIZONTAL_LAYOUT': 'Horizontal',
  'BLOCK_LAYOUT': 'Block' }


def lua_table(name):
    m = re.search(r'local %s = \{ _v = LAYOUT_VERSION, elements = \{\n(.*?)\} \} \}' % name, LUA, re.S)
    if not m:
        raise SystemExit('no ' + name)
    body = m.group(1) + '}'   # (the last element's closing brace: the match's end took it)
    body = re.sub(r'--[^\n]*', '', body)
    out = []
    for em in re.finditer(r'(\w+) = \{ ([^}]*) \}', body):
        fields = em.group(2).strip()
        fields = re.sub(r"(\w+) = '([^']*)'", r"\1: '\2'", fields)
        fields = re.sub(r'(\w+) = ', r'\1: ', fields)
        out.append('  %s: { %s },' % (em.group(1), fields))
    return '\n'.join(out)


for lua_name, js_name in NAMES.items():
    table = lua_table(lua_name)
    if js_name == 'UNDER':
        pat = re.compile(r'(const UNDER = \{ _v: 1, elements: \{\n)(.*?)( \} \};)', re.S)
    else:
        pat = re.compile(r"(\{ name: '%s', note: '(?:[^'\\]|\\.)*', t: \{ _v: 1, elements: \{\n)(.*?)( \} \} \},)" % re.escape(js_name), re.S)
    m = pat.search(JS)
    if not m:
        raise SystemExit('no ' + js_name + ' in the editor')
    new_body = table.rstrip(',')
    JS = JS[:m.start(2)] + new_body + JS[m.end(2):]

ED.write_text(JS, encoding='utf-8')
print('presets synced')
