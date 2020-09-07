Tag: invalid-field-for-derivative
Severity: error
Check: fields/derivatives
Explanation: The specified field in <code>debian/control</code> does not match the
 required format for this Debian derivative.
 .
 Derivative distributions of Debian may enforce additional restrictions
 on such fields for many reasons including ensuring that:
 .
   - Debian maintainers are not contacted for forked or packages that
     are otherwise modified by the derivative.
   - The original maintainer is still credited for their work (eg. in a
     <code>XSBC-Original-Maintainer</code> fied.
   - References to revision control systems (eg. <code>Vcs-Git</code>) are
     pointing to the correct, updated location.
   - Fields that become misleading in the context of a derivative are
     removed.
