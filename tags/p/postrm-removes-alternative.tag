Tag: postrm-removes-alternative
Severity: warning
Check: scripts
Renamed-From: maintainer-script-should-not-use-update-alternatives-remove
Explanation: <tt>update-alternatives --remove &lt;alternative&gt; foo</tt> is
 called in the postrm. This can be dangerous because at the time the
 postrm is executed foo has already been deleted and update-alternatives
 will ignore it while constructing its list of available alternatives.
 Then, if the /etc/alternatives symlink points at foo, update-alternatives
 won't recognize it and will mark the symlink as something site-specific.
 As such, the symlink will no longer be updated automatically and will be
 left dangling until <tt>update-alternatives --auto
 &lt;alternative&gt;</tt> is run by hand.
 .
 <tt>update-alternatives --remove</tt> should be called in the prerm
 instead.
See-Also: policy 6*, update-alternatives(8)
