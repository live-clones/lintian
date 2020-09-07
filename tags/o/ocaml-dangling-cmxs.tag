Tag: ocaml-dangling-cmxs
Severity: warning
Check: languages/ocaml
Explanation: This package seems to be a library package, and provides a native
 plugin (<code>.cmxs</code>). If the plugin is meant to be used as a library
 for other plugins, it should be shipped as bytecode (<code>.cma</code> or
 <code>.cmo</code>) as well.
