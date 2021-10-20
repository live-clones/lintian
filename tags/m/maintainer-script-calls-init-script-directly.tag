Tag: maintainer-script-calls-init-script-directly
Severity: error
Check: init-d/maintainer-script
Explanation: The named maintainer script appear to run an <code>init</code> script in
 <code>/etc/init.d/&ast;</code> directly and not via <code>invoke-rc.d</code>, but
 the use of <code>invoke-rc.d</code> is required.
 .
 Maintainer scripts may call an init script directly only when <code>invoke-rc.d</code>
 is not available.
See-Also:
 policy 9.3.3.2
