Tag: maintainer-script-has-invalid-update-inetd-options
Severity: warning
Check: scripts
See-Also: update-inetd(1), Bug#909758, Bug#909506
Explanation: The specified maintainer script seems to call
 <code>update-inetd(1)</code> with an invalid option combination.
 .
 For example, the <code>--group</code> parameter is only valid in
 combination with <code>--add</code> and <code>--pattern</code> is only valid
 without <code>--add</code>.
 .
 Whilst these have been ignored in the past they now emit a warning
 which will become an error in the future, resulting in upgrade/removal
 failures.
 .
 Please correct the call to <code>update-inetd(1)</code>.
