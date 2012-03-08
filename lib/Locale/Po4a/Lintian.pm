package Locale::Po4a::Lintian;

use strict;
use warnings;

use parent qw(Locale::Po4a::TransTractor);
use Locale::Po4a::Common();

sub initialize {
    my ($self) = @_;
    # do nothing
    return 1;
}

sub parse {
    my ($self) = @_;
    my $keep = 0;
    my $first = 1;
    my ($line, $ref) = $self->shiftline;
    my (@lines, $check_name);
    my $lfield = '';
    my $comment
      = "Please keep the leading space.  Indented lines are used for\n"
      . "\"verbatim\" or shell commands (specially formatted in output).\n";
    my $lr = $ref;
    my $tag = '';

    while (defined($line)) {
        if ($line !~ m/^\s*$/o) {
            if ($line =~ m,^Check-Script: \s* (\S+) \s*$,xo) {
                $check_name = $1;
                $lfield = 'Check-Script';
            }
            if ($line =~ m,^Tag:\s*(\S+)\s*$,o) {
                $tag = $1;
                $lfield = 'Tag';
            } elsif ($line =~ m,^Info:,o
                or($lfield eq 'Info' and $line =~ m/^\s/o)) {
                # Strip the field name and the first space (even for
                # continuation lines). This makes example lines
                # standout by being indented.
                if ($line eq " .\n") {
                    $line = "\n";
                } else {
                    $line =~ s/^(?:Info:)?\s//o;
                }
                push(@lines, $line);
                $lfield = 'Info';
            } else {
                $lfield = '';
                #$self->pushline ($line);
            }
        } else {
            if (@lines) {
                # Remove the last newline if any
                $lines[-1] =~ s/\n\Z//xsm;
                $self->_trans($ref, $check_name, $tag, \@lines, $comment);
                @lines = ();
                $lfield = '';
                $tag = '';
                undef $check_name;
            }
        }
        $lr = $ref if defined $ref;
        ($line, $ref) = $self->shiftline();
    }
    $self->_trans($lr, $check_name, $tag, \@lines, $comment) if @lines;
    return;
}

sub _trans {
    my ($self, $ref, $check_name, $tag, $lines, $comment) = @_;
    my $l = join('', @$lines);
    if ($check_name) {
        $self->pushline("Check-Script-Translation: $check_name\n\n");
    } elsif ($tag) {
        my $t = $self->translate(
            $l,
            $ref,
            'Lintian tag description',
            'wrap' => 0,
            'comment' => "$comment\nTag: $tag"
        );
        # Re-add spaces and turn empty lines into " ."
        my $translated
          = join("\n ",map { $_ eq '' ? '.' : $_} split(m/\n/, $t));
        $self->pushline("Tag: $tag\n");
        $self->pushline("Info: $translated\n\n");
    }
    return;
}

1;
