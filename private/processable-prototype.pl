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
    my $prockey;
    $file = "$cwd/$file" unless ($file =~ m@^/@o);

    if ($file =~ m/\.changes$/o){
        my $group = Lintian::ProcessableGroup->new($file);
        my $src_proc;
        # Correctness depends on the documented order of
        # get_processables
        foreach my $gmember (@{$group->get_processables()}){
            my $mtype = $gmember->pkg_type();
            my $mname = gen_proc_key($gmember);
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
        $group_map{gen_src_proc_key($src_proc)} = $group;
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
    $prockey = gen_proc_key($proc);
    $tmap = $type_map{$type};
    if (exists $tmap->{$prockey}){
        warning ("Skipping " . $prockey . " ($type) - duplicate package");
    } else {
        $tmap->{$prockey} = $proc;
    }
}


# create a proc-group for each of the remaining source packages.
foreach my $source (values %{ $type_map{'source'} }) {
    my $group;
    next if defined $source->group();
    debug(1, 'Creating group for ' . $source->pkg_src());
    $group = Lintian::ProcessableGroup->new();
    $group->add_processable($source);
    $group_map{gen_src_proc_key($source)} = $group;
}

foreach my $bin (values %{ $type_map{'binary'} }, values %{ $type_map{'udeb'} }){
    my $src_key = gen_src_proc_key($bin);
    my $group = $group_map{$src_key};
    if (! defined $group){
        # Create a new group based on the name of the source package
        # - perhaps we will get more binaries from the same source.
        $group = Lintian::ProcessableGroup->new();
        $group_map{$src_key} = $group;
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
    my $pkg_version = $proc->pkg_version();
    return "${pkg_name} $pkg_version ($pkg_type)";
}

sub debug {
    my ($level, $msg) = @_;
    print "$msg\n" if $level >= $debug;
}


sub warning {
    my ($msg) = @_;
    print STDERR "$msg\n";
}

sub gen_proc_key{
    my ($proc) = @_;
    return $proc->pkg_name() . '_' . $proc->pkg_version();
}

sub gen_src_proc_key{
    my ($proc) = @_;
    return $proc->pkg_src() . '_' . $proc->pkg_src_version();
}

