# The default profile for Ubuntu and derivatives thereof.
Profile: ubuntu/main
Extends: debian/main
Disable-Tags: debian-changelog-file-is-a-symlink,
 lzma-deb-archive, no-upstream-changelog,
 upstart-job-in-etc-init.d-not-registered-via-update-rc.d

# Serious as it may break Lucid upgrade path
Tags: data.tar.xz-member-without-dpkg-pre-depends
Severity: serious

