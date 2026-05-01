glibc := "2.17"
target := "x86_64-linux-gnu." + glibc
python_versions := "3.11 3.12 3.13 3.14"
python_tags := "cp311 cp312 cp313 cp314"
stage := justfile_directory() / "python/build/c-stage"
objs := justfile_directory() / "python/build/c-objs"

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

# Build the wheel for a Python version and retag it as manylinux2014_x86_64.
wheel py="3.13": build_supervise
    if [ -d python/build/wheel-{{py}} ]; then trash python/build/wheel-{{py}}; fi
    if [ -d python/dist/cp{{replace(py, ".", "")}} ]; then trash python/dist/cp{{replace(py, ".", "")}}; fi
    mkdir -p python/build/wheel-{{py}} python/dist/cp{{replace(py, ".", "")}}
    PKG_CONFIG_PATH={{stage}}/lib/pkgconfig \
        CC="zig cc -target {{target}}" \
        LDSHARED="zig cc -target {{target}} -shared" \
        uv run --managed-python --python {{py}} --only-group dev python -m build --wheel --outdir python/build/wheel-{{py}} .
    uv run --managed-python --python {{py}} --only-group dev auditwheel repair --plat manylinux2014_x86_64 -w python/dist/cp{{replace(py, ".", "")}} python/build/wheel-{{py}}/*-linux_x86_64.whl

# Install the built wheel into a temp venv and run the tests.
test_wheel py="3.13": (wheel py)
    if [ -d python/build/test-venv-{{py}} ]; then trash python/build/test-venv-{{py}}; fi
    uv venv --managed-python --python {{py}} python/build/test-venv-{{py}}
    uv pip install --python python/build/test-venv-{{py}}/bin/python \
        python/dist/cp{{replace(py, ".", "")}}/*.whl
    python/build/test-venv-{{py}}/bin/python -m unittest supervise_api.tests.test_supervise -v

# Build and test wheels for all supported Python versions.
test_wheels:
    for py in {{python_versions}}; do just test_wheel "$py"; done

# Verify the binary's glibc symbol versions stay <= 2.17.
check_deps: build_supervise
    ./scripts/check_deps.py --max-glibc {{glibc}} {{stage}}/bin/supervise {{stage}}/bin/unlinkwait

# Upload package to PyPI
upload_package py="3.13": (test_wheel py)
    uv run --only-group dev twine upload python/dist/cp{{replace(py, ".", "")}}/*.whl --skip-existing

# Build, test, and upload all supported package versions.
upload_packages: test_wheels
    for tag in {{python_tags}}; do uv run --only-group dev twine upload "python/dist/$tag"/*.whl --skip-existing; done
