# -*- perl -*- Lintian::Processable::Changelog -- access to collected changelog data
#
# Copyright © 1998 Richard Braakman
# Copyright © 2019-2020 Felix Lechner
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

package Lintian::Processable::Changelog;

use v5.20;
use warnings;
use utf8;

use File::Copy qw(copy);
use List::SomeUtils qw(first_value);
use Path::Tiny;
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Changelog - access to collected changelog data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Changelog provides an interface to changelog data.

=head1 INSTANCE METHODS

=over 4

=item changelog_path

=cut

has changelog_path => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        if ($self->type eq 'source') {

            my $file = $self->patched->resolve_path('debian/changelog');
            return
              unless $file && $file->is_open_ok;

            return $file->unpacked_path;
        }

        # pick the first existing file
        my @changelogfiles = (
            'changelog.Debian.gz','changelog.Debian',
            'changelog.debian.gz','changelog.debian',
            'changelog.gz','changelog',
        );

        my $packagepath = 'usr/share/doc/' . $self->name;
        my @candidatepaths = grep { defined }
          map { $self->installed->lookup("$packagepath/$_") } @changelogfiles;
        my $packagechangelogpath
          = first_value { $_->is_file || length $_->link } @candidatepaths;

        return
          unless defined $packagechangelogpath;

        # stop for dangling symbolic link
        my $resolved = $packagechangelogpath->resolve_path;
        return
          unless defined $resolved;

        my $changelogpath;
        if ($packagechangelogpath->basename =~ /\.gz$/) {

            my $contents
              = decode_utf8(safe_qx('gunzip', '-c', $resolved->unpacked_path));

            $changelogpath
              = path($self->basedir)->child('changelog')->stringify;

            path($changelogpath)->spew_utf8($contents);

        } else {
            $changelogpath = $resolved->unpacked_path;
        }

        if ($packagechangelogpath->basename !~ m/changelog\.debian/i) {

            # Either this is a native package OR a non-native package where the
            # debian changelog is missing.  checks/changelog is not too happy
            # with the latter case, so check looks like a Debian changelog.
            my @lines = path($changelogpath)->lines;
            my $ok = 0;
            for my $line (@lines) {
                next if $line =~ /^\s*+$/;
                # look for something like
                # lintian (2.5.3) UNRELEASED; urgency=low
                if ($line
                    =~ /^\S+\s*\([^\)]+\)\s*(?:UNRELEASED|(?:[^ \t;]+\s*)+)\;/)
                {
                    $ok = 1;
                }
                last;
            }
            # Remove it if it not the Debian changelog.
            unless ($ok) {
                unlink $changelogpath
                  or die encode_utf8("Cannot unlink $changelogpath");

                undef $changelogpath;
            }
        }

        return
          unless defined $changelogpath;

        return $changelogpath;
    });

=item changelog

For binary:

Returns the changelog of the binary package as a Parse::DebianChangelog
object, or an empty object if the changelog doesn't exist.  The changelog-file
collection script must have been run to create the changelog file, which
this method expects to find in F<changelog>.

For source:

Returns the changelog of the source package as a Parse::DebianChangelog
object, or an empty object if the changelog cannot be resolved safely.

=cut

has changelog => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $changelog = Lintian::Inspect::Changelog->new;

        my $dch = $self->changelog_path;
        return $changelog
          unless $dch;

        my $bytes = path($dch)->slurp;
        return $changelog
          unless valid_utf8($bytes);

        $changelog->parse(decode_utf8($bytes));

        return $changelog;
    });

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
