Tag: native-source-file-without-utf8-name
Severity: error
Check: files/names
See-Also: policy 10.10
Explanation: The file name in the native source tree is not valid UTF-8.
 File names must decode as valid UTF-8. Please rename the file.
 .
 Unlike other file names in Lintian, which are printed in UTF-8, the
 attached reference shows the bytes used by the file system.
 Unprintable characters may have been replaced.
