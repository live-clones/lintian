Tag: uses-poetry-cli
Severity: info
Check: languages/python
Explanation: The source declares <code>python3-poetry</code> as a build prerequisite,
 but that is a command-line interface (CLI) tool.
 .
 Should <code>poetry</code> be required to build these sources, please declare the
 prerequisite <code>python3-poetry-core</code> instead.
