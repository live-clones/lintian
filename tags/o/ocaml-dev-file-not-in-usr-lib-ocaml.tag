Tag: ocaml-dev-file-not-in-usr-lib-ocaml
Severity: pedantic
Check: languages/ocaml/byte-code/misplaced/path
Explanation: This OCaml package ships development files like <code>&ast;.cmi</code>,
 <code>&ast;.cmx</code> or <code>&ast;.cmxa</code> outside of the standard folder
 <code>/usr/lib/ocaml</code>.
 .
 Those files are used only for compilation and should be placed in a  subfolder of
 the standard OCaml library path.
