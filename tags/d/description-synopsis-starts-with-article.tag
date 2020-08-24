Tag: description-synopsis-starts-with-article
Severity: warning
Check: fields/description
Explanation: The first line of the "Description:" should omit any initial indefinite
 or definite article: "a", "an", or "the". A good heuristic is that it should
 be possible to substitute the package <tt>name</tt> and <tt>synopsis</tt>
 into this formula:
 .
 The package <tt>name</tt> provides {a,an,the,some} <tt>synopsis</tt>.
See-Also: devref 6.2.2
