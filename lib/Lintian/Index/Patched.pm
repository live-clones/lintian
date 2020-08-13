# -*- perl -*- Lintian::Index::Patched
#
# Copyright © 2020 Felix Lechner
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

package Lintian::Index::Patched;

use v5.20;
use warnings;
use utf8;
use autodie;

use Cwd;
use IPC::Run3;
use Path::Tiny;

use Lintian::Index::Item;
use Lintian::IPC::Run3 qw(safe_qx);

use constant EMPTY => q{};
use constant COLON => q{:};
use constant SLASH => q{/};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Index',
  'Lintian::Index::FileInfo',
  'Lintian::Index::Java',
  'Lintian::Index::Md5sums';

=encoding utf-8

=head1 NAME

Lintian::Index::Patched -- An index of a patched file set

=head1 SYNOPSIS

 use Lintian::Index::Patched;

 # Instantiate via Lintian::Index::Patched
 my $orig = Lintian::Index::Patched->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
patched file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4

=item collect

=cut

sub collect {
    my ($self, $groupdir) = @_;

    # source packages can be unpacked anywhere; no anchored roots
    my $basedir = path($groupdir)->child('unpacked')->stringify;
    $self->basedir($basedir);

    $self->create($groupdir);
    $self->load;

    $self->add_md5sums;
    $self->add_fileinfo;
    $self->add_java;

    return;
}

=item create

=cut

sub create {
    my ($self, $groupdir) = @_;

    my $savedir = getcwd;

    path($self->basedir)->remove_tree
      if -d $self->basedir;

    print "N: Using dpkg-source to unpack\n"
      if $ENV{'LINTIAN_DEBUG'};

    my $saved_umask = umask;
    umask 0000;

    my @unpack_command = (qw(dpkg-source -q --no-check --extract),
        "$groupdir/dsc", $self->basedir);

    # ignore STDOUT; older versions are not completely quiet with -q
    my $unpack_error;

    run3(\@unpack_command, undef, undef, \$unpack_error);

    my $status = ($? >> 8);
    if ($status) {
        my $message = "Non-zero status $status from @unpack_command";
        $message .= COLON . NEWLINE . $unpack_error
          if length $unpack_error;

        die $message;
    }

    umask $saved_umask;

    path("$groupdir/unpacked-errors")->append($unpack_error // EMPTY);

    # chdir for index_src
    chdir($self->basedir);

    # get times in UTC
    my $output
      = safe_qx('env', 'TZ=UTC', 'find', '-printf', '%M %s %A+\0%p\0%l\0');

    my $permissionspattern = qr,\S{10},;
    my $sizepattern = qr,\d+,;
    my $datepattern = qr,\d{4}-\d{2}-\d{2},;
    my $timepattern = qr,\d{2}:\d{2}:\d{2}\.\d+,;
    my $pathpattern = qr,[^\0]*,;

    my %all;

    $output =~ s/\0$//;

    my @lines = split(/\0/, $output, -1);
    die 'Did not get a multiple of three lines from find.'
      unless @lines % 3 == 0;

    while(defined(my $first = shift @lines)) {

        my $entry = Lintian::Index::Item->new;

        $first
          =~ /^($permissionspattern)\ ($sizepattern)\ ($datepattern)\+($timepattern)$/s;

        $entry->perm($1);
        $entry->size($2);
        $entry->date($3);
        $entry->time($4);

        my $name = shift @lines;

        my $linktarget = shift @lines;

        # for non-links, string is empty
        $entry->link($linktarget)
          if length $linktarget;

        # find prints single dot for base; removed in next step
        $name =~ s{^\.$}{\./}s;

        # strip relative prefix
        $name =~ s{^\./+}{}s;

        # make sure directories end with a slash, except root
        $name .= SLASH
          if length $name
          && $entry->perm =~ /^d/
          && substr($name, -1) ne SLASH;
        $entry->name($name);

        $all{$entry->name} = $entry;
    }

    $self->catalog(\%all);

    # fix permissions
    safe_qx('chmod', '-R', 'u+rwX,o+rX,o-w', $self->basedir);

    chdir($savedir);

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.
Substantial portions adapted from code written by Russ Allbery, Niels Thykier, and others.

=head1 SEE ALSO

lintian(1)

L<Lintian::Index>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
