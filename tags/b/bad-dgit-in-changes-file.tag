Tag: bad-dgit-in-changes-file
Severity: error
Check: fields/dgit
Explanation: The changes file specifies an invalid value for the Dgit field.
 The value of the Dgit field must contain a commit hash, the distro to which
 the upload was made, a tag name, and a url to use as a hint for the dgit git
 server for that distro, each separated by a single space.
See-Also: dgit(1), dgit(7)
