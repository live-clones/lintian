set -l tags $(lintian-explain-tags --list-tags)
complete -c lintian-explain-tags -f -a "$tags"
complete -c lintian-explain-tags -s l -l list-tags -d 'list all tags Lintian knows about'
complete -c lintian-explain-tags -l include-dir --force-files -r -d 'check for Lintian data in given DIR'
complete -c lintian-explain-tags -l profile -d 'use given vendor profile X to determine severities'
complete -c lintian-explain-tags -l output-width -d 'set output width instead of probing terminal'
complete -c lintian-explain-tags -l user-dirs -d 'include profiles from user directories'
complete -c lintian-explain-tags -l no-user-dirs -d 'exclude profiles from user directories'
complete -c lintian-explain-tags -l version -d 'show version info and exit'

