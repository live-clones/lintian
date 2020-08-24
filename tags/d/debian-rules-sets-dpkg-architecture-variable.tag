Tag: debian-rules-sets-dpkg-architecture-variable
Severity: warning
Check: debian/rules
See-Also: dpkg-architecture(1)
Explanation: The <tt>debian/rules</tt> file sets one or more
 <tt>dpkg-architecture</tt> variables such as <tt>DEB_BUILD_ARCH</tt>.
 .
 These variables are pre-initialized in the environment when running under
 <tt>dpkg-buildpackage</tt> - avoiding these assignments can reduce package
 build time.
 .
 Please use:
 .
   include /usr/share/dpkg/architecture.mk
 .
 instead, or replace the assignment operator with <tt>?=</tt>.
