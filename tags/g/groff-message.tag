Tag: groff-message
Severity: warning
Check: documentation/manual
Renamed-From: manpage-has-errors-from-man
Explanation: A manual page provoked warnings or errors from the <code>man</code>
 program. Here are some common ones:
 .
 "cannot adjust" or "can't break" are issues with paragraph filling. They
 are usually related to long lines. Justifying text on the left hand side
 can help with adjustments. Hyphenation can help with breaks.
 .
 For more information, please see "Manipulating Filling and Adjusting"
 and "Manipulating Hyphenation" in the Groff manual (see <code>info groff</code>).
 .
 "can't find numbered character" usually means that the input was in a
 national legacy encoding. The warning means that some characters were
 dropped. Please use escapes such as <code>\[:a]</code> as described on the
 <code>groff&lowbar;char</code> manual page.
 .
 Other common warnings are formatting typos. String arguments to
 <code>.IP</code> require quotes. Usually, some text is lost or mangled. See
 the <code>groff&lowbar;man</code> (or <code>groff&lowbar;mdoc</code> if using <code>mdoc</code>)
 manual page for details on macros.
 .
 The check for manual pages uses the <code>--warnings</code> option to
 <code>man</code> to catch common problems, like a <code>.</code> or a <code>'</code>
 at the beginning of a line as literal text. They are interpreted as
 Groff commands. Just reformat the paragraph so the characters are not at
 the beginning of a line. You can also add a zero-width space (<code>\&</code>)
 in front of them.
 .
 Aside from overrides, warnings can be disabled with the <code>.warn</code>
 directive. Please see "Debugging" in the Groff manual.
 .
 You can see the warnings yourself by running the command used by Lintian:
 .
     <code>LC&lowbar;ALL=C.UTF-8 MANROFFSEQ='' MANWIDTH=80 \
         man --warnings -E UTF-8 -l -Tutf8 -Z &lt;file&gt; &gt;/dev/null</code>
See-Also: groff_man(7), groff_mdoc(7)
