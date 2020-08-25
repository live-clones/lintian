Tag: preinst-interpreter-without-predepends
Severity: error
Check: scripts
Explanation: The package contains a <code>preinst</code> maintainer script that uses
 an unusual and non-essential interpreter but does not declare a
 pre-dependency on the package that provides this interpreter.
 .
 <code>preinst</code> scripts should be written using only essential
 interpreters to avoid additional dependency complexity. Please do not
 add a pre-dependency without following the policy for doing so (Policy
 section 3.5).
See-Also: policy 7.2
