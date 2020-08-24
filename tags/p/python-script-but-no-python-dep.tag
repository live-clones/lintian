Tag: python-script-but-no-python-dep
Severity: error
Check: scripts
Explanation: Packages with Python scripts should depend on the package
 <tt>python</tt>. Those with scripts that specify a specific version of
 Python must depend, recommend or suggest on that version of Python
 (exactly).
 .
 For example, if a script in the package uses <tt>#!/usr/bin/python</tt>,
 the package needs a dependency on <tt>python</tt>. If a script uses
 <tt>#!/usr/bin/python2.6</tt>, the package needs a dependency on
 <tt>python2.6</tt>. A dependency on <tt>python (>= 2.6)</tt> is not
 correct, since later versions of Python may not provide the
 <tt>/usr/bin/python2.6</tt> binary.
 .
 If you are using debhelper, adding <tt>${python3:Depends}</tt> or
 <tt>${python:Depends}</tt> to the Depends field and ensuring dh_python2 or
 dh_python3 are run during the build should take care of adding the correct
 dependency.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
