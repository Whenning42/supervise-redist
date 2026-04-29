glibc := "2.17"
target := "x86_64-linux-gnu." + glibc
stage := justfile_directory() / "python/build/c-stage"
objs := justfile_directory() / "python/build/c-objs"
test_venv := justfile_directory() / "python/build/test-venv"

# Build the supervise binary, staged for the wheel.
build_supervise:
    cd c && autoreconf -i
    mkdir -p {{objs}}
    cd {{objs}} && CC="zig cc -target {{target}}" \
        {{justfile_directory()}}/c/configure \
        --prefix={{stage}} \
        --host=x86_64-linux-gnu \
        --disable-shared --with-pic
    make -C {{objs}} -j
    make -C {{objs}} install
    mkdir -p python/supervise_api/_bin
    cp {{stage}}/bin/supervise python/supervise_api/_bin/supervise
    chmod 755 python/supervise_api/_bin/supervise

# Build the wheel and retag it as manylinux2014_x86_64.
wheel: build_supervise
    if [ -d python/dist ]; then trash python/dist; fi
    PKG_CONFIG_PATH={{stage}}/lib/pkgconfig \
        CC="zig cc -target {{target}}" \
        LDSHARED="zig cc -target {{target}} -shared" \
        uv run --only-group dev python -m build --wheel --outdir python/dist .
    uv run --only-group dev auditwheel repair --plat manylinux2014_x86_64 -w python/dist python/dist/*-linux_x86_64.whl
    trash python/dist/*-linux_x86_64.whl

# Install the built wheel into a temp venv and run the tests.
test_wheel: wheel
    if [ -d {{test_venv}} ]; then trash {{test_venv}}; fi
    uv venv {{test_venv}}
    uv pip install --python {{test_venv}}/bin/python \
        --find-links ../sfork/python/dist \
        python/dist/*.whl
    {{test_venv}}/bin/python -m unittest supervise_api.tests.test_supervise -v

# Verify the binary's glibc symbol versions stay <= 2.17.
check_deps: build_supervise
    ./scripts/check_deps.py --max-glibc {{glibc}} {{stage}}/bin/supervise {{stage}}/bin/unlinkwait

# Upload package to PyPI
upload_package: test_wheel
    uv run --only-group dev twine upload python/dist/*.whl
