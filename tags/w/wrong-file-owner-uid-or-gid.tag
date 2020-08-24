Tag: wrong-file-owner-uid-or-gid
Severity: error
Check: files/ownership
Explanation: The user or group ID of the owner of the file is invalid. The
 owner user and group IDs must be in the set of globally allocated
 IDs, because other IDs are dynamically allocated and might be used
 for varying purposes on different systems, or are reserved. The set
 of the allowed, globally allocated IDs consists of the ranges 0-99,
 64000-64999 and 65534.
 .
 It's possible for a Policy-compliant package to trigger this tag if the
 user is created in the preinst maintainer script, but this is a very rare
 case and doesn't appear to be necessary. 
See-Also: policy 9.2
