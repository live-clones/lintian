#!/usr/bin/perl

# Helper script to generate d/config from d/templates.
# It is just here to make sure all templates are "used".

use strict;
use warnings;

use lib "$ENV{'LINTIAN_TEST_ROOT'}/lib";
use Lintian::Deb822Parser qw(visit_dpkg_paragraph :constants);

print <<EOF ;
#!/bin/sh

set -e

. /usr/share/debconf/confmodule

EOF

visit_dpkg_paragraph (\&pg, \*STDIN, DCTRL_DEBCONF_TEMPLATE);

exit 0;

sub pg {
    my ($paragraph) = @_;
    my $template = $paragraph->{'template'};
    # Some of them will not have a name, so skip those.
    return unless $template;
    print "db_input high $template || true\n";
    print "db_go\n\n";
}
