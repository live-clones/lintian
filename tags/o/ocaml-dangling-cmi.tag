Tag: ocaml-dangling-cmi
Severity: info
Check: languages/ocaml/byte-code/interface
Explanation: This OCaml package ships a byte code interface file <code>&ast;.cmi</code>
 without the text version in a <code>&ast;.mli</code> file.
 .
 The text version should be shipped for documentation. If the module does not have
 a <code>&ast;.mli</code> file, the source code in a <code>&ast;.ml</code> file
 should be shipped instead.
