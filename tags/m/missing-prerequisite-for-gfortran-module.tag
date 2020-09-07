Tag: missing-prerequisite-for-gfortran-module
Severity: warning
Check: languages/fortran/gfortran
Explanation: The installation package ships a GFORTRAN module but does not depend
 on gfortran-mod-&lt;n&gt;, where &lt;n&gt; is the module version (e.g. gfortran-mod-14
 for modules built using GCC 5).
See-Also: Bug#796352,
 Bug#714730,
 https://salsa.debian.org/science-team/dh-fortran-mod/blob/debian/master/dh_fortran_mod.in
