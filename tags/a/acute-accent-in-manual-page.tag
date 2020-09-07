Tag: acute-accent-in-manual-page
Severity: info
Check: documentation/manual
Renamed-From: acute-accent-in-manpage
Explanation: This manual page uses the \' groff sequence. Usually, the
 intent to generate an apostrophe, but that sequence actually
 renders as an acute accent.
 .
 For an apostrophe or a single closing quote, use plain <code>'</code>.
 For single opening quote, i.e. a straight downward line <code>'</code>
 like the one used in shell commands, use <code>'&#92;(aq'</code>.
See-Also: Bug#554897, Bug#507673
