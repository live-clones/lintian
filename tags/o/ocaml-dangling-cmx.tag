Tag: ocaml-dangling-cmx
Severity: error
Check: languages/ocaml/byte-code/compiled
Explanation: This OCaml package ships a <code>&ast;.cmx</code> byte code module
 without the associated implementation.
 .
 The implementation is shipped in a <code>&ast;.o</code> object file, which can be
 a member in a <code>&ast;.a</code> static library in the same directory.
