Tag: linked-with-obsolete-library
Severity: info
Check: libraries/shared/obsolete
Explanation: This tag is currently only issued for libcblas.so. For an explanation,
 please continue below.
 .
 The symbols in <code>libcblas.so</code>, which represent the <code>CBLAS</code> API,
 were merged into <code>libblas.so</code>. (Note the missing letter <code>C</code>.)
 Please use <code>libblas.so</code> instead.
 .
 The old library is still being shipped until all packages have modified
 their build systems, but it is not managed by <code>update-alternatives</code>
 and may result in poor performance. Please do not use it anymore.
 .
 Some packages may require functionality specific to Atlas3, which is not
 implemented by other <code>BLAS/CBLAS</code> alternatives. Please override the
 tag if your package falls into that category.
See-Also: https://wiki.debian.org/DebianScience/LinearAlgebraLibraries ,
     https://lists.debian.org/debian-devel/2019/10/msg00273.html ,
     https://salsa.debian.org/science-team/lapack/-/blob/master/debian/README.if-you-look-for-libcblas.so.3
