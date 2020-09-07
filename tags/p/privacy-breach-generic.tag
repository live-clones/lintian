Tag: privacy-breach-generic
Severity: warning
Check: files/privacy-breach
Explanation: This package creates a potential privacy breach by fetching data
 from an external website at runtime. Please remove these scripts or
 external HTML resources.
 .
 Please replace any scripts, images, or other remote resources with
 non-remote resources. It is preferable to replace them with text and
 links but local copies of the remote resources are also acceptable as
 long as they don't also make calls to remote services. Please ensure
 that the remote resources are suitable for Debian main before making
 local copies of them.
