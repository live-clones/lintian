#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
  # determine LINTIAN_ROOT
  my $LINTIAN_ROOT = $ENV{'LINTIAN_ROOT'};
  $LINTIAN_ROOT = '.'
      if (defined $LINTIAN_ROOT and not length $LINTIAN_ROOT);
  $LINTIAN_ROOT = '/usr/share/lintian' unless ($LINTIAN_ROOT);
  $ENV{'LINTIAN_ROOT'} = $LINTIAN_ROOT;
}

use lib "$ENV{'LINTIAN_ROOT'}/lib";
use Lintian::Processable;
use Lintian::ProcessableGroup;
use Util;
use Cwd();

my $debug = $ENV{DEBUG}//0;
my $cwd = Cwd::cwd();
my %group_map = ();
my %type_map = (
    'changes' => {},
    'binary'  => {},
    'source'  => {},
    'udeb'    => {},
);

FILE:
foreach my $file (@ARGV) {
    my $type;
    my $proc;
    my $tmap;
    $file = "$cwd/$file" unless ($file =~ m@^/@o);

    if ($file =~ m/\.changes$/o){
        my $group = Lintian::ProcessableGroup->new($file);
        my $src_proc;
        # Correctness depends on the documented order of
        # get_processables
        foreach my $gmember (@{$group->get_processables()}){
            my $mtype = $gmember->pkg_type();
            my $mname = $gmember->pkg_name();
            my $tmap = $type_map{$mtype};
            if (exists $tmap->{$mname}){
                if ($mtype eq 'changes'){
                    # Skip this changes file - we have seen it before
                    warning ("Skipping $mname ($mtype) - duplicate");
                    next FILE;
                }  else {
                    # dump the old file - most likely the one from the
                    # changes file will provide the best results if they
                    # are not identical.
                    warning ("Ignoring previously added $mname ($mtype) - " .
                        "duplicate of file from $file");
                }
            }
            $tmap->{$mname} = $gmember;
        }
        $src_proc = $group->get_source_processable();
        $src_proc = $group->get_changes_processable() unless defined $src_proc;
        fail "$file has no src_proc ($group)" unless defined $src_proc;
        # There are no clashes in sane packages because $src->pkg_src
        # eq $chn->pkg_src except for crafted/incorrect files.
        #
        # ... and for crafted packages we have more to worry about
        # than suboptimal check accuracy.
        $group_map{$src_proc->pkg_src()} = $group;
        next;
    }

    if ($file =~ m/\.deb$/o){
        $type = 'binary';
    } elsif ($file =~ m/\.udeb$/o){
        $type = 'udeb';
    } elsif ($file =~ m/\.dsc$/o){
        $type = 'source';
    } else {
        fail "cannot handle $file";
    }
    $proc = Lintian::Processable->new($type, $file);
    $tmap = $type_map{$type};
    if (exists $tmap->{$proc->pkg_name()}){
        warning ("Skipping " . $proc->pkg_name() . " ($type) - duplicate package");
    } else {
        $tmap->{$proc->pkg_name()} = $proc;
    }
}


# create a proc-group for each of the remaining source packages.
foreach my $source (values %{ $type_map{'source'} }) {
    my $group;
    next if defined $source->group();
    print STDERR "Creating group for " . $source->pkg_src(), "\n";
    $group = Lintian::ProcessableGroup->new();
    $group->add_processable($source);
    $group_map{$source->pkg_src()} = $group;
}

foreach my $bin (values %{ $type_map{'binary'} }, values %{ $type_map{'udeb'} }){
    my $src_name = $bin->pkg_src();
    my $group = $group_map{$src_name};
    if (! defined $group){
        # Create a new group based on the name of the source package
        # - perhaps we will get more binaries from the same source.
        $group = Lintian::ProcessableGroup->new();
        $group_map{$src_name} = $group;
    }
    $group->add_processable($bin);
}

foreach my $gname (sort keys %group_map){
    my $group = $group_map{$gname};
    print "Group \"$gname\" consists of [",
        join(', ', map { stringify_proc($_) } @{$group->get_processables()}),
        "]\n";
}

exit 0;


## subs

sub stringify_proc {
    my ($proc) = @_;
    my $pkg_name = $proc->pkg_name();
    my $pkg_type = $proc->pkg_type();
    my $pkg_arch = $proc->pkg_arch();
    my $pkg_version = $proc->pkg_version();
    return "${pkg_name} ($pkg_type)";
}

sub debug {
    my ($level, $msg) = @_;
    print "$msg\n" if $level >= $debug;
}


sub warning {
    my ($msg) = @_;
    print STDERR "$msg\n";
}

