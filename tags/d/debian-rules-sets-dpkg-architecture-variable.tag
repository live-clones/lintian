Tag: debian-rules-sets-dpkg-architecture-variable
Severity: warning
Check: debian/rules
See-Also: dpkg-architecture(1)
Explanation: The <code>debian/rules</code> file sets one or more
 <code>dpkg-architecture</code> variables such as <code>DEB&lowbar;BUILD&lowbar;ARCH</code>.
 .
 These variables are pre-initialized in the environment when running under
 <code>dpkg-buildpackage</code> - avoiding these assignments can reduce package
 build time.
 .
 Please use:
 .
   include /usr/share/dpkg/architecture.mk
 .
 instead, or replace the assignment operator with <code>?=</code>.
