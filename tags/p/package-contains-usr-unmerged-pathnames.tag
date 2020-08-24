Tag: package-contains-usr-unmerged-pathnames
Severity: classification
Check: files/usr-merge
Explanation: The package installs the listed file to a directory in / (the
 filesystem root) rather than to the corresponding directory inside /usr.
 .
 Debian requires systems to mount /usr prior to invoking init (using an
 initramfs if necessary) so any executables, libraries, or other files
 placed in / for use by early portions of the system init no longer need
 to do so.
 .
 Moving a file from / to /usr (especially an executable in /bin or
 /sbin) will often require a compatibility symlink to the new location,
 as other software may invoke it by absolute path.
 .
 A compatibility symlink to the corresponding file in /usr will not
 trigger this warning but a symlink to anywhere else will.
