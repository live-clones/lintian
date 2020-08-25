Tag: arch-dep-package-has-big-usr-share
Severity: info
Check: huge-usr-share
Explanation: The package has a significant amount of architecture-independent
 data (over 4MB, or over 2MB and more than 50% of the package) in
 <code>/usr/share</code> but is an architecture-dependent package. This is
 wasteful of mirror space and bandwidth since it means distributing
 multiple copies of this data, one for each architecture.
 .
 If the data in <code>/usr/share</code> is not architecture-independent, this
 is a Policy violation that should be fixed by moving the data elsewhere
 (usually <code>/usr/lib</code>).
See-Also: devref 6.7.5
