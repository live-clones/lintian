Tag: script-not-executable
Severity: warning
Check: scripts
Explanation: This file starts with the #! sequence that marks interpreted scripts,
 but it is not executable.
 .
 There has been some discussion to allow such files in paths other than
 <code>/usr/bin</code> but there was ultimately no broad support for it.
See-Also: Bug#368792
