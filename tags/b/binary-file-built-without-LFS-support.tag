Tag: binary-file-built-without-LFS-support
Severity: info
Check: binaries/large-file-support
Experimental: yes
Explanation: The listed ELF binary appears to be (partially) built without
 "Large File Support" (LFS). If so, it may not be able to handle large
 files or files with large metadata values, such as inode numbers, correctly.
 .
 To support large files, code review might be needed to make sure that
 those files are not slurped into memory or mmap(2)ed, and that correct
 64-bit data types are used (ex: <code>off&lowbar;t</code> instead of <code>ssize&lowbar;t</code>), etc. Once
 that has been done ensure <code>&lowbar;FILE&lowbar;OFFSET&lowbar;BITS</code> is defined and
 set to 64 before any system headers are included (note that on systems
 were the ABI has LFS enabled by default, setting <code>&lowbar;FILE&lowbar;OFFSET&lowbar;BITS</code>
 to 64 will be a no-op, and as such optional). This can be done by using
 the <code>AC&lowbar;SYS&lowbar;LARGEFILE</code> macro with autoconf which will set any
 macro required to enable LFS when necessary, or by enabling the
 <code>lfs</code> feature from the <code>future</code> dpkg-buildflags feature
 area which sets the <code>CPPFLAGS</code> variable (since dpkg-dev 1.19.0).
 Note though, that <code>getconf LFS&lowbar;CFLAGS</code> must not be used,
 as it does not support cross-building. Using
 <code>&lowbar;FILE&lowbar;OFFSET&lowbar;BITS</code> should require no system function renames (eg.
 from open(2) to open64(2)), and if this tag is still emitted, the most
 probable cause is because the macro is not seen by the system code being
 compiled.
 .
 Take into account that even if this tag is not emitted, that does not
 mean the binary is LFS-safe (ie. no OOM conditions, file truncation
 or overwrite will happen).
 .
 Also note that enabling LFS on a shared library is not always safe as
 it might break ABI in case some of the exported types change size, in
 those cases a SOVERSION bump might be required. Or alternatively, on
 systems with an ABI without LFS, defining <code>&lowbar;LARGEFILE64&lowbar;SOURCE</code>
 and exporting both 32 and 64-bit variants of the interfaces can avoid
 the SOVERSION bump, at the cost of more complex maintenance.
See-Also: http://www.unix.org/version2/whatsnew/lfs20mar.html,
 https://www.gnu.org/software/libc/manual/html_node/Feature-Test-Macros.html
