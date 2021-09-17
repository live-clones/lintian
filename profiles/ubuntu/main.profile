# The default profile for Ubuntu and derivatives thereof.
Profile: ubuntu/main
Extends: debian/main
Disable-Tags:
 bugs-field-does-not-refer-to-debian-infrastructure
 debian-changelog-file-is-a-symlink
 lzma-deb-archive
 mail-address-loops-or-bounces
 maintainer-upload-has-incorrect-version-number
 no-human-maintainers
 no-nmu-in-changelog
 qa-upload-has-incorrect-version-number
 source-nmu-has-incorrect-version-number
 team-upload-has-incorrect-version-number
 upstart-job-in-etc-init.d-not-registered-via-update-rc.d
