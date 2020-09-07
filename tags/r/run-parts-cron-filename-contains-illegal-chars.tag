Tag: run-parts-cron-filename-contains-illegal-chars
Severity: warning
Check: cron
Explanation: The script in /etc/cron.&lt;time-interval&gt; will not be executed by
 run-parts(8) because the filename contains a "." (full stop) or "+" (plus).
 .
 It is recommended to use "&lowbar;" (underscores) instead of these symbols.
See-Also: run-parts(8), policy 9.5.1
