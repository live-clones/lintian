# -*- perl -*- Lintian::Index::Java
#
# Copyright © 2020 Felix Lechner
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

package Lintian::Index::Java;

use v5.20;
use warnings;
use utf8;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Const::Fast;
use Cwd;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $NEWLINE => qq{\n};
const my $SPACE => q{ };
const my $DASH => q{-};

const my $JAVA_MAGIC_SIZE => 8;
const my $JAVA_MAGIC_BYTES => 0xCAFEBABE;

=head1 NAME

Lintian::Index::Java - java information.

=head1 SYNOPSIS

    use Lintian::Index;

=head1 DESCRIPTION

Lintian::Index::Java java information.

=head1 INSTANCE METHODS

=over 4

=item add_java

=cut

sub add_java {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir)
      or die encode_utf8('Cannot change to directory ' . $self->basedir);

    my $errors = $EMPTY;

    my @files = grep { $_->is_file } @{$self->sorted_list};

    # Wheezy's version of file calls "jar files" for "Zip archive".
    # Newer versions seem to call them "Java Jar file".
    # Jessie also introduced "Java archive data (JAR)"...
    my @java_files = grep {
        $_->file_info=~ m{
            Java [ ] (?:Jar [ ] file|archive [ ] data)
            | Zip [ ] archive
            | JAR }x;
    } @files;

    my @lines;
    for my $file (@java_files) {

        push(@lines, parse_jar($file->name))
          if $file->name =~ /\S+\.jar$/i;
    }

    my $file;
    my $file_list;
    my $manifest = 0;
    local $_ = undef;

    my %java_info;

    for my $line (@lines) {
        chomp $line;
        next if $line =~ /^\s*$/;

        if ($line =~ /^-- ERROR:\s*(\S.+)$/) {
            $java_info{$file}{error} = $1;

        } elsif ($line =~ m{^-- MANIFEST: (?:\./)?(?:.+)$}) {
            # TODO: check $file == $1 ?
            $java_info{$file}{manifest} = {};
            $manifest = $java_info{$file}{manifest};
            $file_list = 0;

        } elsif ($line =~ m{^-- (?:\./)?(.+)$}) {
            $file = $1;
            $java_info{$file}{files} = {};
            $file_list = $java_info{$file}{files};
            $manifest = 0;
        } else {
            if ($manifest && $line =~ m{^  (\S+):\s(.*)$}) {
                $manifest->{$1} = $2;
            } elsif ($file_list) {
                my ($fname, $clmajor) = ($line =~ m{^([^-].*):\s*([-\d]+)$});
                $file_list->{$fname} = $clmajor;
            }
        }
    }

    $_->java_info($java_info{$_->name}) for @java_files;

    chdir($savedir)
      or die encode_utf8("Cannot change to directory $savedir");

    return $errors;
}

=item parse_jar

=cut

sub parse_jar {
    my ($path) = @_;

    my @lines;

    # This script needs unzip, there's no way around.
    push(@lines, "-- $path");

    # Without this Archive::Zip will emit errors to standard error for
    # faulty zip files - but that is not what we want.  AFAICT, it is
    # the only way to get a textual error as well, so (ab)use it for
    # this purpose while we are at it.
    my $errorhandler = sub {
        my ($err) = @_;
        $err =~ s/\r?\n/ /g;

        # trim right
        $err =~ s/\s+$//;

        push(@lines, "-- ERROR: $err");
    };
    my $oldhandler = Archive::Zip::setErrorHandler($errorhandler);

    my $azip = Archive::Zip->new;
    if($azip->read($path) == AZ_OK) {

        # save manifest for the end
        my $manifest;

        # file list comes first
        foreach my $member ($azip->members) {
            my $name = $member->fileName;

            next
              if $member->isDirectory;

            # store for later processing
            $manifest = $member
              if $name =~ m{^META-INF/MANIFEST.MF$}i;

            # add version if we can find it
            my $jversion;
            if ($name =~ /\.class$/) {
                # Collect the Major version of the class file.
                my ($contents, $zerr) = $member->contents;

       # bug in Archive::Zip; seen in android-platform-libcore_10.0.0+r36-1.dsc
                last
                  unless defined $zerr;

                last
                  unless $zerr == AZ_OK;

                # Ensure we can read at least 8 bytes for the unpack.
                next
                  if length $contents < $JAVA_MAGIC_SIZE;

                # translation of the unpack
                #  NN NN NN NN, nn nn, nn nn   - bytes read
                #     $magic  , __ __, $major  - variables
                my ($magic, undef, $major) = unpack('Nnn', $contents);
                $jversion = $major
                  if $magic == $JAVA_MAGIC_BYTES;
            }
            push(@lines, "$name: " . ($jversion // $DASH));
        }

        if ($manifest) {
            push(@lines, "-- MANIFEST: $path");

            my ($contents, $zerr) = $manifest->contents;

       # bug in Archive::Zip; seen in android-platform-libcore_10.0.0+r36-1.dsc
            return ()
              unless defined $zerr;

            if ($zerr == AZ_OK) {
                my $partial = $EMPTY;
                my $first = 1;
                my @list = split($NEWLINE, $contents);
                foreach my $line (@list) {

                    # remove DOS type line feeds
                    $line =~ s/\r//g;

                    if ($line =~ /^(\S+:)\s*(.*)/) {
                        push(@lines, $SPACE . $SPACE . "$1 $2");
                    }
                    if ($line =~ /^ (.*)/) {
                        push(@lines, $1);
                    }
                }
            }
        }
    }

    Archive::Zip::setErrorHandler($oldhandler);

    return @lines;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
