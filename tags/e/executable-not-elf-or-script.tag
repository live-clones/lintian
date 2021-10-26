Tag: executable-not-elf-or-script
Severity: warning
Check: executable
Explanation: This executable file is not an ELF format binary, and does not start
 with the #! sequence that marks interpreted scripts. It might be a sh
 script that fails to name /bin/sh as its shell, or it may be incorrectly
 marked as executable. Sometimes upstream files developed on Windows are
 marked unnecessarily as executable on other systems.
 .
 If you are using debhelper to build your package, running dh&lowbar;fixperms will
 often correct this problem for you.
See-Also:
 policy 10.4
