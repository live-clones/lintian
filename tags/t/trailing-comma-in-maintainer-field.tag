Tag: trailing-comma-in-maintainer-field
Severity: error
Check: fields/maintainer
Explanation: The Maintainer field contains a trailing comma, which is not
 permitted as there can only be one maintainer. This breaks the parsing of some
 tools such as the Debian Package Tracker.
See-Also: debian-policy 5.6.2, Bug#1089649
