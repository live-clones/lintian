Tag: exit-in-shared-library
Severity: info
Check: libraries/shared/exit
Experimental: yes
Renamed-From:
 shlib-calls-exit
Explanation: The listed shared library calls the C library exit() or &lowbar;exit()
 functions.
 .
 In the case of an error, the library should instead return an appropriate
 error code to the calling program which can then determine how to handle
 the error, including performing any required clean-up.
 .
 In most cases, removing the call should be discussed with upstream,
 particularly as it may produce an ABI change.
