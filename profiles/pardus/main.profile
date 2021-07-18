# The default profile for Pardus Linux and derivatives thereof.
Profile: pardus/main
Extends: debian/main
Disable-Tags: no-nmu-in-changelog
 source-nmu-has-incorrect-version-number
 bugs-field-does-not-refer-to-debian-infrastructure

# Pardus ships some packages where upstream only supports installation in /opt so
# allow us to override this tag in those packages.
Tags: dir-or-file-in-opt
Overridable: yes
