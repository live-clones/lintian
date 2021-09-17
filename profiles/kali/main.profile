# The default profile for Kali Linux and derivatives thereof.
Profile: kali/main
Extends: debian/main
Disable-Tags:
 bugs-field-does-not-refer-to-debian-infrastructure
 no-nmu-in-changelog
 source-nmu-has-incorrect-version-number

# Kali ships some packages where upstream only supports installation in /opt so
# allow us to override this tag in those packages.
Tags:
 dir-or-file-in-opt
Overridable: yes
