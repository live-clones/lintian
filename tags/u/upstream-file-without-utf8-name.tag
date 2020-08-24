Tag: upstream-file-without-utf8-name
Severity: info
Check: files/names
See-Also: policy 10.10
Explanation: The file name in the upstream source tree is not valid UTF-8.
 There is probably not much a maintainer can do other than ask upstream
 to package the sources differently.
 .
 Repacking may by an option, but it often has other drawbacks, such as
 the loss of a cryptographic chain of custody.
 .
 Unlike other file names in Lintian, which are printed in UTF-8, the 
 attached reference shows the bytes used by the file system. Unprintable
 characters may have been replaced.
