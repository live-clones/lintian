Tag: rubygem-homepage
Severity: warning
Check: languages/ruby
Explanation: The <code>Homepage</code> field in this package's
 control file refers to Rubygems, and not to the true upstream.
 .
 Debian packages should point at the upstream's homepage, but
 Rubygems is just another packaging system. You may be able to
 find the correct information in the <code>Homepage</code> link
 of the corresponding Rubygems package.
See-Also:
 Bug#981935
