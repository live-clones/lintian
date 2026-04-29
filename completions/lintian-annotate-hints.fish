complete -c lintian-annotate-hints -f

complete -c lintian-annotate-hints -s h -l help -d 'display usage info and exit'
complete -c lintian-annotate-hints -l include-dir -r -d 'use given dir as additional lintian root'
complete -c lintian-annotate-hints -l profiles -r -d 'use severities from given vendor profile'
complete -c lintian-annotate-hints -l user-dirs -d 'check user dirs'
complete -c lintian-annotate-hints -l no-user-dirs -d 'do not check user dirs'
