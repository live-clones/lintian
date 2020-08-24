Tag: django-package-does-not-depend-on-django
Severity: warning
Check: languages/python
Explanation: This package appears to be library module for the Django web development
 framework but it does not specify a binary dependency on the Django package
 itself.
 .
 Please add a Depends on <tt>python-django</tt> or <tt>python3-django</tt>.
