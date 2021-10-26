Tag: shell-script-fails-syntax-check
Severity: error
Check: script/syntax
Explanation: Running this shell script with the shell's -n option set fails,
 which means that the script has syntax errors. The most common cause of
 this problem is a script expecting <code>/bin/sh</code> to be bash checked on
 a system using dash as <code>/bin/sh</code>.
 .
 Run e.g. <code>sh -n yourscript</code> to see the errors yourself.
 .
 Note this can have false-positives, for an example with bash scripts
 using "extglob".
