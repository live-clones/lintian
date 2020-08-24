Tag: shared-library-lacks-stack-section
Severity: error
Check: shared-libs
Renamed-From: shlib-without-PT_GNU_STACK-section
Explanation: The listed shared library lacks a PT_GNU_STACK section. This forces
 the dynamic linker to make the stack executable.
 .
 The shared lib is linked either with a non-GNU linker or a linker which is
 very old. This problem can be fixed with a rebuild.
 .
 To see whether a shared library has this section, run <tt>readelf -l</tt>
 on it and look for a program header of type GNU_STACK.
