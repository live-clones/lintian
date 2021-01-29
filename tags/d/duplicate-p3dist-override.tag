Tag: duplicate-p3dist-override
Severity: error
Check: languages/python/dist-overrides
Explanation:
 <code>dh_python3</code> has an override mechanism
 (<code>debian/py3dist-overrides</code>) that lets you specify different
 prerequisites for particular Python
 imports.
 .
 <code>debian/py3dist-overrides</code> is mainly used for Python programs
 that use GObject introspection, since <code>dh_python3</code> cannot yet
 detect that the packages <code>gir1.2-*-*</code> map to Python imports,
 so overrides are needed.
 .
 When the same import appears twice in the file, the information from the
 first one is used but all the others are discarded. That can lead to
 missing prerequisites.
 .
 An example of a second line that gets ignored:
 .
     gi.repository.Gst gir1.2-gst-plugins-base-1.0
     gi.repository.Gst gir1.2-gstreamer-1.0
 .
 An example of a double dependency that gets kept:
 .
     gi.repository.Gst gir1.2-gst-plugins-base-1.0, gir1.2-gstreamer-1.0
See-Also:
 Bug#980987
