# init.d -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
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

package Lintian::init_d;
use strict;
use Tags;
use Util;

# A list of valid LSB keywords.	 The value is 0 if optional and 1 if required.
my %lsb_keywords = (provides		=> 1,
		    'required-start'	=> 1,
		    'required-stop'	=> 1,
		    'should-start'	=> 0,
		    'should-stop'	=> 0,
		    'default-start'	=> 1,
		    'default-stop'	=> 1,
		    'short-description' => 1,
		    'description'	=> 0);

sub run {

my $pkg = shift;
my $type = shift;

my $postinst = "control/postinst";
my $preinst = "control/preinst";
my $postrm = "control/postrm";
my $prerm = "control/prerm";
my $conffiles = "control/conffiles";

my %initd_postinst;
my %initd_postrm;
my %conffiles;

my $opts_r = qr/-\S+\s*/;
my $name_r = qr/[\w.-]+/;
my $action_r = qr/\w+/;
my $exclude_r = qr/if\s+\[\s+-x\s+\S*update-rc\.d/;

# read postinst control file
if (open(IN, '<', $postinst)) {
    while (<IN>) {
	next if /$exclude_r/o;
	s/\#.*$//o;
	next unless /^(?:.+;|^\s*system[\s\(\']+)?\s*update-rc\.d\s+
	    (?:$opts_r)*($name_r)\s+($action_r)/xo;
	my ($name,$opt) = ($1,$2);
	next if $opt eq 'remove';
	if ($initd_postinst{$name}++ == 1) {
	    tag "duplicate-updaterc.d-calls-in-postinst", "$name";
	    next;
	}
	unless (m,>\s*/dev/null,o) {
	    tag "output-of-updaterc.d-not-redirected-to-dev-null", "$name postinst";
	}
    }
}
close(IN);

# read preinst control file
if (open(IN, '<', $preinst)) {
    while (<IN>) {
	next if /$exclude_r/o;
	s/\#.*$//o;
	next unless m/update-rc\.d\s+(?:$opts_r)*($name_r)\s+($action_r)/o;
	my ($name,$opt) = ($1,$2);
	next if $opt eq 'remove';
	tag "preinst-calls-updaterc.d", "$name";
    }
    close(IN);
}

# read postrm control file
if (open(IN, '<', $postrm)) {
    while (<IN>) {
	next if /$exclude_r/o;
	s/\#.*$//o;
	next unless m/update-rc\.d\s+($opts_r)*($name_r)/o;
	if ($initd_postrm{$2}++ == 1) {
	    tag "duplicate-updaterc.d-calls-in-postrm", "$2";
	    next;
	}
	unless (m,>\s*/dev/null,o) {
	    tag "output-of-updaterc.d-not-redirected-to-dev-null", "$2 postrm";
	}
    }
    close(IN);
}

# read prerm control file
if (open(IN, '<', $prerm)) {
    while (<IN>) {
	next if /$exclude_r/o;
	s/\#.*$//o;
	next unless m/update-rc\.d\s+($opts_r)*($name_r)/o;
	tag "prerm-calls-updaterc.d", "$2";
    }
    close(IN);
}

# init.d scripts have to be removed in postrm
for (keys %initd_postinst) {
    if ($initd_postrm{$_}) {
	delete $initd_postrm{$_};
    } else {
	tag "postrm-does-not-call-updaterc.d-for-init.d-script", "/etc/init.d/$_";
    }
}
for (keys %initd_postrm) {
    tag "postrm-contains-additional-updaterc.d-calls", "/etc/init.d/$_";
}

# load conffiles
if (open(IN, '<', $conffiles)) {
    while (<IN>) {
	chop;
	next if m/^\s*$/o;
	$conffiles{$_} = 1;

	if (m,^/?etc/rc.\.d,o) {
	    tag "file-in-etc-rc.d-marked-as-conffile", "$_";
	}
    }
    close(IN);
}

for (keys %initd_postinst) {
    next if /^\$/;
    # init.d scripts have to be marked as conffiles
    unless ($conffiles{"/etc/init.d/$_"} or $conffiles{"etc/init.d/$_"}) {
	tag "init.d-script-not-marked-as-conffile", "/etc/init.d/$_";
    }

    # check if file exists in package
    my $initd_file = "init.d/$_";
    if (-f $initd_file) {
	check_init($initd_file);
    } else {
	tag "init.d-script-not-included-in-package", "/etc/init.d/$_";
    }
}

# files actually installed in /etc/init.d should match our list :-)
opendir(INITD, "init.d") or fail("cannot read init.d directory: $!");
for (readdir(INITD)) {
    next if $_ eq '.' || $_ eq '..' || $_ eq 'README' || $_ eq 'skeleton';
    unless ($initd_postinst{$_}) {
	tag "script-in-etc-init.d-not-registered-via-update-rc.d", "/etc/init.d/$_";
	check_init("init.d/$_") if -f "init.d/$_";
    }
}
closedir(INITD);

}

sub check_init {
    my ($initd_file) = @_;
    open(IN, '<', $initd_file)
	or fail("cannot open init.d file $initd_file: $!");
    my (%tag, %lsb);
    my $in_file_test = 0;
    while (defined(my $l = <IN>)) {
	if ($. eq 1 && $l =~ m,^\#!\s*(/usr/[^\s]+),) {
	    tag "init.d-script-uses-usr-interpreter", "/etc/init.d/$_ $1";
	}
	if ($l =~ m/^\#\#\# BEGIN INIT INFO/) {
	    if ($lsb{BEGIN}) {
		tag "init.d-script-has-duplicate-lsb-section", "/etc/init.d/$_";
		next;
	    }
	    $lsb{BEGIN} = 1;
	    my $last;

	    # We have an LSB keyword section.  Parse it and save the data
	    # in %lsb for analysis.
	    while (defined(my $l = <IN>)) {
		if ($l =~ /^\#\#\# END INIT INFO/) {
		    $lsb{END} = 1;
		    last;
		} elsif ($l !~ /^\#/) {
		    tag "init.d-script-has-unterminated-lsb-section", "/etc/init.d/$_:$.";
		    last;
		} elsif ($l =~ /^\# ([a-zA-Z-]+):\s*(.*?)\s*$/) {
		    my $keyword = lc $1;
		    my $value = $2;
		    tag "init.d-script-has-duplicate-lsb-keyword", "/etc/init.d/$_:$. $keyword"
			if (defined $lsb{$keyword});
		    tag "init.d-script-has-unknown-lsb-keyword", "/etc/init.d/$_:$. $keyword"
			unless (defined ($lsb_keywords{$keyword}) || $keyword =~ /^x-/);
		    $lsb{$keyword} = $value || '';
		    $last = $keyword;
		} elsif ($l =~ /^\#(\t|  )/ && $last eq 'description') {
		    my $value = $l;
		    $value =~ s/^\#\s*//;
		    $lsb{description} .= ' ' . $value;
		} else {
		    tag "init.d-script-has-bad-lsb-line", "/etc/init.d/$_:$.";
		}
	    }
	}

	# Pretty dummy way to handle conditionals, but should be enough
	# for simple init scripts
	$in_file_test = 1 if ($l =~ m/\bif\s+.+?[\s+-[fe]\s+/);
	$in_file_test = 0 if ($l =~ m/\bfi\b/);
	if (!$in_file_test && $l =~ m,^\s*\.\s+["'"]?(/etc/default/[\$\w/-]+),) {
	    tag "init.d-script-sourcing-without-test", "/etc/init.d/$_:$. $1";
	}

	while ($l =~ s/^[^\#]*?(start|stop|restart|force-reload)//o) {
	    $tag{$1} = 1;
	}
    }
    close(IN);

    # Make sure all of the required keywords are present.
    if (not $lsb{BEGIN}) {
	tag "init.d-script-missing-lsb-section", "/etc/init.d/$_";
    } else {
	for my $keyword (keys %lsb_keywords) {
	    if ($lsb_keywords{$keyword} && !defined $lsb{$keyword}) {
		if ($keyword eq 'short-description') {
		    tag "init.d-script-missing-lsb-short-description", "/etc/init.d/$_";
		} else {
		    tag "init.d-script-missing-lsb-keyword", "/etc/init.d/$_ $keyword";
		}
	    }
	}
    }

    # Check the runlevels.
    my %start;
    if ($lsb{'default-start'}) {
	for my $runlevel (split (/\s+/, $lsb{'default-start'})) {
	    if ($runlevel =~ /^[sS0-6]$/) {
		$start{lc $runlevel} = 1;
	    } else {
		tag "init.d-script-has-bad-start-runlevel", "/etc/init.d/$_ $runlevel";
	    }
	}
    }
    if ($lsb{'default-stop'}) {
	for my $runlevel (split (/\s+/, $lsb{'default-stop'})) {
	    if ($runlevel =~ /^[sS0-6]$/) {
		if ($start{$runlevel}) {
		    tag "init.d-script-has-conflicting-start-stop", "/etc/init.d/$_ $runlevel";
		}
		if ($runlevel =~ /[sS]/) {
		    tag "init-d-script-stops-in-s-runlevel", "/etc/init.d/$_";
		}
	    } else {
		tag "init.d-script-has-bad-stop-runlevel", "/etc/init.d/$_ $runlevel";
	    }
	}
    }

    # all tags included in file?
    $tag{'start'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ start";
    $tag{'stop'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ stop";
    $tag{'restart'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ restart";
    $tag{'force-reload'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ force-reload";
}

1;

# Local Variables:
# indent-tabs-mode: t
# cperl-indent-level: 4
# End:
# vim: syntax=perl ts=8
