Tag: python3-script-but-no-python3-dep
Severity: error
Check: scripts
Explanation: Packages with Python3 scripts should depend on the package
 <code>python3</code>. Those with scripts that specify a specific version of
 Python3 must depend, recommend or suggest on that version of Python3
 (exactly).
 .
 For example, if a script in the package uses <code>#!/usr/bin/python3</code>,
 the package needs a dependency on <code>python3</code>. If a script uses
 <code>#!/usr/bin/python3.8</code>, the package needs a dependency on
 <code>python3.8</code>. A dependency on <code>python (>= 3.8)</code> is not
 correct, since later versions of Python may not provide the
 <code>/usr/bin/python3.8</code> binary.
 .
 If you are using debhelper, adding <code>${python3:Depends}</code> to the
 Depends field and ensuring dh&lowbar;python3 is run during the build should
 take care of adding the correct dependency.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
