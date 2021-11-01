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

package Lintian::Check::GroupChecks;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

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
        if (scalar @{$deps} > 0) {
            # it depends on another package - it can cause
            # a circular dependency
            my $pname = $processable->name;
            push @nodes, $pname;
            $edges{$pname} = [map { $_->name } @{$deps}];
            $self->check_multiarch($processable, $deps);
        }
    }

    # Bail now if we do not have at least two packages depending
    # on some other package from this source.
    return if scalar @nodes < 2;

    $sccs= Lintian::Check::GroupChecks::Graph->new(\@nodes, \%edges)->tarjans;

    for my $comp (@{$sccs}) {
        # It takes two to tango... erh. make a circular dependency.
        next if scalar @{$comp} < 2;

        $self->hint('intra-source-package-circular-dependency',
            (sort @{$comp}));
    }

    return;
}

sub check_file_overlap {
    my ($self, @processables) = @_;

    # make a local copy to be modified
    my @remaining = @processables;

    # avoids checking the same combo twice
    while (@remaining > 1) {

        # avoids checking the same combo twice
        my $one = shift @remaining;

        my @provides_one = $one->fields->trimmed_list('Provides', qr{,});
        my $relation_one = Lintian::Relation->new->load(
            join(' |̈́ ', $one->name, @provides_one));

        for my $two (@remaining) {

            # poor man's work-around for "Multi-arch: same"
            next
              if $one->name eq $two->name;

            my @provides_two = $two->fields->trimmed_list('Provides', qr{,});
            my $relation_two = Lintian::Relation->new->load(
                join(' | ', $two->name, @provides_two));

            # $two conflicts/replaces with $one
            next
              if $two->relation('Conflicts')->satisfies($relation_one);
            next
              if $two->relation('Replaces')->satisfies($one->name);

            # $one conflicts/replaces with $two
            next
              if $one->relation('Conflicts')->satisfies($relation_two);
            next
              if $one->relation('Replaces')->satisfies($two->name);

            for my $one_file (@{$one->installed->sorted_list}) {

                my $name = $one_file->name;

                $name =~ s{/$}{};
                my $two_file = $two->installed->lookup($name)
                  // $two->installed->lookup("$name/");
                next
                  unless defined $two_file;

                next
                  if $one_file->is_dir && $two_file->is_dir;

                $self->hint('binaries-have-file-conflict',
                    sort($one->name, $two->name), $name);
            }
        }
    }

    return;
}

sub check_multiarch {
    my ($self, $processable, $deps) = @_;

    my $KNOWN_DBG_PACKAGE
      = $self->profile->load_data('common/dbg-pkg',qr/\s*\~\~\s*/,
        sub { return qr/$_[0]/xms; });

    my $ma = $processable->fields->value('Multi-Arch') || 'no';
    if ($ma eq 'same') {
        for my $dep (@{$deps}) {
            my $dma = $dep->fields->value('Multi-Arch') || 'no';
            if ($dma eq 'same' or $dma eq 'foreign') {
                1; # OK
            } else {
                $self->hint(
                    'dependency-is-not-multi-archified',
                    join(q{ },
                        $processable->name, 'depends on',
                        $dep->name, "(multi-arch: $dma)"));
            }
        }
    } elsif ($ma ne 'same'
        and ($processable->fields->value('Section') || 'none')
        =~ m{(?:^|/)debug$}) {
        # Debug package that isn't M-A: same, exploit that (non-debug)
        # dependencies is (almost certainly) a package for which the
        # debug carries debug symbols.
        for my $dep (@{$deps}) {
            my $dma = $dep->fields->value('Multi-Arch') || 'no';
            if ($dma eq 'same'
                && ($dep->fields->value('Section') || 'none')
                !~ m{(?:^|/)debug$}){

                # Debug package isn't M-A: same, but depends on a
                # package that is from same source that isn't a debug
                # package and that is M-A same.  Thus it is not
                # possible to install debug symbols for all
                # (architecture) variants of the binaries.
                $self->hint(
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
package Lintian::Check::GroupChecks::Graph;  ## no critic (Modules::ProhibitMultiplePackages)
#>>>

use Const::Fast;

const my $EMPTY => q{};

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
    for my $node (@{$nodes}) {
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
    push(@{$stack}, $node);
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
        my $elem = $EMPTY;

        do {
            $elem = pop @{$stack};
            delete $on_stack->{$elem};
            push(@{$component}, $elem);

        } until $node eq $elem;

        push(@{$scc}, $component);
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
