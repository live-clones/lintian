Tag: pyproject-toml-but-not-pybuild-pyproject-flit
Severity: info
Check: languages/python
Explanation: pybuild now supports building using PEP-517 standard
 interfaces natively. As such, this package could be built using pybuild's
 generic pyproject plugin and the flit build backend.
 .
 Please build-depend on <code>pybuild-plugin-pyproject</code> as well as
 <code>python3-flit</code> to use this pybuild feature.
 .
 Note that no changes are currently required if you are already using pybuild's
 dedicated flit plugin. Also note this plugin will eventually be deprecated in
 favor of the generic pyproject one.
