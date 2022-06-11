# -*- perl -*-
#
# Copyright (C) 2008, 2010 by Raphael Geissert <atomo64@gmail.com>
# Copyright (C) 2017 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Data::InitD::VirtualFacilities;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use IPC::Run3;
use List::SomeUtils qw(first_value uniq);
use Path::Tiny;
use PerlIO::gzip;
use Unicode::UTF8 qw(encode_utf8);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $DOLLAR => q{$};

const my $NEWLINE => qq{\n};

const my $WAIT_STATUS_SHIFT => 8;

use Moo;
use namespace::clean;

with 'Lintian::Data::JoinedLines';

=head1 NAME

Lintian::Data::InitD::VirtualFacilities - Lintian interface for init.d virtual facilities

=head1 SYNOPSIS

    use Lintian::Data::InitD::VirtualFacilities;

=head1 DESCRIPTION

This module provides a way to load data files for init.d.

=head1 INSTANCE METHODS

=over 4

=item title

=item location

=item separator

=cut

has title => (
    is => 'rw',
    default => 'Init.d Virtual Facilities'
);

has location => (
    is => 'rw',
    default => 'init.d/virtual_facilities'
);

has separator => (
    is => 'rw',
    default => sub { qr{ \s+ }x }
);

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    # neutral sort order
    local $ENV{LC_ALL} = 'C';

    my $port = 'amd64';

    my %paths_by_installable_names;

    for my $installable_architecture ('all', $port) {

        my $local_path
          = $archive->contents_gz('sid', 'main', $installable_architecture);

        open(my $fd, '<:gzip', $local_path)
          or die encode_utf8("Cannot open $local_path.");

        while (my $line = <$fd>) {

            chomp $line;

            my ($path, $finder) = split($SPACE, $line, 2);
            next
              unless length $path
              && length $finder;

            # catch both monolithic and split configurations
            if ($path =~ m{^ etc/insserv[.]conf (?: $ | [.]d / )? }x) {

                my @locations = split(m{,}, $finder);
                for my $location (@locations) {

                    my ($section, $installable)= split(m{/}, $location, 2);

                    $paths_by_installable_names{$installable} //= [];
                    push(@{$paths_by_installable_names{$installable}}, $path);
                }

                next;
            }
        }

        close $fd;
    }

    my $deb822_by_installable_name
      = $archive->deb822_packages_by_installable_name('sid', 'main', $port);

    my $work_folder
      = Path::Tiny->tempdir(
        TEMPLATE => 'refresh-debhelper-add-ons-XXXXXXXXXX');

    my @virtual_facilities;

    my @installable_names = keys %paths_by_installable_names;

    for my $installable_name (sort @installable_names) {

        next
          unless exists $deb822_by_installable_name->{$installable_name};

        my $deb822 = $deb822_by_installable_name->{$installable_name};

        my $pool_path = $deb822->value('Filename');

        my $deb_filename = basename($pool_path);
        my $deb_local_path = "$work_folder/$deb_filename";
        my $deb_url = $archive->mirror_base . $SLASH . $pool_path;

        my $stderr;
        run3(
            [qw{wget --quiet}, "--output-document=$deb_local_path", $deb_url],
            undef, \$stderr
        );
        my $status = ($? >> $WAIT_STATUS_SHIFT);

        # stderr already in UTF-8
        die $stderr
          if $status;

        my $extract_folder = "$work_folder/pool/$pool_path";
        path($extract_folder)->mkpath;

        run3([qw{dpkg-deb --extract}, $deb_local_path, $extract_folder],
            undef, \$stderr);
        $status = ($? >> $WAIT_STATUS_SHIFT);

        # stderr already in UTF-8
        die $stderr
          if $status;

        unlink($deb_local_path)
          or die encode_utf8("Cannot delete $deb_local_path");

        my $monolithic_rule = File::Find::Rule->file;
        $monolithic_rule->name('insserv.conf');
        my @files= $monolithic_rule->in("$extract_folder/etc");

        my $split_files_rule = File::Find::Rule->file;
        push(@files,
            $split_files_rule->in("$extract_folder/etc/insserv.conf.d"));

        for my $path (@files) {

            open(my $fd, '<', $path)
              or die encode_utf8("Cannot open $path.");

            while (my $line = <$fd>) {

                if ($line =~ m{^ ( \$\S+ ) }x) {

                    my $virtual = $1;
                    push(@virtual_facilities, $virtual);
                }
            }

            close $fd;
        }

        path("$work_folder/pool")->remove_tree;
    }

    push(@virtual_facilities, $DOLLAR . 'all');

    my $generated = $EMPTY;

    # still in UTF-8
    $generated .= $_ . $NEWLINE for sort +uniq @virtual_facilities;

    my $header =<<"HEADER";
# The list of known virtual facilities that init scripts may depend on.
#

HEADER

    my $data_path = "$basedir/" . $self->location;
    my $parent_dir = path($data_path)->parent->stringify;
    path($parent_dir)->mkpath
      unless -e $parent_dir;

    my $output = encode_utf8($header) . $generated;
    path($data_path)->spew($output);

    return 1;
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
