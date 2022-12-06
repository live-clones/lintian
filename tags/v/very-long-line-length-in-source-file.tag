Tag: very-long-line-length-in-source-file
Experimental: yes
Severity: pedantic
Check: files/contents/line-length
Explanation: The source file includes a line length that is well beyond
 the normally human made code line length.
 .
 This very long line length does not allow Lintian to do
 correctly some source file checks.
 .
 This line could also be the result of some text injected by
 a computer program, and thus could lead to FTBFS bugs.
 .
 Last but not least, long line in source code could be used
 to obfuscate the source code and to hide stuff like backdoors
 or security problems.
 .
 It could be due to jslint source comments or other build tool
 comments.
 .
 You may report this issue upstream.
Renamed-From:
 insane-line-length-in-source-file

Screen: autotools/long-lines
Advocates: Russ Allbery <rra@debian.org>
Reason:
 Upstream sources using <code>autoconf</code> have traditionally been
 distributed with generated <code>./configure</code> scripts as well as
 other third-party <code>m4</code> macro files such as <code>libtool</code>.
 .
 When paired with <code>automake</code>, there may also be some intermediate
 <code>Makefile.in</code> files.
 .
 A lot of sources potentially contain such files, but they are not actionable
 by either the Debian distributor or by the upstream maintainer.
 .
 As a side note, modern Debian build protocols will re-create many of those
 files via <code>dh_autoreconf</code>. They are present merely to aid in
 bootstrapping systems where the GNU suite may not yet be available.
See-Also:
 Bug#996740
