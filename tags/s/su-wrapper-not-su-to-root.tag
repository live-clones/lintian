Tag: su-wrapper-not-su-to-root
Severity: warning
Check: menu-format
Explanation: The command in a <code>menu</code> item or in a Desktop file uses
 a <code>su</code> wrapper other than <code>su-to-root</code>.
 .
 On Debian systems, please use <code>su-to-root -X</code>. That will pick the
 best wrapper depending on which software is installed and which desktop
 environment is being used.
 .
 Using <code>su-to-root</code> is especially important for Live CD systems.
 They need to use <code>sudo</code> rather than <code>su</code>. The
 <code>su-to-root</code> command can be configured to invoke only
 <code>sudo</code>.
