Tag: ocaml-dangling-cmi
Severity: info
Check: languages/ocaml
Explanation: This package installs a compiled interface (<code>.cmi</code>) without
 its text version (<code>.mli</code>). The text version should also be
 installed for documentation purpose. If the module involved doesn't have
 a <code>.mli</code>, its source code (<code>.ml</code>) should be installed
 instead.
