#!/usr/bin/perl

use strict;
use warnings;

use Syntax::Keyword::Try;
use Test::More;

use Lintian::Deb822;

my %TESTS_BAD = (
    'pgp-sig-before-start' => qr/PGP signature before message/,
    'pgp-two-signatures' => qr/Found two PGP signatures/,
    'pgp-unexpected-header' => qr/Unexpected .+ header/,
    'pgp-malformed-header' => qr/Malformed PGP header/,

    'pgp-two-signed-msgs' => qr/Multiple PGP messages/,
    'pgp-no-end-pgp-header' => qr/Cannot find END PGP SIGNATURE/,
    'pgp-leading-unsigned' => qr/Expected PGP MESSAGE header/,
    'pgp-trailing-unsigned' => qr/Data after PGP SIGNATURE/,
    'pgp-eof-missing-sign' => qr/Cannot find BEGIN PGP SIGNATURE/,
);

my $DATADIR = $0;
$DATADIR =~ s{[^/]+$}{};
if ($DATADIR) {
    # invoked in some other dir
    $DATADIR = "$DATADIR/data";
} else {
    # current dir
    $DATADIR = 'data';
}

plan skip_all => 'Data files not available'
  unless -d $DATADIR;

plan tests => scalar keys %TESTS_BAD;

for my $filename (sort keys %TESTS_BAD) {

    my $path = "$DATADIR/$filename";

    my $deb822 = Lintian::Deb822->new;

    try {
        $deb822->read_file($path);

    } catch {
        my $error = $@;

        my $fail_regex = $TESTS_BAD{$filename};
        like($error, $fail_regex, $filename);

        next;
    }

    fail("$path was parsed successfully");
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
