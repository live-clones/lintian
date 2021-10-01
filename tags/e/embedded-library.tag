Tag: embedded-library
Severity: error
Check: libraries/embedded
Explanation: The given ELF object appears to have been statically linked to
 a library. Doing this is strongly discouraged due to the extra work
 needed by the security team to fix all the extra embedded copies or
 trigger the package rebuilds, as appropriate.
 .
 If the package uses a modified version of the given library it is highly
 recommended to coordinate with the library's maintainer to include the
 changes on the system version of the library.
See-Also: policy 4.13
