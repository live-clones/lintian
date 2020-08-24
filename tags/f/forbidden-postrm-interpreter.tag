Tag: forbidden-postrm-interpreter
Severity: error
Check: scripts
Explanation: This package contains a <tt>postrm</tt> maintainer script that uses
 an interpreter that isn't essential. The <tt>purge</tt> action of
 <tt>postrm</tt> can only rely on essential packages, which means the
 interpreter used by <tt>postrm</tt> must be one of the essential ones
 (<tt>sh</tt>, <tt>bash</tt>, or <tt>perl</tt>).
See-Also: policy 7.2
