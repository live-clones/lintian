Tag: bad-permissions-for-ali-file
Severity: warning
Check: files/permissions
See-Also: policy 8.4
Explanation: Ada Library Information (&ast;.ali) files are required to be read-only
 (mode 0444) by GNAT.
 .
 If at least one user can write the &ast;.ali file, GNAT considers whether
 or not to recompile the corresponding source file. Such recompilation
 would fail because normal users don't have write permission on the
 files. Moreover, such recompilation would defeat the purpose of
 library packages, which provide &ast;.a and &ast;.so libraries to link against).
