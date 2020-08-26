Tag: debian-changelog-file-is-a-symlink
Severity: warning
Check: debian/changelog
Explanation: The Debian changelog file is a symlink to a file in a different
 directory or not found in this package. Please don't do this. It makes
 package checking and manipulation unnecessarily difficult. Because it was
 a symlink, the Debian changelog file was not checked for other
 problems. (Symlinks to another file in /usr/share/doc/*pkg* or a
 subdirectory thereof are fine and should not trigger this warning.)
 .
 To refer to the changelog, copyright, and other documentation files of
 another package that this one depends on, please symlink the entire
 /usr/share/doc/*pkg* directory rather than individual files.
