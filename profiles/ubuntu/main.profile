# The default profile for Ubuntu and derivatives thereof.
Profile: ubuntu/main
Extends: debian/main
Disable-Tags: debian-changelog-file-is-a-symlink,
 lzma-deb-archive, maintainer-address-causes-mail-loops-or-bounces,
 no-upstream-changelog, uploader-address-causes-mail-loops-or-bounces,
 upstart-job-in-etc-init.d-not-registered-via-update-rc.d

# Serious as it may break Lucid upgrade path
Tags: data.tar.xz-member-without-dpkg-pre-depends
Severity: serious

