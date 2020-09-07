Tag: incorrect-naming-of-pkcs11-module
Severity: error
Check: files/p11-kit
Explanation: This package ships a PKCS#11 module configuration file under
 <code>/usr/share/p11-kit/modules</code>, but its naming doesn't conform
 to what <code>p11-kit</code> expects. Files in that directory should
 respect the following convention, case insensitive:
  [a-z0-9][a-z0-9&lowbar;.-]&ast;.module
 .
 p11-kit currently warns on every file that does not follow the
 convention and may ignore them in the future.
