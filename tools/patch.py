"""Safe text patching for loop iterations: every replacement must apply exactly once.
Usage in heredocs:  from tools.patch import sub; sub(path, old, new)"""
import sys

def sub(path, old, new, count=1):
    s = open(path).read()
    n = s.count(old)
    if n != count:
        sys.exit(f"PATCH FAILED in {path}: expected {count} match(es), found {n}:\n{old[:200]}")
    open(path, 'w').write(s.replace(old, new))
