# group-checks -- lintian check script -*- perl -*-

# Copyright © 2011 Niels Thykier <niels@thykier.net>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
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

package Lintian::group_checks;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(any);

use Lintian::Data;
use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $KNOWN_DBG_PACKAGE = Lintian::Data->new('common/dbg-pkg',qr/\s*\~\~\s*/,
    sub { return qr/$_[0]/xms; });

sub source {
    my ($self) = @_;

    my $group = $self->group;

    ## To find circular dependencies, we will first generate Strongly
    ## Connected Components using Tarjan's algorithm
    ##
    ## We are not using DepMap, because it cannot tell how the circles
    ## are made - only that there exists at least 1 circle.

    # The packages a.k.a. nodes
    my (@nodes, %edges, $sccs);
    my @procs = $group->get_processables('binary');

    $self->check_file_overlap(@procs);

    foreach my $processable (@procs) {
        my $deps = $group->direct_dependencies($processable);
        if (scalar @$deps > 0) {
            # it depends on another package - it can cause
            # a circular dependency
            my $pname = $processable->name;
            push @nodes, $pname;
            $edges{$pname} = [map { $_->name } @$deps];
            $self->check_multiarch($processable, $deps);
        }
    }

    # Bail now if we do not have at least two packages depending
    # on some other package from this source.
    return if scalar @nodes < 2;

    $sccs = Lintian::group_checks::Graph->new(\@nodes, \%edges)->tarjans;

    foreach my $comp (@$sccs) {
        # It takes two to tango... erh. make a circular dependency.
        next if scalar @$comp < 2;
        $self->tag('intra-source-package-circular-dependency', sort @$comp);
    }

    return;
}

sub check_file_overlap {
    my ($self, @procs) = @_;
    # Sort them for stable output
    my @sorted = sort { $a->name cmp $b->name } @procs;
    for (my $i = 0 ; $i < scalar @sorted ; $i++) {
        my $processable = $sorted[$i];

        my @p = grep { $_ } split(/,/, $processable->field('provides', ''));
        my $prov
          = Lintian::Relation->new(join(' |̈́ ', $processable->name, @p));
        for (my $j = $i ; $j < scalar @sorted ; $j++) {
            my $other = $sorted[$j];

            my @op = grep { $_ } split(/,/, $other->field('provides', ''));
            my $oprov= Lintian::Relation->new(join(' | ', $other->name, @op));
            # poor man's "Multi-arch: same" work-around.
            next if $processable->name eq $other->name;

            # $other conflicts/replaces with $processable
            next if $other->relation('conflicts')->implies($prov);
            next if $other->relation('replaces')->implies($processable->name);

            # $processable conflicts/replaces with $other
            next if $processable->relation('conflicts')->implies($oprov);
            next if $processable->relation('replaces')->implies($other->name);

            $self->overlap_check($processable, $processable, $other, $other);
        }
    }
    return;
}

sub overlap_check {
    my ($self, $a_proc, $a_info, $b_proc, $b_info) = @_;
    foreach my $a_file ($a_info->installed->sorted_list) {
        my $name = $a_file->name;
        my $b_file;
        $name =~ s,/$,,;
        $b_file = $b_info->installed->lookup($name)
          // $b_info->installed->lookup("$name/");
        if ($b_file) {
            next if $a_file->is_dir and $b_file->is_dir;
            $self->tag('binaries-have-file-conflict',
                $a_proc->name,$b_proc->name, $name);
        }
    }
    return;
}

sub check_multiarch {
    my ($self, $processable, $deps) = @_;

    my $ma = $processable->field('multi-arch', 'no');
    if ($ma eq 'same') {
        foreach my $dep (@$deps) {
            my $dma = $dep->field('multi-arch', 'no');
            if ($dma eq 'same' or $dma eq 'foreign') {
                1; # OK
            } else {
                $self->tag(
                    'dependency-is-not-multi-archified',
                    join(q{ },
                        $processable->name, 'depends on',
                        $dep->name, "(multi-arch: $dma)"));
            }
        }
    } elsif ($ma ne 'same'
        and $processable->field('section', 'none') =~ m,(?:^|/)debug$,) {
        # Debug package that isn't M-A: same, exploit that (non-debug)
        # dependencies is (almost certainly) a package for which the
        # debug carries debug symbols.
        foreach my $dep (@$deps) {
            my $dma = $dep->field('multi-arch', 'no');
            if (    $dma eq 'same'
                and $dep->field('section', 'none') !~ m,(?:^|/)debug$,){

                # Debug package isn't M-A: same, but depends on a
                # package that is from same source that isn't a debug
                # package and that is M-A same.  Thus it is not
                # possible to install debug symbols for all
                # (architecture) variants of the binaries.
                $self->tag(
                    'debug-package-for-multi-arch-same-pkg-not-coinstallable',
                    $processable->name . ' => ' . $dep->name
                  )
                  unless any { $processable->name =~ m/$_/xms }
                $KNOWN_DBG_PACKAGE->all;
            }
        }
    }
    return;
}

## Encapsulate Tarjan's algorithm in a class/object to keep
## the run sub somewhat sane.  Allow this "extra" package as
## it is not a proper subclass.
#<<< no Perl tidy (it breaks the no critic comment)
package Lintian::group_checks::Graph;  ## no critic (Modules::ProhibitMultiplePackages)
#>>>

sub new {
    my ($type, $nodes, $edges) = @_;
    my $self = { nodes => $nodes, edges => $edges};
    bless $self, $type;
    return $self;
}

sub tarjans {
    my ($self) = @_;
    my $nodes = $self->{nodes};
    $self->{index} = 0;
    $self->{scc} = [];
    $self->{stack} = [];
    $self->{on_stack} = {};
    # The information for each node:
    #  $self->{node_info}{$node}[X], where X is:
    #    0 => index
    #    1 => low_index
    $self->{node_info} = {};
    foreach my $node (@$nodes) {
        $self->_tarjans_sc($node)
          unless defined $self->{node_info}{$node};
    }
    return $self->{scc};
}

sub _tarjans_sc {
    my ($self, $node) = @_;
    my $index = $self->{index};
    my $stack = $self->{stack};
    my $ninfo = [$index, $index];
    my $on_stack = $self->{on_stack};
    $self->{node_info}{$node} = $ninfo;
    $index++;
    $self->{index} = $index;
    push @$stack, $node;
    $on_stack->{$node} = 1;

    foreach my $neighbour (@{ $self->{edges}{$node} }){
        my $nb_info;
        $nb_info = $self->{node_info}{$neighbour};
        if (!defined $nb_info){
            # First time visit
            $self->_tarjans_sc($neighbour);
            # refresh $nb_info
            $nb_info = $self->{node_info}{$neighbour};
            # min($node.low_index, $neigh.low_index)
            $ninfo->[1] = $nb_info->[1] if $nb_info->[1] < $ninfo->[1];
        } elsif (exists $on_stack->{$neighbour})  {
            # Node is in this component
            # min($node.low_index, $neigh.index)
            $ninfo->[1] = $nb_info->[0] if $nb_info->[0] < $ninfo->[1];
        }
    }
    if ($ninfo->[0] == $ninfo->[1]){
        # the "root" node - create the SSC.
        my $component = [];
        my $scc = $self->{scc};
        my $elem = '';
        do {
            $elem = pop @$stack;
            delete $on_stack->{$elem};
            push @$component, $elem;
        } until $node eq $elem;
        push @$scc, $component;
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
