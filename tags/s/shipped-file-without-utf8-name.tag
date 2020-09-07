Tag: shipped-file-without-utf8-name
Severity: error
Check: files/names
See-Also: policy 10.10
Explanation: The file name in the installed tree is not valid UTF-8.
 As a shipped file in an installation package, the name of this file is
 considered the responsibility of the package maintainer. Please
 rename the file.
 .
 Unlike other file names in Lintian, which are printed in UTF-8, the
 attached reference shows the bytes used by the file system.
 Unprintable characters may have been replaced.
Renamed-From: file-name-is-not-valid-UTF-8
