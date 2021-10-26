Tag: bash-completion-with-hashbang
Severity: warning
Check: shell/bash/completion
Explanation: This file starts with the #! sequence that marks interpreted scripts,
 but it is a bash completion script that is merely intended to be sourced.
 .
 Please remove the line with hashbang, including any designated interpreter.
See-Also:
 https://salsa.debian.org/lintian/lintian/-/merge_requests/292#note_139494
