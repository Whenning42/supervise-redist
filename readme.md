A python wheel for catern's [supervise](https://github.com/catern/supervise/tree/master)
that includes the C binary along with the python API.

## Build prerequisites

System tools:
- `uv` (https://docs.astral.sh/uv/) — environment management for build/test tooling
- `zig` — used as a glibc-2.17-targeted cross-compiler for the supervise binary
- `autoreconf` (autoconf + automake) — to bootstrap the C build
- `just` — runs the recipes in `justfile`

All Python tooling (`build`, `auditwheel`, `twine`) is declared in this repo's
top-level `pyproject.toml` under the `dev` dependency group and is pulled in
on demand by `uv run --only-group dev`.

## Build/test commands

Run `justfile --list` or read the `justfile` for recipes and entrypoints.
