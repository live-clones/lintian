Tag: uses-implicit-await-trigger
Severity: warning
Check: triggers
Explanation: The listed trigger is present in the control file of the package.
 The trigger is an await trigger, which may not be obvious from its name.
 .
 Await triggers place rather strong requirements on dpkg that often lead
 to trigger cycles due to changes in other packages.
 .
 If the package does not need the guarantees that dpkg provides to await
 triggers, please use the "-noawait" variant of the trigger. This is often
 the case for packages that use the trigger to compile a form of cache.
 .
 If the package does need the guarantees provided by dpkg, then please
 document the rationale in a comment above the trigger and use the
 "-await" variant of the trigger to avoid this warning.
See-Also: deb-triggers(5), Bug#774559
