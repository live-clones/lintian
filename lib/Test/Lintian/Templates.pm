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

package Test::Lintian::Templates;

=head1 NAME

Test::Lintian::Templates -- Helper routines dealing with templates

=head1 SYNOPSIS

use Test::Lintian::Templates qw(fill_template);

my $data = { 'placeholder' => 'value' };
my $file = '/path/to/generated/file';

fill_template("$file.in", $file, $data);

=head1 DESCRIPTION

Routines for dealing with templates in Lintian test specifications.

=cut

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      copy_skeleton_template_sets
      remove_surplus_templates
      fill_skeleton_templates
      fill_whitelisted_templates
      fill_all_templates
      fill_template
    );
}

use Carp;
use Const::Fast;
use List::Util qw(max);
use File::Path qw(make_path);
use File::Spec::Functions qw(rel2abs abs2rel);
use File::Find::Rule;
use File::stat;
use Path::Tiny;
use Text::Template;
use Unicode::UTF8 qw(encode_utf8);

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Helper qw(copy_dir_contents);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $DOT => q{.};
const my $COMMA => q{,};
const my $COLON => q{:};

=head1 FUNCTIONS

=over 4

=item copy_skeleton_template_sets(INSTRUCTIONS, RUN_PATH, SUITE, TEST_SET)

Copies template sets belonging to SUITE into the test working directory
RUN_PATH according to INSTRUCTIONS. The INSTRUCTIONS are the target
directory relative to RUN_PATH followed by the name of the template set
in parentheses. Multiple such instructions must be separated by commas.

=cut

sub copy_skeleton_template_sets {
    my ($instructions, $runpath, $testset)= @_;

    # populate working directory with specified template sets
    for my $placement (split($COMMA, $instructions)) {

        my ($relative, $name)
          =($placement =~ qr/^\s*([^()\s]+)\s*\(([^()\s]+)\)\s*$/);

        croak encode_utf8('No template destination specified in skeleton.')
          unless length $relative;

        croak encode_utf8('No template set specified in skeleton.')
          unless length $name;

        my $templatesetpath = "$testset/templates/$name";
        croak encode_utf8(
            "Cannot find template set '$name' at $templatesetpath.")
          unless -d $templatesetpath;

        say encode_utf8("Installing template set '$name'"
              . ($relative ne $DOT ? " to ./$relative." : $EMPTY));

        # create directory
        my $destination = "$runpath/$relative";
        make_path($destination);

        # copy template set
        copy_dir_contents($templatesetpath, $destination)
          if -d $templatesetpath;
    }
    return;
}

=item remove_surplus_templates(SRC_DIR, TARGET_DIR)

Removes from TARGET_DIR any templates that have corresponding originals
in SRC_DIR.

=cut

sub remove_surplus_templates {
    my ($source, $destination) = @_;

    my @originals = File::Find::Rule->file->in($source);
    foreach my $original (@originals) {
        my $relative = abs2rel($original, $source);
        my $template = rel2abs("$relative.in", $destination);

        if (-e $template) {
            unlink($template)
              or die encode_utf8("Cannot unlink $template");
        }
    }
    return;
}

=item fill_skeleton_templates(INSTRUCTIONS, HASH, EPOCH, RUN_PATH, TEST_SET)

Fills the templates specified in INSTRUCTIONS using the data in HASH. Only
fills templates when the generated files are not present or are older than
either the file modification time of the template or the age of the data
as evidenced by EPOCH. The INSTRUCTIONS are the target directory relative
to RUN_PATH followed by the name of the whitelist in parentheses. Multiple
instructions must be separated by commas.

=cut

sub fill_skeleton_templates {
    my ($instructions, $testcase, $threshold, $runpath, $testset)= @_;

    for my $target (split(/$COMMA/, $instructions)) {

        my ($relative, $name)
          =($target=~ qr/^\s*([^()\s]+)\s*(?:\(([^()\s]+)\))?\s*$/);

        croak encode_utf8('No fill destination specified in skeleton.')
          unless length $relative;

        if (length $name) {

            # template set
            my $whitelistpath = "$testset/whitelists/$name";
            croak encode_utf8(
                "Cannot find template whitelist '$name' at $whitelistpath")
              unless -e $whitelistpath;

            say encode_utf8($EMPTY);

            say encode_utf8('Generate files '
                  . ($relative ne $DOT ? "in ./$relative " : $EMPTY)
                  . "from templates using whitelist '$name'.");
            my $whitelist = read_config($whitelistpath);

            my @candidates = $whitelist->trimmed_list('May-Generate');
            my $destination = "$runpath/$relative";

            say encode_utf8('Fill templates'
                  . ($relative ne $DOT ? " in ./$relative" : $EMPTY)
                  . $COLON
                  . $SPACE
                  . join($SPACE, @candidates));

            foreach my $candidate (@candidates) {
                my $generated = rel2abs($candidate, $destination);
                my $template = "$generated.in";

                # fill template if needed
                fill_template($template, $generated, $testcase, $threshold)
                  if -e $template;
            }

        }else {

            # single file
            say encode_utf8("Filling template: $relative");

            my $generated = rel2abs($relative, $runpath);
            my $template = "$generated.in";

            # fill template if needed
            fill_template($template, $generated, $testcase, $threshold)
              if -e $template;
        }
    }
    return;
}

=item fill_whitelisted_templates(DIR, WHITE_LIST, HASH, HASH_EPOCH)

Generates all files in array WHITE_LIST relative to DIR from their templates,
which are assumed to have the same file name but with extension '.in', using
data provided in HASH. The optional argument HASH_EPOCH can be used to
preserve files when no generation is necessary.

=cut

sub fill_whitelisted_templates {
    my ($directory, $whitelistpath, $data, $data_epoch) = @_;

    croak encode_utf8("No whitelist found at $whitelistpath")
      unless -e $whitelistpath;

    my $whitelist = read_config($whitelistpath);
    my @list = $whitelist->trimmed_list('May-Generate');

    foreach my $file (@list) {
        my $generated = rel2abs($file, $directory);
        my $template = "$generated.in";

        # fill template if needed
        fill_template($template, $generated, $data, $data_epoch)
          if -e $template;
    }
    return;
}

=item fill_all_templates(HASH, DIR)

Fills all templates in DIR with data from HASH.

=cut

sub fill_all_templates {
    my ($data, $data_epoch, $directory) = @_;

    my @templates = File::Find::Rule->name('*.in')->in($directory);
    foreach my $template (@templates) {
        my ($generated) = ($template =~ qr/^(.+?)\.in$/);

        # fill template if needed
        fill_template($template, $generated, $data, $data_epoch);
    }
    return;
}

=item fill_template(TEMPLATE, GENERATED, HASH, HASH_EPOCH, DELIMITERS)

Fills template TEMPLATE with data from HASH and places the result in
file GENERATED. When given HASH_EPOCH, will evaluate beforehand if a
substitution is necessary based on file modification times. The optional
parameter DELIMITERS can be used to change the standard delimiters.

=cut

sub fill_template {
    my ($template, $generated, $data, $data_epoch, $delimiters) = @_;

    my $generated_epoch
      = length $generated  && -e $generated ? stat($generated)->mtime : 0;
    my $template_epoch
      = length $template && -e $template ? stat($template)->mtime : time;
    my $threshold = max($template_epoch, $data_epoch//time);

    if ($generated_epoch <= $threshold) {

        my $filler= Text::Template->new(
            TYPE => 'FILE',
            DELIMITERS => ['[%', '%]'],
            SOURCE => $template
        );
        croak encode_utf8(
            "Cannot read template $template: $Text::Template::ERROR")
          unless $filler;

        open(my $handle, '>', $generated)
          or croak encode_utf8("Could not open file $generated: $!");
        $filler->fill_in(
            OUTPUT => $handle,
            HASH => $data,
            DELIMITERS => $delimiters
          )
          or croak encode_utf8(
            "Could not create file $generated from template $template");
        close $handle
          or carp encode_utf8("Could not close file $generated: $!");

        # transfer file permissions from template to generated file
        my $stat = stat($template)
          or croak encode_utf8("stat $template failed: $!");
        chmod $stat->mode, $generated
          or croak encode_utf8("chmod $generated failed: $!");

        # set mtime to $threshold
        path($generated)->touch($threshold);
    }

    # delete template
    if (-e $generated) {
        unlink($template)
          or die encode_utf8("Cannot unlink $template");
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
