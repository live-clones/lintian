package common_data;

use strict;
use warnings;

use base qw(Exporter);

our @EXPORT = qw
(
   $known_shells_regex
);

# To let "perl -cw" test know we use these variables;
use vars qw
(
  $known_shells_regex
);

# simple defines for commonly needed data

$known_shells_regex = qr'(?:[bd]?a|t?c|(?:pd|m)?k|z)?sh';

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround
