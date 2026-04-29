#!/usr/bin/env python3
"""Verify a binary's required GLIBC symbol versions don't exceed a max.

Usage: check_deps.py [--max-glibc 2.17] BINARY [BINARY ...]
"""
import argparse
import re
import subprocess
import sys
from typing import Iterable


def parse_version(s: str) -> tuple:
    return tuple(int(x) for x in s.split("."))


def fmt(v: tuple) -> str:
    return ".".join(str(x) for x in v)


def required_glibc_versions(binary: str) -> set:
    out = subprocess.check_output(["objdump", "-T", binary], text=True)
    versions = set()
    for line in out.splitlines():
        m = re.search(r"GLIBC_(\d+(?:\.\d+)+)", line)
        if m:
            versions.add(parse_version(m.group(1)))
    return versions


def shared_lib_deps(binary: str) -> Iterable[str]:
    out = subprocess.check_output(["ldd", binary], text=True)
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("statically linked"):
            continue
        yield line


def check(binary: str, limit: tuple) -> bool:
    versions = required_glibc_versions(binary)
    bad = sorted(v for v in versions if v > limit)
    max_used = max(versions, default=(0,))
    if bad:
        print(f"FAIL {binary}: requires {', '.join('GLIBC_' + fmt(v) for v in bad)} (limit {fmt(limit)})")
        return False
    print(f"OK   {binary}: max GLIBC_{fmt(max_used)} <= {fmt(limit)}")
    for line in shared_lib_deps(binary):
        print(f"     {line}")
    return True


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--max-glibc", default="2.17")
    p.add_argument("binaries", nargs="+")
    args = p.parse_args()
    limit = parse_version(args.max_glibc)
    ok = all(check(b, limit) for b in args.binaries)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
