Tag: ruby-interpreter-is-deprecated
Severity: warning
Check: languages/ruby
Explanation: In the past, Ruby interpreter packages used to provide the
 `ruby-interpreter` virtual package. That virtual package is now deprecated, is
 not provided by any package, and should not be used as a dependency.
 .
 For packages using gem2deb, you could replace all Ruby-related dependencies,
 both on the interpreter and on any libraries, by ${ruby:Depends}. That will be
 expanded during the build to include all the necessary dependencies.
