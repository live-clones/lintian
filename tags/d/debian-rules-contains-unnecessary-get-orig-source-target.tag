Tag: debian-rules-contains-unnecessary-get-orig-source-target
Severity: info
Check: debian/rules
Explanation: This package's <code>debian/rules</code> file contains a
 <code>get-orig-source</code> target that appears to be unnecessary. For
 example, the package might simply contain a single call to uscan(1).
 .
 Such calls are not ideal; maintainers should be able to call uscan with
 their own choice of options and they additionally encourage the
 proliferation of boilerplate code across the archive.
 .
 Since Debian Policy 4.1.4, packages are encouraged to migrate to uscan
 and a <code>Files-Excluded</code> header in the <code>debian/copyright</code>
 file.
See-Also: uscan(1)
