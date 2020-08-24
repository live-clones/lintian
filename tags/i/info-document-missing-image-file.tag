Tag: info-document-missing-image-file
Severity: warning
Check: documentation/texinfo
Explanation: This info document contains an "[image]" but the image file it
 specifies is missing. Texinfo <tt>@image{}</tt> becomes
 .
  [image src="filename.png"]
 .
 in the <tt>.info</tt>. Emacs 22 and up info
 mode can display this in a GUI if filename.png is in
 <tt>/usr/share/info</tt> or if the src gives a path to the file
 elsewhere.
 .
 If you put an image file in <tt>/usr/share/info</tt> then please name
 it like the document so as to avoid name clashes. Eg. foo.info might
 call an image foo-example1.png. If upstream does not do this already
 then it may be easier to <tt>sed</tt> the <tt>src=""</tt> to a path
 elsewhere, perhaps to share with an HTML rendition under say
 <tt>/usr/share/doc/foo/html/</tt>.
