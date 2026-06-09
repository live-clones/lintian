# The default profile for ParrotOS and derivatives thereof.
Profile: parrot/main
Extends: debian/main
Disable-Tags:
 bugs-field-does-not-refer-to-debian-infrastructure
 no-nmu-in-changelog
 source-nmu-has-incorrect-version-number

# ParrotOS ships some packages where upstream only supports installation in /opt so
# allow us to override this tag in those packages.
Tags:
 dir-or-file-in-opt
Overridable: yes
