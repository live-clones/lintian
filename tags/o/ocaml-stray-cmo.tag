Tag: ocaml-stray-cmo
Severity: info
Check: languages/ocaml/byte-code/library
Explanation: This OCaml package installs a <code>&ast;.cma</code> byte code
 library together with a separate <code>&ast;.cmo</code> byte code file, with
 both having the same base name.
 .
 The module provided by the <code>&ast;.cmo</code> file is usually an archive
 member in the <code>&ast;.cma</code> library, so there is no need for the
 <code>&ast;.cmo</code> file.
