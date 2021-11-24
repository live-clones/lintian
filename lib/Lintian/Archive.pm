# Copyright © 2021 Felix Lechner
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

package Lintian::Archive;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use IPC::Run3;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

const my $SLASH => q{/};

const my $WAIT_STATUS_SHIFT => 8;

=head1 NAME

Lintian::Archive -- Facilities for archive data

=head1 SYNOPSIS

use Lintian::Archive;

=head1 DESCRIPTION

A class for downloading and accessing archive information

=head1 INSTANCE METHODS

=over 4

=item mirror_base

=item work_folder

=item packages

=cut

has mirror_base => (is => 'rw', default => 'https://deb.debian.org/debian');

has work_folder => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $work_folder
          = Path::Tiny->tempdir(TEMPLATE => 'lintian-archive-XXXXXXXXXX');

        return $work_folder;
    });

has packages => (is => 'rw', default => sub { {} });

=item contents_gz

=cut

sub contents_gz {
    my ($self, $release, $archive_liberty, $installable_architecture) = @_;

    my $relative
      = "$release/$archive_liberty/Contents-$installable_architecture.gz";
    my $local_path = $self->work_folder . $SLASH . $relative;

    return $local_path
      if -e $local_path;

    path($local_path)->parent->mkpath;

    my $url = $self->mirror_base . "/dists/$relative";

    my $stderr;
    run3([qw{wget --quiet}, "--output-document=$local_path", $url],
        undef, \$stderr);
    my $status = ($? >> $WAIT_STATUS_SHIFT);

    # stderr already in UTF-8
    die $stderr
      if $status;

    return $local_path;
}

=item deb822_packages_by_installable_name

=cut

sub deb822_packages_by_installable_name {
    my ($self, $release, $archive_liberty, $port) = @_;

    return $self->packages->{$release}{$archive_liberty}{$port}
      if exists $self->packages->{$release}{$archive_liberty}{$port};

    my $relative_unzipped = "$release/$archive_liberty/binary-$port/Packages";
    my $local_path = $self->work_folder . $SLASH . $relative_unzipped;

    path($local_path)->parent->mkpath;

    my $url = $self->mirror_base . "/dists/$relative_unzipped.gz";

    my $stderr;

    run3([qw{wget --quiet}, "--output-document=$local_path.gz", $url],
        undef, \$stderr);
    my $status = ($? >> $WAIT_STATUS_SHIFT);

    # stderr already in UTF-8
    die $stderr
      if $status;

    run3(['gunzip', "$local_path.gz"], undef, \$stderr);
    $status = ($? >> $WAIT_STATUS_SHIFT);

    # stderr already in UTF-8
    die $stderr
      if $status;

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->read_file($local_path);

    unlink($local_path)
      or die encode_utf8("Cannot delete $local_path");

    my %section_by_installable_name;
    for my $section (@sections) {

        my $installable_name = $section->value('Package');
        $section_by_installable_name{$installable_name} = $section;
    }

    $self->packages->{$release}{$archive_liberty}{$port}
      = \%section_by_installable_name;

    return \%section_by_installable_name;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
