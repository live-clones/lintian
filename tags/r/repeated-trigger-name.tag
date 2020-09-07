Tag: repeated-trigger-name
Severity: error
Check: triggers
Explanation: The package repeats the same trigger. There should be no reason to
 do this and it may lead to confusing results or errors.
 .
 For the same "base" type of trigger (e.g. two <code>interest</code>-type triggers)
 the last declaration will be the effective one.
 .
 This tag is also triggered if the package has an <code>activate</code> trigger
 for something on which it also declares an <code>interest</code>. The only (but
 rather unlikely) reason to do this is if another package *also*
 declares an <code>interest</code> and this package needs to activate that
 other package. If the package is using it for this exact purpose, then
 please use a Lintian override to state this.
 .
 Please remove any duplicate definitions.
See-Also: deb-triggers(5), Bug#698723
