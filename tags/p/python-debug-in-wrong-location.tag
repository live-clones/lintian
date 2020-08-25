Tag: python-debug-in-wrong-location
Severity: warning
Check: languages/python
See-Also: Bug#576014
Explanation: The package appears to be installing debug modules in
 /usr/lib/debug/usr/lib/pyshared/pythonX.Y/. However, gdb(1)
 will not look for it there, making it less useful. The file
 should be installed in /usr/lib/debug/usr/lib/pymodules/pythonX.Y/
 instead.
