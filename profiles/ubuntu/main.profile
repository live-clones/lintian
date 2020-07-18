# The default profile for Ubuntu and derivatives thereof.
Profile: ubuntu/main
Extends: debian/main
Disable-Tags: no-nmu-in-changelog,
 debian-changelog-file-is-a-symlink, lzma-deb-archive,
 mail-address-loops-or-bounces,
 maintainer-upload-has-incorrect-version-number,
 qa-upload-has-incorrect-version-number,
 source-nmu-has-incorrect-version-number,
 team-upload-has-incorrect-version-number,
 upstart-job-in-etc-init.d-not-registered-via-update-rc.d,
 no-human-maintainers, bugs-field-does-not-refer-to-debian-infrastructure
