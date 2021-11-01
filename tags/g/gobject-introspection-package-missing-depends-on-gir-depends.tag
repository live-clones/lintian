Tag: gobject-introspection-package-missing-depends-on-gir-depends
Severity: error
Check: desktop/gnome/gir/substvars
Explanation: The package in <code>debian/control</code> is a GObject Introspection
 installation package but does not declare its prerequisites using the
 <code>${gir:Depends}</code> substvar.
 .
 Without proper runtime prerequisites, a program usually aborts.
 .
 This tag can often be fixed by adding the <code>--with=gir</code> Debhelper
 sequence.
