Tag: homepage-github-url-ends-with-dot-git
Severity: info
Check: fields/homepage
Explanation: The Homepage field contains a GitHub URL that ends with .git
 Please update to use the canonical URL, without .git at the end, for the
 GitHub repository instead.
 .
 https://github.com/foo/bar
 .
 not:
 .
 https://github.com/foo/bar.git
