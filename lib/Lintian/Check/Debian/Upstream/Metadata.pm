# debian/upstream/metadata -- lintian check script -*- perl -*-

# Copyright © 2016 Petter Reinholdtsen
# Copyright © 2020 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Jelmer Vernooĳ
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
# MA 02110-1301, USA.

package Lintian::Check::Debian::Upstream::Metadata;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::Util qw(none);
use YAML::XS;

# default changed to false in 0.81; enable then in .perlcriticrc
$YAML::XS::LoadBlessed = 0;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

# Need 0.69 for $LoadBlessed (#861958)
const my $HAS_LOAD_BLESSED => 0.69;

# taken from https://wiki.debian.org/UpstreamMetadata
my @known_fields = qw(
  Archive
  ASCL-Id
  Bug-Database
  Bug-Submit
  Cite-As
  Changelog
  CPE
  Documentation
  Donation
  FAQ
  Funding
  Gallery
  Other-References
  Reference
  Registration
  Registry
  Repository
  Repository-Browse
  Screenshots
  Security-Contact
  Webservice
);

# tolerated for packages not using DEP-5 copyright
my @tolerated_fields = qw(
  Name
  Contact
);

sub source {
    my ($self) = @_;

    my $file
      = $self->processable->patched->resolve_path('debian/upstream/metadata');

    if ($self->processable->native) {
        $self->hint('upstream-metadata-in-native-source')
          if defined $file;
        return;
    }

    unless (defined $file) {
        $self->hint('upstream-metadata-file-is-missing');
        return;
    }

    $self->hint('upstream-metadata-exists');

    unless ($file->is_open_ok) {
        $self->hint('upstream-metadata-is-not-a-file');
        return;
    }

    return
      if $YAML::XS::VERSION < $HAS_LOAD_BLESSED;

    my $yaml;
    eval { $yaml = YAML::XS::LoadFile($file->unpacked_path); };

    if ($@ || !defined $yaml) {
        my $message = $@;
        my ($reason, $document, $line, $column)= (
            $message =~ m{
                \AYAML::XS::Load\sError:\sThe\sproblem:\n
                \n\s++(.+)\n
                \n
                was\sfound\sat\sdocument:\s(\d+),\sline:\s(\d+),\scolumn:\s(\d+)\n}x
        );

        $message
          = "$reason (at document $document, line $line, column $column)"
          if ( length $reason
            && length $document
            && length $line
            && length $document);

        $self->hint('upstream-metadata-yaml-invalid', $message);

        return;
    }

    unless (ref $yaml eq 'HASH') {
        $self->hint('upstream-metadata-not-yaml-mapping', $file->name);
        return;
    }

    for my $field (keys %{$yaml}) {

        $self->hint('upstream-metadata', $field, $yaml->{$field})
          if ref($yaml->{$field}) eq $EMPTY;
    }

    my $lc
      = List::Compare->new([keys %{$yaml}],[@known_fields, @tolerated_fields]);
    my @invalid_fields = $lc->get_Lonly;

    $self->hint('upstream-metadata-field-unknown', $_)for @invalid_fields;

    $self->hint('upstream-metadata-missing-repository')
      if none { defined $yaml->{$_} } qw(Repository Repository-Browse);
    $self->hint('upstream-metadata-missing-bug-tracking')
      if none { defined $yaml->{$_} } qw(Bug-Database Bug-Submit);

    return;
}

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # here we check old upstream specification
    # debian/upstream should be a directory
    $self->hint('debian-upstream-obsolete-path', $item->name)
      if $item->name eq 'debian/upstream'
      || $item->name eq 'debian/upstream-metadata.yaml';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
