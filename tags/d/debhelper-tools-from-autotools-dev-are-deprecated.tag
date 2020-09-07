Tag: debhelper-tools-from-autotools-dev-are-deprecated
Severity: warning
Check: debhelper
Explanation: The debhelper tools from autotools-dev has been replaced by the tool
 <code>dh&lowbar;update&lowbar;autotools&lowbar;config</code>, which was available in
 debhelper (&gt;= 9.20160114)
 .
 The <code>dh&lowbar;update&lowbar;autotools&lowbar;config</code> is run
 by default via the <code>dh</code>
 command sequencer. If you are using <code>dh</code>, you can probably just remove
 the uses of the tooling from autotools-dev without doing any further changes.
 .
 If you use the "classic" debhelper style, then please replace all
 calls to <code>dh&lowbar;autotools-dev&lowbar;updateconfig</code> with
 <code>dh&lowbar;update&lowbar;autotools&lowbar;config</code>. The calls to
 <code>dh&lowbar;autotools-dev&lowbar;restoreconfig</code> are replaced by
 <code>dh&lowbar;clean</code>, so they can most likely just be removed without
 any further changes.
See-Also: Bug#878528
