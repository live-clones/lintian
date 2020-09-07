Tag: unused-debconf-template
Severity: info
Check: debian/debconf
Explanation: Templates which are not used by the package should be removed from
 the templates file.
 .
 This will reduce the size of the templates database and prevent
 translators from unnecessarily translating the template's text.
 .
 In some cases, the template is used but Lintian is unable to determine
 this. Common causes are:
 .
 - the maintainer scripts embed a variable in the template name in
 order to allow a template to be selected from a range of similar
 templates (e.g. <code>db&lowbar;input low start&lowbar;$service&lowbar;at&lowbar;boot</code>)
 .
 - the template is not used by the maintainer scripts but is used by
 a program in the package
 .
 - the maintainer scripts are written in perl. Lintian currently only
 understands the shell script debconf functions.
 .
 If any of the above apply, please install an override.
