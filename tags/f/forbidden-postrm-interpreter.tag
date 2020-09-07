Tag: forbidden-postrm-interpreter
Severity: error
Check: scripts
Explanation: This package contains a <code>postrm</code> maintainer script that uses
 an interpreter that isn't essential. The <code>purge</code> action of
 <code>postrm</code> can only rely on essential packages, which means the
 interpreter used by <code>postrm</code> must be one of the essential ones
 (<code>sh</code>, <code>bash</code>, or <code>perl</code>).
See-Also: policy 7.2
