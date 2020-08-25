Tag: python-script-but-no-python-dep
Severity: error
Check: scripts
Explanation: Packages with Python scripts should depend on the package
 <code>python</code>. Those with scripts that specify a specific version of
 Python must depend, recommend or suggest on that version of Python
 (exactly).
 .
 For example, if a script in the package uses <code>#!/usr/bin/python</code>,
 the package needs a dependency on <code>python</code>. If a script uses
 <code>#!/usr/bin/python2.6</code>, the package needs a dependency on
 <code>python2.6</code>. A dependency on <code>python (>= 2.6)</code> is not
 correct, since later versions of Python may not provide the
 <code>/usr/bin/python2.6</code> binary.
 .
 If you are using debhelper, adding <code>${python3:Depends}</code> or
 <code>${python:Depends}</code> to the Depends field and ensuring dh_python2 or
 dh_python3 are run during the build should take care of adding the correct
 dependency.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
