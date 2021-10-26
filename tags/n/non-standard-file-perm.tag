Tag: non-standard-file-perm
Severity: warning
Check: files/permissions
Explanation: The file has a mode different from 0644. In some cases this is
 intentional, but in other cases this is a bug.
See-Also: policy 10.9

Screen: toolchain/gnat/ali-read-only
Advocates: Nicolas Boulenguez <nicolas@debian.org>
Reason: In GNAT, the compiler also deals with dependencies and rebuild order.
 The <code>.ali</code> files contain the dependency information required to detect
 if a <code>.o</code> is more recent than the closure of all sources it depends
 upon, or if it should be rebuilt.
 .
 By convention, a read-only <code>.ali</code> file tells <code>GNAT</code> to fail if
 the <code>.o</code> is obsolete or unavailable, instead of attempting to rebuild.
 This is recommended for packaged libraries (the <code>.so</code> or <code>.a</code>
 are available but not the <code>.o</code> files).
 .
 This convention may seem bizarre according to modern standards, but it
 has been in use for 25 years, so Adacore would probably need a
 compelling reason to break it.
 .
 See also Debian Policy 8.4, which explicitly requires this:
 .
 If the package provides Ada Library Information (<code>&ast;.ali</code>) files for use
 with <code>GNAT</code>, these files must be installed read-only (mode 0444) so that
 <code>GNAT</code> will not attempt to recompile them. This overrides the normal
 file mode requirements given in "Permissions and owners."
See-Also:
 policy 8.4,
 Bug#986400
