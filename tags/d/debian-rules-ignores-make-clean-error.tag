Tag: debian-rules-ignores-make-clean-error
Severity: warning
Check: debian/rules
Explanation: A rule in the <code>debian/rules</code> file for this package calls the
 package's clean or distclean target with a line like:
 .
  -$(MAKE) distclean
 or
  $(MAKE) -i distclean
 .
 The leading "-" or the option -i tells make to ignore all errors.
 Normally this is done for packages using Autoconf since Makefile may not
 exist. However, this line ignores all other error messages, not just
 the missing Makefile error. It's better to use:
 .
  [ ! -f Makefile ] || $(MAKE) distclean
 .
 so that other error messages from the clean or distclean rule will still
 be caught (or just remove the "-" if the package uses a static makefile).
