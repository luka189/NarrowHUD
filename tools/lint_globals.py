"""Every name a module uses that isn't its own local, imported from N, or one of Lua's and the head's (chef, M, log,
DATA, SEED, N): a typo or a missing import shows up here, not in the game.

    python3 tools/lint_globals.py      (run by tests/run_tests.py too)
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import lua_scope

ROOT = Path(__file__).resolve().parent.parent
OK = set('N chef M log ENGINE_GS DATA SEED BALLISTICS TEXTURES math string table pairs ipairs tostring tonumber type pcall setmetatable getmetatable '
         'next select unpack error rawget rawset os print _G xpcall assert loadstring setfenv collectgarbage'.split())


def main():
    bad = []
    for f in sorted((ROOT / 'src' / 'modules').glob('*.lua')):
        lua_scope.resolve(f.read_text(encoding='utf-8'))
        for name, line in lua_scope.FREE:
            if name not in OK:
                bad.append(f'{f.name}:{line}: {name}')
    for b in bad:
        print(b)
    return len(bad)


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
