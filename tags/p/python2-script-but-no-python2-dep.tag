Tag: python2-script-but-no-python2-dep
Severity: error
Check: scripts
Explanation: Packages with Python2 scripts should depend on the package
 <code>python2</code>. Those with scripts that specify a specific version of
 Python2 must depend, recommend or suggest on that version of Python2
 (exactly).
 .
 For example, if a script in the package uses <code>#!/usr/bin/python2</code>,
 the package needs a dependency on <code>python2</code>. If a script uses
 <code>#!/usr/bin/python2.7</code>, the package needs a dependency on
 <code>python2.7</code>. A dependency on <code>python (>= 2.7)</code> is not
 correct, since later versions of Python2 may not provide the
 <code>/usr/bin/python2.7</code> binary.
 .
 If you are using debhelper, adding <code>${python2:Depends}</code> to the
 Depends field and ensuring dh&lowbar;python2 is run during the build should
 take care of adding the correct dependency.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
