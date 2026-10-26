"""Token-level scope resolver for Lua 5.1 (enough for NarrowHUD's style): every Name token that refers to a chunk-level
local, with its position, and whether it's assigned."""
import re

KEYWORDS = set('and break do else elseif end false for function if in local nil not or repeat return then true until while'.split())

def tokenize(src):
    toks = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == '\n': line += 1; i += 1; continue
        if c.isspace(): i += 1; continue
        if src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:
                close = ']' + m.group(1) + ']'
                j = src.index(close, i) + len(close)
            else:
                j = src.find('\n', i)
                j = n if j < 0 else j
            line += src.count('\n', i, j); i = j; continue
        m = re.match(r'\[(=*)\[', src[i:])
        if m:
            close = ']' + m.group(1) + ']'
            j = src.index(close, i) + len(close)
            toks.append(('str', src[i:j], i, line)); line += src.count('\n', i, j); i = j; continue
        if c in '"\'':
            j = i + 1
            while src[j] != c:
                if src[j] == '\\': j += 1
                j += 1
            j += 1
            toks.append(('str', src[i:j], i, line)); i = j; continue
        m = re.match(r'0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?', src[i:])
        if m and (c.isdigit() or (c == '.' and i + 1 < n and src[i + 1].isdigit())):
            toks.append(('num', m.group(0), i, line)); i += len(m.group(0)); continue
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i:])
        if m:
            w = m.group(0)
            toks.append(('kw' if w in KEYWORDS else 'name', w, i, line)); i += len(w); continue
        for op in ('...', '..', '==', '~=', '<=', '>='):
            if src.startswith(op, i):
                toks.append(('op', op, i, line)); i += len(op); break
        else:
            toks.append(('op', c, i, line)); i += 1
    return toks

class Decl:
    def __init__(s, name, pos, line, top):
        s.name, s.pos, s.line, s.top, s.refs = name, pos, line, top, []
    def __repr__(s): return 'Decl(%s@%d)' % (s.name, s.line)

FREE = []
def resolve(src):
    del FREE[:]
    toks = tokenize(src)
    top = {}
    tops = []
    scopes = [top]          # each a dict name -> Decl
    kinds = ['chunk']       # what opened each scope
    brackets = []           # open ( [ { with the scope depth
    pending = None          # names to declare at the next 'do' (for loops)
    i = 0
    def declare(t, scope=None):
        sc = scope if scope is not None else scopes[-1]
        d = Decl(t[1], t[2], t[3], sc is top)
        sc[t[1]] = d
        if sc is top: tops.append(d)
        return d
    def lookup(name):
        for sc in reversed(scopes):
            if name in sc: return sc[name]
        return None
    while i < len(toks):
        kind, v, pos, line = toks[i]
        prev = toks[i - 1] if i else None
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        if kind == 'kw':
            if v == 'local':
                if nxt[1] == 'function':
                    declare(toks[i + 2])
                    i += 2  # 'function' handled next round (name skipped below)
                    # open function scope at 'function'
                    # params
                    j = i + 1
                    assert toks[j][1] == '(', toks[j]
                    scopes.append({}); kinds.append('function')
                    j += 1
                    while toks[j][1] != ')':
                        if toks[j][0] == 'name': declare(toks[j])
                        j += 1
                    i = j + 1; continue
                # local a, b, c [= ...]: names visible from here (see the caveat)
                j = i + 1
                names = []
                while True:
                    names.append(toks[j]); j += 1
                    if toks[j][1] == ',': j += 1; continue
                    break
                for t in names: declare(t)
                i = j; continue
            if v == 'function':
                # function [name.a.b[:m]] (params)
                j = i + 1
                is_method = False
                while toks[j][1] != '(':
                    t = toks[j]
                    if t[0] == 'name' and (toks[j - 1][1] not in ('.', ':')):
                        d = lookup(t[1])
                        if d and d.top: d.refs.append((t[2], t[3], toks[j + 1][1] == '('))  # write when function x()
                    if t[1] == ':': is_method = True
                    j += 1
                scopes.append({}); kinds.append('function')
                if is_method: scopes[-1]['self'] = Decl('self', 0, 0, False)
                j += 1
                while toks[j][1] != ')':
                    if toks[j][0] == 'name': declare(toks[j])
                    j += 1
                i = j + 1; continue
            if v == 'for':
                j = i + 1
                pend = []
                while toks[j][1] not in ('=', 'in'):
                    if toks[j][0] == 'name': pend.append(toks[j])
                    j += 1
                pending = pend
                i = j; continue
            if v in ('do',):
                scopes.append({}); kinds.append('do')
                if pending:
                    for t in pending: declare(t)
                    pending = None
            elif v == 'then':
                scopes.append({}); kinds.append('then')
            elif v in ('elseif', 'else'):
                scopes.pop(); kinds.pop()
                if v == 'else': scopes.append({}); kinds.append('then')
            elif v == 'repeat':
                scopes.append({}); kinds.append('repeat')
            elif v == 'until':
                scopes.pop(); kinds.pop()
            elif v == 'end':
                scopes.pop(); kinds.pop()
            i += 1; continue
        if kind == 'op':
            if v in '([{': brackets.append(v)
            elif v in ')]}': brackets.pop()
            i += 1; continue
        if kind == 'name':
            if prev and prev[1] in ('.', ':') and prev[0] == 'op':
                i += 1; continue
            if brackets and brackets[-1] == '{' and nxt and nxt[1] == '=' and prev and prev[1] in ('{', ',', ';'):
                i += 1; continue   # a table key
            d = lookup(v)
            if d is None: FREE.append((v, line))
            if d is not None and d.top:
                write = nxt is not None and nxt[1] == '=' and not (brackets and brackets[-1] in '({[')
                if not write and nxt is not None and nxt[1] == ',' and not (brackets and brackets[-1] in '({['):
                    # a, b.c, d[e] = ...: a target of a multiple assignment
                    j = i + 1
                    toks = toks + [('eof', '', 0, 0)] * 4 if toks[-1][0] != 'eof' else toks
                    while j < len(toks) and toks[j][1] == ',':
                        j += 1
                        if toks[j][0] != 'name': break
                        j += 1
                        while toks[j][1] in ('.', '['):
                            if toks[j][1] == '.': j += 2
                            else:
                                depth = 0
                                while True:
                                    if toks[j][1] == '[': depth += 1
                                    elif toks[j][1] == ']':
                                        depth -= 1
                                        if depth == 0: break
                                    j += 1
                                j += 1
                    write = toks[j][1] == '='
                d.refs.append((pos, line, write))
            i += 1; continue
        i += 1
    assert len(scopes) == 1, (len(scopes), kinds)
    return tops
