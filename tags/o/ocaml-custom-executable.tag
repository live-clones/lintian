Tag: ocaml-custom-executable
Severity: warning
Check: languages/ocaml/custom-executable
Explanation: This OCaml package ships a byte code executable that was linked
 with a custom runtime.
 .
 Such executables cannot be stripped and require special care. Their usage is
 deprecated in favour of shared libraries for C stubs with names like
 <code>dll&ast;.so</code>.
