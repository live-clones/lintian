Tag: repeated-trigger-name
Severity: error
Check: triggers
Explanation: The package repeats the same trigger. There should be no reason to
 do this and it may lead to confusing results or errors.
 .
 For the same "base" type of trigger (e.g. two <tt>interest</tt>-type triggers)
 the last declaration will be the effective one.
 .
 This tag is also triggered if the package has an <tt>activate</tt> trigger
 for something on which it also declares an <tt>interest</tt>. The only (but
 rather unlikely) reason to do this is if another package <i>also</i>
 declares an <tt>interest</tt> and this package needs to activate that
 other package. If the package is using it for this exact purpose, then
 please use a Lintian override to state this.
 .
 Please remove any duplicate definitions.
See-Also: deb-triggers(5), #698723
