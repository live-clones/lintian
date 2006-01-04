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
if (open(IN,$postinst)) {
    while (<IN>) {
	next if /$exclude_r/o;
	s/\#.*$//o;
	next unless /^(?:.+;)?\s*update-rc\.d\s+
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
if (open(IN,$preinst)) {
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
if (open(IN,$postrm)) {
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
if (open(IN,$prerm)) {
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
if (open(IN,$conffiles)) {
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
	# yes! check it...
	open(IN,$initd_file) or fail("cannot open init.d file $initd_file: $!");
	my %tag;
	while (defined(my $l = <IN>)) {
	    while ($l =~ s/(start|stop|restart|force-reload)//o) {
		$tag{$1} = 1;
	    }
	}
	close(IN);

	# all tags included in file?
	$tag{'start'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ start";
	$tag{'stop'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ stop";
	$tag{'restart'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ restart";
	$tag{'force-reload'} or tag "init.d-script-does-not-implement-required-option", "/etc/init.d/$_ force-reload";
    } else {
	tag "init.d-script-not-included-in-package", "/etc/init.d/$_";
    }
}

# files actually installed in /etc/init.d should match our list :-)
opendir(INITD, "init.d") or fail("cannot read init.d directory: $!");
for (readdir(INITD)) {
    next if $_ eq '.' || $_ eq '..';
    tag "script-in-etc-init.d-not-registered-via-update-rc.d", "/etc/init.d/$_"
	unless $initd_postinst{$_};
}
closedir(INITD);

}

1;

# vim: syntax=perl ts=8
