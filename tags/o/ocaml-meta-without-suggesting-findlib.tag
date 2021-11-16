Tag: ocaml-meta-without-suggesting-findlib
Severity: pedantic
Check: languages/ocaml/meta
Explanation: This OCaml package installs a <code>META</code> file but does not
 declare <code> ocaml-findlib</code> as a prerequisite.
 .
 Ocaml libraries with a <code>META</code> file are easier to use with
 <code>findlib</code>. The package should, at a minimum, suggest
 <code>ocaml-findlib</code>.
