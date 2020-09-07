Tag: excessive-debhelper-overrides
Severity: warning
Check: debhelper
Explanation: The <code>debian/rules</code> file appears to include a suspiciously
 high number of <code>override&lowbar;dh&lowbar;</code>-style overrides.
 .
 It is likely that is this was intended to optimise package builds by
 introducing "no-op" overrides that avoid specific debhelper commands.
 .
 However, whilst using overrides are not a problem per-se, such a list
 is usually subject to constant revision, prevents future debhelper
 versions fixing archive-wide problems, adds unnecessary
 noise/distraction for anyone reviewing the package, and increases the
 package's "bus factor". It is, in addition, aesthetically displeasing.
 .
 Furthermore, this is typically a premature optimisation. debhelper already
 includes optimizations to avoid running commands when unnecessary. If you find
 a debhelper command taking unnecessarily long when it has no work to do,
 please work with the debhelper developers to help debhelper skip that command
 in more circumstances, optimizing not only your package build but everyone
 else's as well.
 .
 Please remove the unnecessary overrides.
See-Also: debhelper(7), dh(1)
