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
use Lintian::ProcessablePool;
use Util;
use Cwd();

my $debug = $ENV{DEBUG}//0;
my $cwd = Cwd::cwd();
my $pool = Lintian::ProcessablePool->new();

foreach my $file (@ARGV) {
    $pool->add_file($file) or die "Adding $file failed\n";
}

foreach my $gname ( sort $pool->get_group_names() ){
    my $group = $pool->get_group($gname);
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
    if ($pkg_type eq 'binary' or $pkg_type eq 'udeb'){
        my $pkg_arch = $proc->pkg_arch();
        return "${pkg_name} $pkg_version ($pkg_type:$pkg_arch)";
    }
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
    return $proc->pkg_name() . '_' . $proc->pkg_version() .
        '_' . $proc->pkg_arch();
}

sub gen_src_proc_key{
    my ($proc) = @_;
    return $proc->pkg_src() . '_' . $proc->pkg_src_version();
}

