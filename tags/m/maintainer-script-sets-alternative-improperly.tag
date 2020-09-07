Tag: maintainer-script-sets-alternative-improperly
Severity: warning
Check: scripts
Renamed-From: maintainer-script-should-not-use-update-alternatives-set
Explanation: The maintainer script calls <code>update-alternatives --set
 &lt;alternative&gt; foo</code> or <code>update-alternatives --config
 &lt;alternative&gt;</code> or <code>update-alternatives --set-selections</code>.
 .
 This makes it impossible to distinguish between an alternative that's
 manually set because the user set it and one that's manually set because
 the package set it.
See-Also: update-alternatives(8)
