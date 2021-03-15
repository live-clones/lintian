# Copyright © 2018 Felix Lechner
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
# MA 02110-1301, USA

package Test::StagedFileProducer;

=head1 NAME

Test::StagedFileProducer -- mtime-based file production engine

=head1 SYNOPSIS

  use Test::StagedFileProducer;

  my $wherever = '/your/test/directory';

  my $producer = Test::StagedFileProducer->new(path => $wherever);
  $producer->exclude("$wherever/log", "$wherever/build-stamp");

  my $output = "$wherever/file.out";
  $producer->add_stage(
        products => [$output],
        build =>sub {
            print encode_utf8("Building $output.\n");
        },
        skip =>sub {
            print encode_utf8("Skipping $output.\n");
        }
  );

  $producer->run(minimum_epoch => time, verbose => 1);

=head1 DESCRIPTION

Provides a way to define and stack file production stages that all
depend on subsets of the same group of files.

After the stages are defined, the processing engine takes an inventory
of all files in a target directory. It excludes some files, like logs,
that should not be considered.

Each stage adds its own products to the list of files to be excluded
before deciding whether to produce them. The decision is based on
relative file modification times, in addition to a systemic rebuilding
threshold. Before rebuilding, each stage asks a lower stage to make
the same determination.

The result is an engine with file production stages that depend on
successively larger sets of files.

=cut

use v5.20;
use warnings;
use utf8;

use Carp;
use Const::Fast;
use File::Find::Rule;
use File::Spec::Functions qw(abs2rel);
use File::stat;
use List::Util qw(min max);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Test::Lintian::Helper qw(rfc822date);

const my $EMPTY => q{};
const my $SPACE => q{ };

=head1 FUNCTIONS

=over 4

=item new(path => PATH)

Create a new instance focused on files in directory PATH.

=cut

sub new {
    my ($class, %params) = @_;

    my $self = bless {}, $class;

    croak encode_utf8('Cannot proceed without a path.')
      unless exists $params{path};
    $self->{path} = $params{path};

    $self->{exclude} = [];
    $self->{stages} = [];

    return $self;
}

=item exclude(LIST)

Excludes all absolute paths in LIST from all mtime comparisons.
This is especially useful for logs. Calls to Path::Tiny->realpath
are made to ensure the elements are canonical and have a chance
of matching something returned by File::Find::Rule.

=cut

sub exclude {
    my ($self, @list) = @_;

    push(@{$self->{exclude}}, grep { defined } @list);

    return;
}

=item add_stage(HASH)

Add a stage defined by HASH to the processing engine for processing
after stages previously added. HASH can define the following keys:

$HASH{products} => LIST; a list of full-path filenames to be
produced.

$HASH{minimum_epoch} => EPOCH; an integer threshold for maximum age

$HASH{build} => SUB; a sub executed when production is required.

$HASH{skip} => SUB; a sub executed when production is not required.

=cut

sub add_stage {
    my ($self, %stage) = @_;

    push(@{$self->{stages}}, \%stage);

    return;
}

=item run(PARAMETERS)

Runs the defined engine using the given parameters, which are
arranged in a matching list suitable for assignment to a hash.
The following two parameters are currently available:

minimum_epoch => EPOCH; a systemic threshold, in epochs, below
which rebuilding is mandatory for any product.

verbose => BOOLEAN; an option to enable more verbose reporting

=cut

sub run {
    my ($self, %params) = @_;

    $self->{minimum_epoch} = $params{minimum_epoch} // 0;
    $self->{verbose} = $params{verbose} // 0;

    # take an mtime inventory of all files in path
    $self->{mtimes}
      = { map { $_ => stat($_)->mtime }
          File::Find::Rule->file->in($self->{path}) };

    say encode_utf8(
        'Found the following file modification times (most recent first):')
      if $self->{verbose};

    my @ordered= reverse sort { $self->{mtimes}{$a} <=> $self->{mtimes}{$b} }
      keys %{$self->{mtimes}};
    foreach my $file (@ordered) {
        my $relative = abs2rel($file, $self->{path});
        say encode_utf8(rfc822date($self->{mtimes}{$file}) . " : $relative")
          if $self->{verbose};
    }

    $self->_process_remaining_stages(@{$self->{exclude}});

    return;
}

=item _process_remaining_stages(LIST)

An internal subroutine that is used recursively to execute
the stages. The list passed describes the list of files to
be excluded from subsequent mtime calculations.

Please note that the bulk of the execution takes place
after calling the next lower stage. That is to ensure that
any lower build targets (or products, in our parlance) are
met before the present stage attempts to do its job.

=cut

sub _process_remaining_stages {
    my ($self, @exclude) = @_;

    if (scalar @{$self->{stages}}) {

        # get the next processing stage
        my %stage = %{ pop(@{$self->{stages}}) };

        # add our products to the list of files excluded
        my @products = grep { defined } @{$stage{products}//[]};
        push(@exclude, @products);

        # pass to next lower stage for potential rebuilding
        $self->_process_remaining_stages(@exclude);

        # get good paths that will match those of File::Find
        @exclude = map { path($_)->realpath } @exclude;

        say encode_utf8($EMPTY) if $self->{verbose};

        my @relative = sort map { abs2rel($_, $self->{path}) } @products;
        say encode_utf8(
            'Considering production of: ' . join($SPACE, @relative))
          if $self->{verbose};

        say encode_utf8('Excluding: '
              . join($SPACE, sort map { abs2rel($_, $self->{path}) } @exclude))
          if $self->{verbose};

        my %relevant = %{$self->{mtimes}};
        delete @relevant{@exclude};

# my @ordered= reverse sort { $relevant{$a} <=> $relevant{$b} }
#   keys %relevant;
# foreach my $file (@ordered) {
#   say encode_utf8(rfc822date($relevant{$file}) . ' : ' . abs2rel($file, $self->{path}))
#     if $self->{verbose};
# }

        say encode_utf8($EMPTY) if $self->{verbose};

        my $file_epoch = (max(values %relevant))//time;
        say encode_utf8(
            'Input files modified on      : '. rfc822date($file_epoch))
          if $self->{verbose};

        my $systemic_minimum_epoch = $self->{minimum_epoch} // 0;
        say encode_utf8('Systemic minimum epoch is    : '
              . rfc822date($systemic_minimum_epoch))
          if $self->{verbose};

        my $stage_minimum_epoch = $stage{minimum_epoch} // 0;
        say encode_utf8('Stage minimum epoch is       : '
              . rfc822date($stage_minimum_epoch))
          if $self->{verbose};

        my $threshold
          = max($stage_minimum_epoch, $systemic_minimum_epoch, $file_epoch);
        say encode_utf8(
            'Rebuild threshold is         : '. rfc822date($threshold))
          if $self->{verbose};

        say encode_utf8($EMPTY) if $self->{verbose};

        my $product_epoch
          = min(map { -e $_ ? stat($_)->mtime : 0 } @products);
        if($product_epoch) {
            say encode_utf8(
                'Products modified on         : '. rfc822date($product_epoch))
              if $self->{verbose};
        } else {
            say encode_utf8('At least one product is not present.')
              if $self->{verbose};
        }

        # not producing if times are equal; resolution 1 sec
        if ($product_epoch < $threshold) {

            say encode_utf8('Producing: ' . join($SPACE, @relative))
              if $self->{verbose};

            $stage{build}->() if exists $stage{build};

            # sometimes the products are not the newest files
            path($_)->touch(time) for @products;

        } else {

            say encode_utf8(
                'Skipping production of: ' . join($SPACE, @relative))
              if $self->{verbose};

            $stage{skip}->() if exists $stage{skip};
        }
    }

    return;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
