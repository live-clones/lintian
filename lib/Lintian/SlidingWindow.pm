# -*- perl -*-

# Copyright (C) 2013 Bastien ROUCARIES
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

package Lintian::SlidingWindow;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

const my $DEFAULT_BLOCK_SIZE => 4096;
const my $EMPTY => q{};

has handle => (is => 'rw');
has blocksize => (is => 'rw', default => $DEFAULT_BLOCK_SIZE);
has blocknumber => (is => 'rw', default => -1);
has blocksub => (is => 'rw', default => undef);
has _queue => (is => 'rw', default =>  sub {[q{}, q{}]});

sub readwindow {
    my ($self) = @_;
    my $window;

    my $first = $self->blocknumber < 0;
    {
        # This path is too hot for autodie at its current performance
        # (at the time of writing, that would be autodie/2.23).
        # - Benchmark chromium-browser/32.0.1700.123-2/source
        no autodie qw(read);
        my $blocksize = $self->blocksize;
        # Read twice the amount in the first window and split that
        # into "two parts".  That way we avoid half a block followed
        # by a full block with the first half being identical to the
        # previous one.
        $blocksize *= 2 if $first;
        my $res = read($self->handle, $window, $blocksize);
        if (not $res) {
            die encode_utf8("read failed: $!\n") unless defined($res);
            return;
        }
    }

    if(defined($self->blocksub)) {
        local $_ = $window;
        $self->blocksub->();
        $window = $_;
    }

    $self->blocknumber($self->blocknumber + 1);

    if ($first && $self->blocksize < length($window)) {
        # Split the first block into two windows.  We assume here that
        # if the two halves are not of equal length, then it is
        # because the file is shorter than 2*blocksize.  In this case,
        # make the second half the shorter (it shouldn't matter and it
        # is easier to do this way).
        my $blocksize = $self->blocksize;
        $self->_queue->[0] = substr($window, 0, $blocksize);
        $self->_queue->[1] = substr($window, $blocksize);
        return $window;
    }
    shift(@{$self->_queue});
    push(@{$self->_queue}, $window);
    return join($EMPTY, @{$self->_queue});
}

=head1 NAME

Lintian::SlidingWindow - Lintian interface to sliding window match

=head1 SYNOPSIS

    use Lintian::SlidingWindow;

    my $sfd = Lintian::SlidingWindow->new('<','someevilfile.c', sub { $_ = lc($_); });
    my $window;
    while ($window = $sfd->readwindow) {
       if (index($window, 'evil') > -1) {
           if($window =~
                 m/software \s++ shall \s++
                   be \s++ used \s++ for \s++ good \s*+ ,?+ \s*+
                   not \s++ evil/xsim) {
              # do something like : tag 'license-problem-json-evil';
           }
       }
    }

=head1 DESCRIPTION

Lintian::SlidingWindow provides a way of matching some pattern,
including multi line pattern, without needing to fully load the
file in memory.

=head1 CLASS METHODS

=over 4

=item new(HANDLE[, BLOCKSUB[, BLOCKSIZE]])

Create a new sliding window by reading from a given HANDLE, which must
be open for reading. Optionally run BLOCKSUB against each block. Note
that BLOCKSUB should apply transform byte by byte and does not depend
of context.

Each window consists of up to two blocks of BLOCKSIZE characters.

=back

=head1 INSTANCE METHODS

=over 4

=item readwindow

Return a new block of sliding window. Return undef at end of file.

=item C<blocksize>

=item blocknumber

=item handle

=item blocksub

=back

=head1 DIAGNOSTICS

=over 4

=item no data type specified

=back

=head1 AUTHOR

Originally written by Bastien ROUCARIES for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
