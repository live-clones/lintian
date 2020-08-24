Tag: source-contains-prebuilt-wasm-binary
Severity: pedantic
Check: cruft
Explanation: The source tarball contains a prebuilt binary wasm object.
 They are usually provided for the convenience of users. These files
 usually just take up space in the tarball and need to be rebuilt from
 source.
 .
 Check if upstream also provides source-only tarballs that you can use as
 the upstream distribution instead. If not, you may want to ask upstream
 to provide source-only tarballs.
