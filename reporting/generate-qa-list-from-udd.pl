#!/usr/bin/perl

# Copyright © 2019 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA

use v5.20;
use warnings;
use utf8;
use autodie;

use DBI;
use Getopt::Long;

use constant EMPTY => q{};
use constant SPACE => q{ };

my $select;
my $debug;

Getopt::Long::Configure('bundling');
unless (
    Getopt::Long::GetOptions(
        'd|debug+'         => \$debug,
        's|select=s'       => \$select,
        'h|help'           => sub {usage(); exit;},
    )
) {
    usage();
    exit 1;
}

# check number of arguments
die('Please use -h for usage information.')
  if @ARGV > 0;

my $source_selector = (length $select ? "s.source=\'$select\'" : 1);

my $source_subquery =<<EOSTR;
SELECT
    s.source,
    t.tag_type,
    t.package_type,
    t.tag,
    t.information,
    s.distribution,
    s.release,
    count(*)
FROM
    public.lintian AS t
INNER JOIN
    public.all_sources AS s
ON
    (t.package=s.source AND t.package_version=s.version)
WHERE
    s.distribution='debian'
AND
    (s.release='sid' OR s.release='experimental')
AND
    t.package_type='source'
AND
    t.package_arch='source'
AND
    t.tag_type<>'classification'
AND
    $source_selector
GROUP BY
    s.source,
    t.tag_type,
    t.package_type,
    t.tag,
    t.information,
    s.distribution,
    s.release
EOSTR

my $source_query =<<EOSTR;
SELECT
    _.source,
    _.tag_type,
    _.package_type,
    _.tag,
    _.information,
    generate_series(1,max(_.count))
FROM
    ($source_subquery) AS _
GROUP BY
    _.source,
    _.tag_type,
    _.package_type,
    _.tag,
    _.information
EOSTR

my $deb_selector = (length $select ? "p.source=\'$select\'" : 1);

my $deb_subquery =<<EOSTR;
SELECT
    p.source,
    t.tag_type,
    t.package_type,
    p.package,
    t.tag,
    t.information,
    t.package_arch,
    p.distribution,
    p.release,
    count(*)
FROM
    public.lintian AS t
INNER JOIN
    public.all_packages AS p
ON
    (t.package=p.package AND t.package_version=p.version AND t.package_arch=p.architecture)
WHERE
    p.distribution='debian'
AND
    (p.release='sid' OR p.release='experimental')
AND
    (t.package_type IN ('binary','udeb'))
AND
    t.tag_type<>'classification'
AND
    $deb_selector
GROUP BY
    p.source,
    t.tag_type,
    t.package_type,
    p.package,
    t.tag,
    t.information,
    t.package_arch,
    p.distribution,
    p.release
EOSTR

my $deb_query =<<EOSTR;
SELECT
    _.source,
    _.tag_type,
    _.package_type,
    _.package,
    _.tag,
    _.information,
    generate_series(1,max(_.count))
FROM
    ($deb_subquery) AS _
GROUP BY
    _.source,
    _.tag_type,
    _.package_type,
    _.package,
    _.tag,
    _.information
EOSTR

my %tagcount;
my $rowcount = 0;

my $dbh = DBI->connect("dbi:Pg:dbname=udd;host=udd-mirror.debian.net",
                    'udd-mirror', 'udd-mirror', {AutoCommit => 0});

my $sourcetags_sth = $dbh->prepare($source_query);
my $debtags_sth = $dbh->prepare($deb_query);

# get all source tags
$sourcetags_sth->execute;

# keep a count for levels by source package
while (my @row = $sourcetags_sth->fetchrow_array) {

    count_tag(\%tagcount, @row);
    $rowcount++;
}

if ($debug) {
    say STDERR "Found $rowcount source tags.";
    say STDERR EMPTY;
}

$rowcount = 0;

# get all binary tags
$debtags_sth->execute;

# keep a count for levels by source package
while (my @row = $debtags_sth->fetchrow_array) {

    count_tag(\%tagcount, @row);
    $rowcount++;
}

if ($debug) {
    say STDERR "Found $rowcount installation tags.";
    say STDERR EMPTY;
}

# print counts per source package
for my $source (sort keys %tagcount) {

    my @counts = map { $tagcount{$source}{$_}//0 } qw{error warning information pedantic experimental overridden};
    say "$source @counts"
}

$dbh->disconnect;

exit;


sub count_tag {
    my ($tagcountref, @row) = @_;

    say STDERR "@row"
      if $debug;

    my $source = $row[0];
    my $tag_type = $row[1];

    $tagcountref->{$source}{$tag_type} = 0
      unless exists $tagcountref->{$source}{$tag_type};

    $tagcountref->{$source}{$tag_type}++;
}

sub usage {
    print <<"END";
Usage: $0 [-d] [-s <source>]

    --select, -s  Select a single source package for processing.
    --debug, -d   Display additional debugging information.

    The option --select generates just one line for the selected source.
END
    return;
}


# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
