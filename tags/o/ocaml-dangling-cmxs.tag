Tag: ocaml-dangling-cmxs
Severity: warning
Check: languages/ocaml/byte-code/plugin
Explanation: This OCaml package provides a native plugin with a name like
 <code>*.cmxs</code> but does not ship the associated byte code.
 .
 If the plugin is meant to be used inside other plugins, the package should also
 ship the byte code in a similarly-named file, such as <code>&ast;cma</code> or
 <code>&ast;.cmo</code>.
