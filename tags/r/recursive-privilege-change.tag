Tag: recursive-privilege-change
Severity: warning
Check: scripts
Renamed-From: maintainer-script-should-not-use-recursive-chown-or-chmod
Explanation: The named maintainer script appears to call <code>chmod</code> or
 <code>chown</code> with a <code>--recursive</code>/<code>-R</code> argument, or
 it uses <code>find(1)</code> with similar intent.
 .
 All such uses are vulnerable to hardlink attacks on mainline (i.e.
 non-Debian) kernels that do not set <code>fs.protected&lowbar;hardlinks=1</code>.
 .
 The security risk arises when when a non-privileged user set links
 to files they do not own, such as such as <code>/etc/shadow</code> or
 files in <code>/var/lib/dpkg/</code>. A superuser's recursive call to
 <code>chown</code> or <code>chmod</code> on behalf of a role user account
 would then modify the non-owned files in ways that allow the
 non-privileged user to manipulate them later.
 .
 There are several ways to mitigate the issue in maintainer scripts:
 .
  - For a static role user, please call <code>chown</code> at build time
    and not during the installation.
  - If that is too complicated, use <code>runuser(1)</code> in the
    relevant build parts to create files with correct ownership.
  - Given a static list of files to change, use non-recursive calls
    for each file. (Please do not generate the list with <code>find</code>.)
See-Also: Bug#895597, Bug#889060, Bug#889488, runuser(1)
