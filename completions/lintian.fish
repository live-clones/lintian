complete -c lintian -f

# Actions
complete -c lintian -s c -l check -d 'run all checks over the specified packages'
complete -c lintian -s C -l check-part -d 'run only specified checks'
complete -c lintian -s F -l ftp-master-rejects -d 'run only checks resulting auto rejects'
complete -c lintian -s T -l tags -d 'run only checks issuing these tags'
complete -c lintian -s X -l dont-check-part -d 'run all but specified checks'
complete -c lintian -l tags-from-file --force-files -r -d 'read tags from file'

# General
complete -c lintian -s h -l help -d 'display usage info and exit'
complete -c lintian -s q -l quiet -d 'supress all information messages'
complete -c lintian -s v -l verbose -d 'display verbose messages'
complete -c lintian -s V -l version -d 'display lintian version number and exit'
complete -c lintian -l print-version -d 'display unadorned version number and exit'

# Behavior
complete -c lintian -l color -a 'auto never always html' -d 'whether to colorize tags in output'
# lintian.debian.org is currently offline.
#complete -c lintian -l hyperlinks -a 'on off' -d 'show text-based hyperlinks to tag descriptions'
complete -c lintian -l default-display-level -d 'reset current display level to the default'
complete -c lintian -l display-source -d 'only display tags from source X'
complete -c lintian -s E -l display-experimental -d 'display experimental ("X:") tags'
complete -c lintian -l no-display-experimental -d 'do not display experimental ("X:") tags'
complete -c lintian -l fail-on -a 'error warning info pedantic experimental override none' -d 'exit with status 2 for given condition'
complete -c lintian -s i -l info -d 'print explanatory info about each additional problem'
complete -c lintian -s I -l display-info -d 'display informational ("I:") tags'
complete -c lintian -s L -l display-level -d 'fine-grained selection of tags to be displayed'
complete -c lintian -s o -l no-override -d 'ignore all overrides provided by package'
complete -c lintian -l pedantic -d 'display pedantic ("P:") tags'
complete -c lintian -l profile -d 'use profile from vendor'
complete -c lintian -l show-overrides -d 'show overriden tags'
complete -c lintian -l no-show-overrides -d 'hide overriden tags'
complete -c lintian -l suppress-tags -d 'comma separated list of tags to suppress'
complete -c lintian -l suppress-tags-from-file --force-file -r -d 'read tags to suppress from file'
complete -c lintian -l tag-display-limit -d 'max instances of each tag to emit'

# Configuration
complete -c lintian -l cfg --force-file -r -d 'read configuration from specific file'
complete -c lintian -l no-cfg -d 'do not read any configuration file'
complete -c lintian -l ignore-lintian-env -d 'ignore env vars starting with LINTIAN_'
complete -c lintian -l include-dir --force-file -r -d 'use DIR as additional LINTIAN_BASE'
complete -c lintian -l j -l jobs -d 'parallel job limit'
complete -c lintian -l user-dirs -d 'check user dirs'
complete -c lintian -l no-user-dirs -d 'do not check user dirs'
complete -c lintian -l allow-root -d 'override superuser warning'
complete -c lintian -l packages-from-file --force-file -r -d 'path to file to process'
complete -c lintian -l perf-debug -d 'enable performance debug logging'
