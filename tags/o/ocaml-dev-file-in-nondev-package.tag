Tag: ocaml-dev-file-in-nondev-package
Severity: pedantic
Check: languages/ocaml
Explanation: This package doesn't appear to be a development package, but
 installs OCaml development files (<code>.cmi</code>, <code>.cmx</code> or
 <code>.cmxa</code>). These files should be moved to a development package.
