Tag: uses-implicit-await-trigger
Severity: warning
Check: triggers
Explanation: The listed trigger is present in the control file of the package.
 The trigger is an <code>await</code> trigger, which may not be obvious from its name.
 .
 The <code>await</code> triggers place rather strong requirements on <code>dpkg</code> that often lead
 to trigger cycles due to changes in other packages.
 .
 If the package does not need the guarantees that <code>dpkg</code> provides to <code>await</code>
 triggers, please use the <code>-noawait</code> variant of the trigger. This is often
 the case for packages that use the trigger to compile a form of cache.
 .
 If the package does need the guarantees provided by <code>dpkg</code>, then please
 document the rationale in a comment above the trigger and use the
 <code>-await</code> variant of the trigger to avoid this warning.
See-Also:
 deb-triggers(5),
 Bug#774559
