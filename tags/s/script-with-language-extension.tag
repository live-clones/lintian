Tag: script-with-language-extension
Severity: warning
Check: files/scripts
Explanation: When scripts are installed into a directory in the system PATH, the
 script name should not include an extension such as <code>.sh</code> or
 <code>.pl</code> that denotes the scripting language currently used to
 implement it. The implementation language may change; if it does,
 leaving the name the same would be confusing and changing it would be
 disruptive.
See-Also: policy 10.4
