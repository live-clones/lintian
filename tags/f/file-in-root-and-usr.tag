Tag: file-in-root-and-usr
Severity: error
Check: usrmerge
Explanation: The package ships two files with the same name installed both in
 /{bin,sbin,lib&ast;}/ and /usr/{bin,sbin,lib&ast;}/.
 This is incompatible with the merged /usr directories scheme.
 .
 Packages with conflicting files must remove one of them if possible or
 make it a symlink to the other and manage the links in the maintainer
 scripts.
See-Also: https://wiki.debian.org/UsrMerge,
     https://anonscm.debian.org/cgit/users/md/usrmerge.git/plain/debian/README.Debian
