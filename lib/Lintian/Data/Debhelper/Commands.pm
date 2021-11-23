# -*- perl -*-
#
# Copyright © 2008 by Raphael Geissert <atomo64@gmail.com>
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
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

package Lintian::Data::Debhelper::Commands;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use File::Basename;
use IPC::Run3;
use List::SomeUtils qw(first_value any uniq);
use JSON::MaybeXS;
use Path::Tiny;
use PerlIO::gzip;
use Time::Piece;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::File;

use Moo;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};

const my $WAIT_STATUS_SHIFT => 8;

=head1 NAME

Lintian::Data::Debhelper::Commands - Lintian interface for debhelper commands.

=head1 SYNOPSIS

    use Lintian::Data::Debhelper::Commands;

=head1 DESCRIPTION

This module provides a way to load data files for debhelper.

=head1 INSTANCE METHODS

=over 4

=item location

=item preamble

=item installable_names_by_command

=item maint_commands

=item misc_depends_commands

=cut

has location => (
    is => 'rw',
    default => 'debhelper/commands.json'
);

has preamble => (is => 'rw');
has installable_names_by_command => (is => 'rw', default => sub { {} });
has maint_commands => (is => 'rw', default => sub { [] });
has misc_depends_commands => (is => 'rw', default => sub { [] });

=item all

=cut

sub all {
    my ($self) = @_;

    return keys %{$self->installable_names_by_command};
}

=item installed_by

=cut

sub installed_by {
    my ($self, $name) = @_;

    return ()
      unless exists $self->installable_names_by_command->{$name};

    my @installed_by = @{$self->installable_names_by_command->{$name} // []};

    push(@installed_by, 'debhelper-compat')
      if any { $_ eq 'debhelper' } @installed_by;

    return @installed_by;
}

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    croak encode_utf8('Unknown data file: ' . $self->location)
      unless length $path;

    my $json = path($path)->slurp;
    my $data = decode_json($json);

    $self->preamble($data->{preamble});

    my %commands = %{$data->{commands} // {}};

    my %installable_names_by_command;
    my @maint_commands;
    my @misc_depends_commands;

    for my $name (keys %commands) {

        my @installable_names;
        push(@installable_names, @{$commands{$name}{installed_by}});

        $installable_names_by_command{$name} = \@installable_names;

        push(@maint_commands, $name)
          if $commands{$name}{uses_autoscript};

        push(@misc_depends_commands, $name)
          if $commands{$name}{uses_misc_depends}
          && $name ne 'dh_gencontrol';
    }

    $self->installable_names_by_command(\%installable_names_by_command);
    $self->maint_commands(\@maint_commands);
    $self->misc_depends_commands(\@misc_depends_commands);

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $basedir) = @_;

    my $work_folder
      = Path::Tiny->tempdir(
        TEMPLATE => 'refresh-debhelper-add-ons-XXXXXXXXXX');

    my $mirror_base = 'https://deb.debian.org/debian';

    # neutral sort order
    local $ENV{LC_ALL} = 'C';

    my $port = 'amd64';

    my %commands;

    my $stderr;
    my $status;

    my @wget_command = qw{/usr/bin/wget --no-verbose};

    for my $architecture ('all', $port) {

        my $file_name = "Contents-$architecture.gz";
        my $local_path = "$work_folder/$file_name";
        my $url = "$mirror_base/dists/sid/main/$file_name";

        say $EMPTY;
        say encode_utf8("Getting $file_name");

        run3([@wget_command, "--output-document=$local_path", $url],
            undef, \$stderr);
        $status = ($? >> $WAIT_STATUS_SHIFT);

        # already in UTF-8
        die $stderr
          if $status;

        open(my $fd, '<:gzip', $local_path)
          or die encode_utf8("Cannot open $local_path.");

        while (my $line = <$fd>) {

            chomp $line;

            my ($path, $finder) = split($SPACE, $line, 2);
            next
              unless length $path
              && length $finder;

            if ($path =~ m{^ usr/bin/ (dh_ \S+) $}x) {

                my $name = $1;

                my @locations = split(m{,}, $finder);
                for my $location (@locations) {

                    my ($section, $installable)= split(m{/}, $location, 2);

                    $commands{$name}{installed_by} //= [];
                    push(@{$commands{$name}{installed_by}}, $installable);
                }

                next;
            }
        }

        close $fd;
    }

    my $packages_filename = 'Packages';
    my $packages_local_path = "$work_folder/$packages_filename";
    my $packages_url = "$mirror_base/dists/sid/main/binary-$port/Packages.gz";

    say $EMPTY;
    say encode_utf8("Getting $packages_filename");

    run3([
            @wget_command, "--output-document=$packages_local_path.gz",
            $packages_url
        ],
        \undef,
        \$stderr
    );

    run3(['gunzip', "$packages_local_path.gz"], \undef, \$stderr);
    $status = ($? >> $WAIT_STATUS_SHIFT);
    # already in UTF-8
    die $stderr
      if $status;

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->read_file($packages_local_path);

    my %section_by_installable_name;
    for my $section (@sections) {

        my $installable_name = $section->value('Package');
        $section_by_installable_name{$installable_name} = $section;
    }

    my @uses_autoscript;
    my @uses_misc_depends;

    my @installable_names= uniq map { @{$_->{installed_by}} }values %commands;

    for my $installable_name (sort @installable_names) {

        my $section = $section_by_installable_name{$installable_name};

        my $pool_path = $section->value('Filename');

        my $deb_filename = basename($pool_path);
        my $deb_local_path = "$work_folder/$deb_filename";
        my $deb_url = "$mirror_base/$pool_path";

        say $EMPTY;
        say encode_utf8("Getting $pool_path");

        run3([@wget_command, "--output-document=$deb_local_path", $deb_url],
            \undef, \$stderr);
        $status = ($? >> $WAIT_STATUS_SHIFT);
        # already in UTF-8
        die $stderr
          if $status;

        my $extract_folder = "$work_folder/pool/$pool_path";
        path($extract_folder)->mkpath;

        run3([qw{dpkg-deb --extract}, $deb_local_path, $extract_folder],
            \undef, \$stderr);
        $status = ($? >> $WAIT_STATUS_SHIFT);
        # already in UTF-8
        die $stderr
          if $status;

        unlink($deb_local_path)
          or die encode_utf8("Cannot delete $deb_local_path");

        my $autoscript_rule = File::Find::Rule->file;
        $autoscript_rule->name(qr{^dh_});
        $autoscript_rule->grep(qr{autoscript});
        my @autoscript_matches
          = $autoscript_rule->in("$extract_folder/usr/bin");

        push(@uses_autoscript, map { basename($_) } @autoscript_matches);

        my $misc_depends_rule = File::Find::Rule->file;
        $misc_depends_rule->name(qr{^dh_});
        $misc_depends_rule->grep(qr{misc:Depends});
        my @misc_depends_matches
          = $misc_depends_rule->in("$extract_folder/usr/bin");

        push(@uses_misc_depends, map { basename($_) } @misc_depends_matches);

        path("$work_folder/pool")->remove_tree;
    }

    $commands{$_}{uses_autoscript} = 1 for @uses_autoscript;

    $commands{$_}{uses_misc_depends} = 1 for @uses_misc_depends;

    my %preamble;
    $preamble{title} = 'Debhelper Commands';
    $preamble{last_update} = gmtime->datetime . 'Z';

    my %all;
    $all{preamble} = \%preamble;
    $all{commands} = \%commands;

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    my $json = $encoder->encode(\%all);

    my $datapath = "$basedir/" . $self->location;
    my $parentdir = path($datapath)->parent->stringify;
    path($parentdir)->mkpath
      unless -e $parentdir;

    # already in UTF-8
    path($datapath)->spew($json);

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
