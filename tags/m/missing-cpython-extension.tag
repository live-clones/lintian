Tag: missing-cpython-extension
Severity: error
Check: languages/python/cpython
Explanation: This package builds CPython extensions, but does not build
 extensions for all the supported Python versions in the archive.
 .
 Please make sure to build-depend on <code>python3-all-dev</code> to build
 CPython extensions for all the supported Python versions.
