# -*- perl -*- Lintian::Index::FileInfo
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

package Lintian::Index::FileInfo;

use strict;
use warnings;
use autodie;

use Cwd;
use IO::Async::Loop;
use IO::Async::Process;
use IO::Async::Routine;
use Path::Tiny;
use Try::Tiny;

use Lintian::Util qw(drop_relative_prefix);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COMMA => q{,};
use constant COLON => q{:};
use constant NEWLINE => qq{\n};
use constant NULL => qq{\0};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::FileInfo - determine file type via magic.

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Index::FileInfo determine file type via magic.

=head1 INSTANCE METHODS

=over 4

=item check_magic

=cut

sub check_magic {
    my ($path, $type) = @_;

    # the file program is regularly wrong here; determine type properly
    return ($path, $type)
      unless $path =~ m/\.gz$/
      && -f $path
      && !-l $path
      && $type !~ m/compressed/;

    open(my $fd, '<', $path)
      or die "Cannot open $path";

    my $size = sysread($fd, my $buffer, 1024);

    close($fd)
      or warn "Cannot close $path";

    # need to read at least 9 bytes
    return ($path, $type)
      unless $size >= 9;

    # translation of the unpack
    #  nn nn ,  NN NN NN NN, nn nn, cc     - bytes read
    #  $magic,  __ __ __ __, __ __, $comp  - variables
    my ($magic, undef, undef, $compression) = unpack('nNnc', $buffer);

    my $text = EMPTY;

    # gzip file magic
    if ($magic == 0x1f8b){

        $text = 'gzip compressed data';

        # 2 for max compression; RFC1952 suggests this is a
        # flag and not a value, hence bit operation
        $text .= COMMA . SPACE . 'max compression'
          if $compression & 2;
    }

    $type .= COMMA . SPACE . $text
      if $text;

    return ($path, $type);
}

=item add_fileinfo

=cut

sub add_fileinfo {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir);

    my $loop = IO::Async::Loop->new;

    my @generatecommand = (
        'xargs', '--null','--no-run-if-empty', 'file',
        '--no-pad', '--print0','--'
    );
    my $generatedone = $loop->new_future;

    my $generate = IO::Async::Process->new(
        command => [@generatecommand],
        stdin => { via => 'pipe_write' },
        stdout => { via => 'pipe_read' },
        on_finish => sub {
            # ignore failures; file returns non-zero on parse errors
            # output then contains "ERROR" messages but is still usable

            $generatedone->done('Done with @generatecommand');
            return;
        });

    my %fileinfo;

    $generate->stdout->configure(
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            while($$buffref =~ s/^([^\0]*)\x00: (.*)\n//) {

                my $path = $1;
                my $type = $2;

                unless(length $path && length $type) {
                    $generatedone->fail(
                        "syntax error in file-info output: '$path' '$type'");

                    next;
                }

                ($path, $type) = check_magic($path, $type);

                # remove relative prefix, if present
                $path = drop_relative_prefix($path);

                $fileinfo{$path} = $type;
            }

            return 0;
        },
    );

    $loop->add($generate);

    # get the regular files in the index
    my @files = grep { $_->is_file } $self->sorted_list;

    $generate->stdin->write($_ . NULL) for @files;

    $generate->stdin->close_when_empty;
    $generatedone->get;

    $_->file_info($fileinfo{$_->name}) for @files;

    chdir($savedir);

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
