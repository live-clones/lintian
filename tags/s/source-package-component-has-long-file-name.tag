Tag: source-package-component-has-long-file-name
Severity: warning
Check: filename-length
Explanation: The source package has a component with a very long filename.
 This may complicate shipping the package on some media that put
 restrictions on the length of the filenames (such as CDs).
 .
 Lintian only checks emits this tag once per source package based
 on the component with the longest filename.
See-Also: https://lists.debian.org/debian-devel/2011/03/msg00943.html
