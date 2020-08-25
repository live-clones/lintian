Tag: portable-executable-missing-security-features
Severity: pedantic
Check: pe
Experimental: yes
Explanation: A portable executable (PE32+) file lacks security features.
 .
 Due to changes in <code>binutils-mingw-w64</code> the historical
 advice is incorrect. Current tools do not create safe binaries,
 and advertising such settings with <code>genpeimg</code> is pointless.
 .
 In short, the flags alone do nothing unless a binary is built
 specifically to support a missing flag. Merely setting the flag,
 as recommended below, can actually make a file less secure.
 .
 More information can be found via the link in the references.
 .
 The following advice is historical. PLEASE DO NOT FOLLOW IT.
 .
 The package ships a Microsoft Windows Portable Executable (PE) file
 that appears to be lacking security hardening features. You can see
 which are missing using the <code>pesec</code> tool from the
 <code>pev</code> package.
 .
 EFI binaries also often trigger this tag. The security flags are
 probably meaningless for them, but the flags are easily changed
 using the <code>genpeimg</code> tool from the <code>mingw-w64-tools</code>
 package.
 .
     $ genpeimg -d +d -d +n -d +s $file
 .
 Then, to verify that it worked:
 .
     $ genpeimg -x $file
     ...
     Optional Characteristics:
       dynamic-base nx-compatible no-SEH
 .
 Please change the flags, if possible, instead of overriding the tag.
 .
See-Also: https://www.kb.cert.org/vuls/id/307144/, Bug#953212
