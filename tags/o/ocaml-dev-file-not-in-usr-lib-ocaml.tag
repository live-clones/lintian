Tag: ocaml-dev-file-not-in-usr-lib-ocaml
Severity: pedantic
Check: languages/ocaml
Explanation: This development package installs OCaml development files
 (<code>.cmi</code>, <code>.cmx</code> or <code>.cmxa</code>) outside
 <code>/usr/lib/ocaml</code>. Such files are used only by compilation and
 should be in a subdirectory of OCaml standard library path.
