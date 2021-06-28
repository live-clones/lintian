Tag: non-standard-file-perm
Severity: warning
Check: files/permissions
Explanation: The file has a mode different from 0644. In some cases this is
 intentional, but in other cases this is a bug.
See-Also: policy 10.9

Screen: toolchain/gnat/ali-read-only
Petitioners: Nicolas Boulenguez <nicolas@debian.org>
Reason: In GNAT, the compiler also deals with dependencies and rebuild order.
 The <tt>.ali</tt> files contain the dependency information required to detect
 if a <tt>.o</tt> is more recent than the closure of all sources it depends
 upon, or if it should be rebuilt.
 .
 By convention, a read-only <tt>.ali</tt> file tells <tt>GNAT</tt> to fail if
 the <tt>.o</tt> is obsolete or unavailable, instead of attempting to rebuild.
 This is recommended for packaged libraries (the <tt>.so</tt> or <tt>.a</tt>
 are available but not the <tt>.o</tt> files).
 .
 This convention may seem bizarre according to modern standards, but it
 has been in use for 25 years, so Adacore would probably need a
 compelling reason to break it.
 .
 See also Debian Policy 8.4, which explicitly requires this:
 .
 If the package provides Ada Library Information (<tt>*.ali</tt>) files for use
 with <tt>GNAT</tt>, these files must be installed read-only (mode 0444) so that
 <tt>GNAT>/tt> will not attempt to recompile them. This overrides the normal
 file mode requirements given in "Permissions and owners."
See-Also:
 policy 8.4,
 Bug#986400
