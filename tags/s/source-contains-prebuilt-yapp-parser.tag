Tag: source-contains-prebuilt-yapp-parser
Severity: pedantic
Check: languages/perl/yapp
Explanation: The source tarball contains a prebuilt Parse::Yapp parser.
 This is usually left by mistake when generating the tarball without
 first cleaning the source directory. You may want to report this as
 an upstream bug if there is no sign that this was intended.
 .
 Please build the parser from source.
See-Also: Bug#921080
