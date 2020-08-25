Tag: override_dh_auto_test-does-not-check-DEB_BUILD_OPTIONS
Severity: info
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package has an
 <code>override&lowbar;dh&lowbar;auto&lowbar;test</code> target that does not appear to
 check <code>DEB&lowbar;BUILD&lowbar;OPTIONS</code> against <code>nocheck</code>.
 .
 As this check is not automatically performed by debhelper(1), the
 specified testsuite is run regardless of another maintainer using
 the <code>nocheck</code> build option.
 .
 Please add a check such as:
 .
  override&lowbar;dh&lowbar;auto&lowbar;test:
  ifeq (,$(filter nocheck,$(DEB&lowbar;BUILD&lowbar;OPTIONS)))
          ./run-upstream-testsuite
  endif
 .
 Lintian will ignore comments and other lines such as:
 .
  # Disabled
  : Disabled
  echo "Disabled"
  mkdir foo/
  ENV=var dh&lowbar;auto&lowbar;test -- ARG=value
 .
 This check is not required in Debhelper compat level 13 or greater
 (see Bug#568897).
See-Also: policy 4.9.1, https://wiki.debian.org/BuildProfileSpec#Registered_profile_names
