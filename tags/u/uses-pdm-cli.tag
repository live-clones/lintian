Tag: uses-pdm-cli
Severity: info
Check: languages/python
Explanation: The source declares <code>python3-pdm</code> as a build prerequisite,
 but that is a command-line interface (CLI) tool.
 .
 Should <code>pdm</code> be required to build these sources, please declare the
 prerequisite <code>python3-pdm-pep517</code> instead.
