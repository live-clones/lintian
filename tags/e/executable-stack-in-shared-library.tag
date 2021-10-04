Tag: executable-stack-in-shared-library
Severity: warning
Check: libraries/shared/stack
Renamed-From:
 shlib-with-executable-stack
Explanation: The listed shared library declares the stack as executable.
 .
 Executable stack is usually an error as it is only needed if the code
 contains GCC trampolines or similar constructs which uses code on the
 stack. One possible source for false positives are object files built
 from assembler files which don't define a proper .note.GNU-stack
 section.
 .
 To see the permissions on the stack, run <code>readelf -l</code> on the
 shared library and look for the program header of type GNU&lowbar;STACK. In the
 flag column, there should not be an E flag set.
