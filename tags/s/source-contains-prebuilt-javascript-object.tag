Tag: source-contains-prebuilt-javascript-object
Severity: pedantic
Check: files/source-missing
Explanation: The source tarball contains a prebuilt (minified) JavaScript object.
 They are usually left by mistake when generating the tarball by not
 cleaning the source directory first. You may want to report this as
 an upstream bug, in case there is no sign that this was intended.
