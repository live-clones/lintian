Tag: ocaml-meta-without-suggesting-findlib
Severity: pedantic
Check: languages/ocaml
Explanation: This development package installs a META file but doesn't depend on
 ocaml-findlib. Libraries with META file are easier to use with findlib.
 The package should at least suggest ocaml-findlib.
