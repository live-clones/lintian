Tag: chown-with-dot
Severity: pedantic
Check: script/deprecated/chown
Explanation: The named script uses a dot to separate owner and group in
 a call like <code>chown user.group</code> but that usage is deprecated.
 .
 Please use a colon instead, as in:
 .
 <code>chown user:group</code>.
