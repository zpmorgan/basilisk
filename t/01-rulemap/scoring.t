use strict;
use warnings;
use Test::More tests => 1;
use lib qw/lib/;
use basilisk::Rulemap;

my $rulemap1 = new basilisk::Rulemap::Rect (h=>4,w=>4);
my $board1 = Util::board_from_text (
   '0000
    0000
    0000
    0000', 4);

my $captures = '0 0';
my $score = $rulemap1->compute_score ($board1, $captures);
is_deeply ($score, {b=>0, w=>6.5});


