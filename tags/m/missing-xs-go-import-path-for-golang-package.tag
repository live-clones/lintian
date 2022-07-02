Tag: missing-xs-go-import-path-for-golang-package
Severity: info
Check: languages/golang/import-path
Explanation: This Golang source does not declare a <code>XS-Go-Import-Path</code>
 field in the <code>debian/control</code> file..
 .
 Many tools like <code>dh-make-golang(1)</code> use the field to resolve
 resolve prerequisites correctly. It is also used in the Golang team's CI.
 .
 When using <code>dh-golang</code>, the field's value should be the same as
 <code>DH&lowbar;GOPKG</code> in <code>debian/rules</code>. The
 <code>dh-golang</code> build system then automatically sets <code>DH&lowbar;GOPKG</code>
 to the value from <code>XS-Go-Import-Path</code>.
 .
 For packages that do not use <code>dh-golang</code>, or for packages whose upstream
 does not publish the sources in a way compatible with <code>go get</code> (and hence
 does not have a canonical import path) you should use a fake import path. Please
 contact the Golang team at for more advice.
See-Also:
 https://go-team.pages.debian.net,
 https://go-team.pages.debian.net/ci.html.
