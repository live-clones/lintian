Tag: homepage-gitlab-url-ends-with-dot-git
Severity: warning
Check: fields/homepage
Explanation: The Homepage field contains a GitLab URL that ends with .git
 Please update to use the canonical URL, without .git at the end, for the
 GitLab repository instead.
 .
 https://gitlab.com/foo/bar
 .
 not:
 .
 https://gitlab.com/foo/bar.git
