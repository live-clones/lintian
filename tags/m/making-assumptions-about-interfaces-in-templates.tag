Tag: making-assumptions-about-interfaces-in-templates
Severity: warning
Check: debian/debconf
Explanation: Template text should not make reference to widgets belonging to
 some debconf interfaces. Sentences like "If you answer Yes..." have no
 meaning for users of graphical interfaces which use checkboxes for
 boolean questions.
See-Also: devref 6.5.2.4
