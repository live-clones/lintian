#!/usr/bin/perl

use strict;
use warnings;
use autodie;

use Test::More;

use Lintian::Util qw(visit_dpkg_paragraph);

my $syntax_error = qr/syntax error at line \d+/;
my %TESTS_BAD = (
#<<< no perl tidy (TODO: lines slightly too long)
    'pgp-sig-before-start' => qr/${syntax_error}: PGP signature seen before start of signed message/,
    'pgp-two-signatures' => qr/${syntax_error}: Two PGP signatures \(first one at line \d+\)/,
    'pgp-unexpected-header' => qr/${syntax_error}: Unexpected .+ header/,
    'pgp-malformed-header' => qr/${syntax_error}: Malformed PGP header/,

    'pgp-two-signed-msgs' => qr/${syntax_error}: Expected at most one signed message \(previous at line \d+\)/,
    'pgp-no-end-pgp-header' => qr/${syntax_error}: End of file but expected a "END PGP SIGNATURE" header/,
    'pgp-leading-unsigned' => qr/${syntax_error}: PGP MESSAGE header must be first content if present/,
    'pgp-trailing-unsigned' => qr/${syntax_error}: Data after the PGP SIGNATURE/,
    'pgp-eof-missing-sign' => qr/${syntax_error}: End of file before "BEGIN PGP SIGNATURE"/,
#<<<
);

my $DATADIR = $0;
$DATADIR =~ s,[^/]+$,,o;
if ($DATADIR) {
    # invokved in some other dir
    $DATADIR = "$DATADIR/data";
} else {
    # current dir
    $DATADIR = 'data';
}

plan skip_all => 'Data files not available'
  unless -d $DATADIR;

plan tests => scalar keys %TESTS_BAD;

foreach my $filename (sort keys %TESTS_BAD) {
    my $fail_regex = $TESTS_BAD{$filename};
    my $path = "$DATADIR/$filename";
    open(my $fd, '<', $path);
    eval {
        visit_dpkg_paragraph(sub {}, $fd);
    };
    close($fd);
    if (my $err = $@) {
        like($err, $fail_regex, $filename);
    } else {
        fail("$path was parsed successfully");
    }
}

