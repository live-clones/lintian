Tag: missing-xs-go-import-path-for-golang-package
Severity: info
Check: debian/control
Explanation: This source package does not specify a <tt>XS-Go-Import-Path</tt>
 control field.
 .
 The <tt>XS-Go-Import-Path</tt> exposes the import path of the Go
 package to the Debian archive in an easily machine-readable form which
 is then used by tools such as <tt>dh-make-golang(1)</tt> to resolve
 dependencies, avoid accidental duplication in the archive, or in
 https://go-team.pages.debian.net/ci.html.
 .
 For packages using <tt>dh-golang</tt>, the field should be set to the same
 value as the <tt>DH_GOPKG</tt> variable in <tt>debian/rules</tt>.
 <tt>dh-golang</tt> will automatically set <tt>DH_GOPKG</tt> to the
 <tt>XS-Go-Import-Path</tt> value.
 .
 For packages which do not use <tt>dh-golang</tt> (or where upstream does
 not publish the source in a way that is compatible with <tt>go get</tt>
 and hence does not have a canonical import path) it is preferred to
 set a fake import path. Please contact the pkg-go team at
 https://go-team.pages.debian.net/ for more specific advice in this
 situation.
