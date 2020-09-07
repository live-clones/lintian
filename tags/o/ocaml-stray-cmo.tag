Tag: ocaml-stray-cmo
Severity: info
Check: languages/ocaml
Explanation: This package installs a <code>.cma</code> file and a <code>.cmo</code> file
 with the same base name. Most of the time, the module provided by the
 <code>.cmo</code> file is also linked in the <code>.cma</code> file, so the
 <code>.cmo</code> file is useless.
