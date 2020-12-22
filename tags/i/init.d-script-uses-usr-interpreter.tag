Tag: init.d-script-uses-usr-interpreter
Severity: warning
Check: init-d
Explanation: The given <code>/etc/init.d</code> script specifies an interpreter in
 its shebang located under <code>/usr</code>.
 .
 It indicates that the init script may be using a non-essential
 interpreter. Since init scripts are configuration files, they may be
 left on the system after their package has been removed but not purged.
 At that point, the package dependencies are not guaranteed to exist and
 the interpreter may therefore not be available.
 .
 It's generally best to write init scripts using <code>/bin/sh</code> or
 <code>/bin/bash</code> where possible, since they are guaranteed to always be
 available.
