Tag: gfortran-module-does-not-declare-version
Severity: warning
Check: languages/fortran/gfortran
Explanation: The installation package ships a GFORTRAN module which does not
 declare a module version number. That number is needed to establish the
 proper prerequisites for binary rebuilds.
See-Also: Bug#796352,
 Bug#714730,
 https://salsa.debian.org/science-team/dh-fortran-mod/blob/debian/master/dh_fortran_mod.in
