# Copyright © 2019-2020 Felix Lechner
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

package Lintian::Processable::Installable;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use IPC::Run3;
use Unicode::UTF8 qw(encode_utf8 decode_utf8 valid_utf8);

use Lintian::Deb822::File;

use Moo;
use namespace::clean;

with
  'Lintian::Processable::Installable::Class',
  'Lintian::Processable::Installable::Relation',
  'Lintian::Processable::Changelog',
  'Lintian::Processable::Control',
  'Lintian::Processable::Control::Conffiles',
  'Lintian::Processable::Installed',
  'Lintian::Processable::IsNonFree',
  'Lintian::Processable::Hardening',
  'Lintian::Processable::NotJustDocs',
  'Lintian::Processable::Overrides',
  'Lintian::Processable';

# read up to 40kB at a time.  this happens to be 4096 "tar records"
# (with a block-size of 512 and a block factor of 20, which appear to
# be the defaults).  when we do full reads and writes of READ_SIZE (the
# OS willing), the receiving end will never be with an incomplete
# record.
const my $TAR_RECORD_SIZE => 20 * 512;

const my $COLON => q{:};
const my $NEWLINE => qq{\n};
const my $OPEN_PIPE => q{-|};

const my $WAIT_STATUS_SHIFT => 8;

=for Pod::Coverage BUILDARGS

=head1 NAME

Lintian::Processable::Installable -- An installation package Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable::Installable;

 my $processable = Lintian::Processable::Installable->new;
 $processable->init_from_file('path');

=head1 DESCRIPTION

This class represents a 'deb' or 'udeb' file that Lintian can process. Objects
of this kind are often part of a L<Lintian::Group>, which
represents all the files in a changes or buildinfo file.

=head1 INSTANCE METHODS

=over 4

=item init_from_file (PATH)

Initializes a new object from PATH.

=cut

sub init_from_file {
    my ($self, $file) = @_;

    croak encode_utf8("File $file does not exist")
      unless -e $file;

    $self->path($file);

    # get control.tar.gz; dpkg-deb -f $file is slow; use tar instead
    my @dpkg_command = ('dpkg-deb', '--ctrl-tarfile', $self->path);

    my $dpkg_pid = open(my $from_dpkg, $OPEN_PIPE, @dpkg_command)
      or die encode_utf8("Cannot run @dpkg_command: $!");

    # would like to set buffer size to 4096 & $TAR_RECORD_SIZE

    # get binary control file
    my $stdout_bytes;
    my $stderr_bytes;
    my @tar_command = qw{tar --wildcards -xO -f - *control};
    run3(\@tar_command, $from_dpkg, \$stdout_bytes, \$stderr_bytes);
    my $status = ($? >> $WAIT_STATUS_SHIFT);

    if ($status) {

        my $message= "Non-zero status $status from @tar_command";
        $message .= $COLON . $NEWLINE . decode_utf8($stderr_bytes)
          if length $stderr_bytes;

        croak encode_utf8($message);
    }

    close $from_dpkg
      or warn encode_utf8("close failed for handle from @dpkg_command: $!");

    waitpid($dpkg_pid, 0);

    croak encode_utf8('Nationally encoded control data in ' . $self->path)
      unless valid_utf8($stdout_bytes);

    my $stdout = decode_utf8($stdout_bytes);

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->parse_string($stdout);
    croak encode_utf8(
        'Not exactly one section with installable control data in '
          . $self->path)
      unless @sections == 1;

    $self->fields($sections[0]);

    my $name = $self->fields->value('Package');
    my $version = $self->fields->value('Version');
    my $architecture = $self->fields->value('Architecture');
    my $source_name = $self->fields->value('Source');

    my $source_version = $version;

    unless (length $name) {
        $name = $self->guess_name($self->path);
        croak encode_utf8('Cannot determine the name from ' . $self->path)
          unless length $name;
    }

    # source may be left out if same as $name
    $source_name = $name
      unless length $source_name;

    # source probably contains the version in parentheses
    if ($source_name =~ m/(\S++)\s*\(([^\)]+)\)/){
        $source_name = $1;
        $source_version = $2;
    }

    $self->name($name);
    $self->version($version);
    $self->architecture($architecture);
    $self->source_name($source_name);
    $self->source_version($source_version);

    # make sure none of these fields can cause traversal
    $self->tainted(1)
      if $self->name ne $name
      || $self->version ne $version
      || $self->architecture ne $architecture
      || $self->source_name ne $source_name
      || $self->source_version ne $source_version;

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
