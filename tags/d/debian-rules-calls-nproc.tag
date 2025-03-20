Tag: debian-rules-calls-nproc
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package appears to
 use nproc to determine the number of jobs to run in parallel during the
 package build. This violates the Debian Policy, as the build must respect
 "parallel=N" when passed in DEB_BUILD_OPTIONS.
 .
 To determine the number of jobs to run in parallel during the package build,
 you can use the DEB_BUILD_OPTION_PARALLEL variable from
 <code>/usr/share/dpkg/buildopts.mk</code>, which is set to the value of "N"
 when "parallel=N" is passed.
 .
     include /usr/share/dpkg/buildopts.mk
     NUM_CPUS=$(DEB_BUILD_OPTION_PARALLEL)
 .
 You can also use Make's <code>addprefix</code> to add a prefix like "-j" if
 the DEB_BUILD_OPTION_PARALLEL variable is present, which can then be passed as
 an argument.
See-Also: debian-policy 4.9.1
