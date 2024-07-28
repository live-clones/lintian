Tag: acute-accent-in-manual-page
Severity: info
Check: documentation/manual
Renamed-From: acute-accent-in-manpage
Explanation: This manual page uses the <code>\'</code> groff
 sequence. Usually, the intent is to generate an apostrophe, but that
 sequence actually renders as an acute accent.
 .
 For an apostrophe or a single closing quote, use plain <code>'</code>.
 For single opening quote, i.e. a straight downward line <code>'</code>
 like the one used in shell commands, use <code>'&#92;(aq'</code>.
 .
 In case this tag was emitted for the second half of a
 <code>'\\'</code> sequence, this is indeed no acute accent, but still
 wrong: A literal backslash should be written <code>\e</code> in the
 groff format, i.e. a <code>'\\'</code> sequence needs to be changed
 to <code>'\e'</code> which also won't trigger this tag.
See-Also: Bug#554897, Bug#507673, Bug#966803
