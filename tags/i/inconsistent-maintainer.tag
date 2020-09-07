Tag: inconsistent-maintainer
Severity: error
Check: fields/maintainer
Explanation: The Maintainer address in a group of related processables is
 inconsistent as indicated.
 .
 This sometimes happens when environmental variables like <code>DEBEMAIL</code>
 are set to different values when building sources and changes separately.
 Please use the same maintainer everywhere.
See-Also: Bug#546525, https://wiki.ubuntu.com/DebianMaintainerField, Ubuntu Bug#1862787
