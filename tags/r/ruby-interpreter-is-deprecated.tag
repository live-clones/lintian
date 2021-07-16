Tag: ruby-interpreter-is-deprecated
Severity: warning
Check: languages/ruby
Explanation: Starting with ruby2.3, Ruby interpreter packages stopped
 providing the  <code>ruby-interpreter</code> virtual package. It should
 no longer be used as a prerequisite.
 .
 In packages using <code>gem2deb</code>, please consider using
 <code>${ruby:Depends}</code>. It will expand automatically to the
 prerequisites the package needs (including the interpreter as well
 as the libraries) and can replace all other Ruby-related dependency
 declarations.
