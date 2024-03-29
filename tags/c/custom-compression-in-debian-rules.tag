Tag: custom-compression-in-debian-rules
Severity: warning
Check: debian/rules
Renamed-From: debian-rules-should-not-use-custom-compression-settings
Explanation: This package calls <code>dh&lowbar;builddeb(1)</code> to select a custom
 compression level or algorithm in <code>debian/rules</code>. Please remove
 the call and let dpkg-deb(1) select suitable defaults.
 .
 Custom compression settings are usually chosen for one of two
 reasons:
 .
 Higher compression levels or more advanced algorithms shrink the
 sizes of large files, but they can cause problems in the resource 
 constrained environments used in Debian's buildd infrastructure. 
 For example, higher than expected memory consumption may trigger   
 an FTBFS or a failure to install.
 .
 Lower compression levels or less advanced algorithms are sometimes
 needed to support older Debian version. Unfortunately, they also 
 make it harder to change the defaults on an archive-wide basis.
 .
 Some legitimate use cases trigger this tag. Please override it.       
See-Also: Bug#829100, Bug#906614, Bug#909696, dpkg-deb(1)
