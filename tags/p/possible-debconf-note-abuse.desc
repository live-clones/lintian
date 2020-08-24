Tag: possible-debconf-note-abuse
Severity: warning
Check: debian/debconf
Explanation: Debconf notes should be used only for important notes that the
 user really should see, since debconf will go to great pains to make
 sure the user sees it.
 .
 Displaying a note with a low priority is conflicting with this statement,
 since using a low or medium priority shows that the note is not
 important.
 .
 The right fix is NOT to increase the priority of the note, but to move
 it somewhere else in the inline documentation, for example in a
 README.Debian file for notes about package usability or NEWS.Debian for
 changes in the package behavior, or to simply drop it if it is not
 needed (e.g. "welcome" notes). Changing the templates type to "error"
 can also be appropriate, such as for input validation errors.
See-Also: policy 3.9.1
