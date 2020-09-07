Tag: missing-intermediate-directory
Severity: warning
Check: files/missing
Explanation: The package contains files in the listed directory, but does
 not contain the actual directory itself. Some tools do not cope
 very well with this case. Notably Lintian prior to 2.5.32 would
 crash on such packages.
