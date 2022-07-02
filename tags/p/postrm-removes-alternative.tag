Tag: postrm-removes-alternative
Severity: warning
Check: scripts
Renamed-From:
 maintainer-script-should-not-use-update-alternatives-remove
Explanation: <code>update-alternatives --remove &lt;alternative&gt; foo</code> is
 called in the <code>postrm</code> maintainer script.
 .
 Instead, <code>update-alternatives --remove</code> should be called in
 <code>prerm</code>.
 .
 Th present command will not work as intended. When <code>postrm</code> runs,
 <code>foo</code> was already deleted. <code>update-alternatives</code> will
 then ignore the program while constructing the list of available alternatives.
 .
 If the symbolic link in <code>/etc/alternatives</code> then still points at
 <code>foo</code>, <code>update-alternatives</code> will not recognize it. It
 will then mark the link as site-specific.
 .
 Going forward, the symbolic link will no longer be updated automatically. It will be
 left dangling until <code>update-alternatives --auto &lt;alternative&gt;</code>
 is run by hand.
See-Also:
 debian-policy appendix-6,
 update-alternatives(8)
