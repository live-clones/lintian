#! /usr/bin/perl -w

package common_data;
use base qw(Exporter);

our @EXPORT = qw
(
   %known_source_fields $known_shells_regex
);

# To let "perl -cw" test know we use these variables;
use vars qw
(
  %known_source_fields $known_shells_regex
);

# simple defines for commonly needed data

# The Ubuntu original-maintainer field is handled separately.
%known_source_fields = map { $_ => 1 }
    ('source', 'version', 'maintainer', 'binary', 'architecture',
     'standards-version', 'files', 'build-depends', 'build-depends-indep',
     'build-conflicts', 'build-conflicts-indep', 'format', 'origin',
     'uploaders', 'python-version', 'autobuild', 'homepage', 'vcs-arch',
     'vcs-bzr', 'vcs-cvs', 'vcs-darcs', 'vcs-git', 'vcs-hg', 'vcs-mtn',
     'vcs-svn', 'vcs-browser', 'dm-upload-allowed', 'bugs', 'checksums-sha1',
     'checksums-sha256', 'checksums-md5');

$known_shells_regex = qr'(?:(?:b|d)?a|t?c|(?:pd|m)?k|z)?sh';

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround
