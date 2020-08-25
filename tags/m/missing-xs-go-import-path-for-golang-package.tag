Tag: missing-xs-go-import-path-for-golang-package
Severity: info
Check: debian/control
Explanation: This source package does not specify a <code>XS-Go-Import-Path</code>
 control field.
 .
 The <code>XS-Go-Import-Path</code> exposes the import path of the Go
 package to the Debian archive in an easily machine-readable form which
 is then used by tools such as <code>dh-make-golang(1)</code> to resolve
 dependencies, avoid accidental duplication in the archive, or in
 https://go-team.pages.debian.net/ci.html.
 .
 For packages using <code>dh-golang</code>, the field should be set to the same
 value as the <code>DH&lowbar;GOPKG</code> variable in <code>debian/rules</code>.
 <code>dh-golang</code> will automatically set <code>DH&lowbar;GOPKG</code> to the
 <code>XS-Go-Import-Path</code> value.
 .
 For packages which do not use <code>dh-golang</code> (or where upstream does
 not publish the source in a way that is compatible with <code>go get</code>
 and hence does not have a canonical import path) it is preferred to
 set a fake import path. Please contact the pkg-go team at
 https://go-team.pages.debian.net/ for more specific advice in this
 situation.
