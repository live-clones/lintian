Tag: debian-files-list-in-source
Severity: error
Check: debian/files
Explanation: Leaving <code>debian/files</code> causes problems for the autobuilders,
 since that file will likely include the list of .deb files for another
 architecture, which will cause dpkg-buildpackage run by the buildd to fail.
 .
 The clean rule for the package should remove this file.
See-Also: policy 4.12
