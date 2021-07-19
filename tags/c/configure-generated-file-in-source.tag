Tag: configure-generated-file-in-source
Severity: warning
Check: build-systems/autotools
Explanation: Leaving config.cache/status causes autobuilders problems.
 config.cache and config.status are produced by GNU autoconf's configure
 scripts. If they are left in the source package, autobuilders may pick
 up settings for the wrong architecture.
 .
 The clean rule in <code>debian/rules</code> should remove this file. This
 should ideally be done by fixing the upstream build system to do it when
 you run the appropriate cleaning command (and don't forget to forward the
 fix to the upstream authors so it doesn't happen in the next release). If
 that is already implemented, then make sure you are indeed cleaning it in
 the clean rule. If all else fails, a simple rm -f should work.
 .
 Note that Lintian cannot reliably detect the removal in the clean rule,
 so once you fix this, please ignore or override this warning.
