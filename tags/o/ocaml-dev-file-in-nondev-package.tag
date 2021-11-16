Tag: ocaml-dev-file-in-nondev-package
Severity: pedantic
Check: languages/ocaml/byte-code/misplaced/package
Explanation: This OCaml package ships development files such as <code>&ast;.cmi</code>,
 <code>&ast;.cmx</code> or <code>&ast;.cmxa</code> but does not appear to be a
 development package.
 .
 The files should be moved to a development package.
