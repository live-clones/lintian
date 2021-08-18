Tag: python-traceback-in-manpage
Severity: error
Check: documentation/manual
Explanation: The specified manual page contains a Python traceback.
 .
 This was probably caused by a call to <code>help2man</code> failing to
 correctly execute, likely due to an  missing or incorrect
 <code>PYTHONPATH</code> environment variable.
 .
 Note that calls to generate manpages from binaries may succeed if the package
 being built is already installed in the build environment as might locate
 potentially old copy of the program under <code>/usr/lib/python3</code>. This
 is fairly common on maintainers' machines, for example. However, in
 environments where the package is not installed (such as most buildds),
 generating the manpage may fail and inject a traceback into the manual page.
