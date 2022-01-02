Tag: pyproject-toml-but-not-pybuild-pyproject-poetry
Severity: info
Check: languages/python
Explanation: pybuild now supports building using PEP-517 standard
 interfaces natively. As such, this package could be built using pybuild's
 generic pyproject plugin and the poetry build backend.
 .
 Please build-depend on <code>pybuild-plugin-pyproject</code> as well as
 <code>python3-poetry-core</code> to use this pybuild feature.
