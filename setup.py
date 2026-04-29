from setuptools import setup

# cffi_modules has no PEP 621 equivalent; cffi's setuptools integration
# requires it to be passed to setup() imperatively.
setup(cffi_modules=["python/ffibuilder.py:ffibuilder"])
