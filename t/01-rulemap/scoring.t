use strict;
use warnings;
use Test::More tests => 6;
use lib qw/lib/;
use basilisk::Rulemap;

{
   my $rulemap = new basilisk::Rulemap::Rect (h=>4,w=>4);
   my $board = Util::board_from_text (
      '0000
       0000
       0000
       0000', 4);

   my $captures = '0 0';
   my $score1 = $rulemap->compute_score ($board, $captures, {});
   is_deeply ($score1, {b=>0, w=>6.5}, 'empty score');
   $rulemap->set_stone_at_node($board, [2,2], 'b');
   my $score2 = $rulemap->compute_score ($board, $captures, {});
   is_deeply ($score2, {b=>15, w=>6.5}, 'score with black board');
   $rulemap->set_stone_at_node($board, [1,1], 'w');
   my $score3 = $rulemap->compute_score ($board, $captures, {});
   is_deeply ($score3, {b=>0, w=>6.5}, 'score: board has 1 w, 1 b stone');
}



{ #count territory & death masks
   my $rulemap = new basilisk::Rulemap::Rect (h=>4,w=>4, wrap_ns=>1);
   my $board = Util::board_from_text (
      '0b00
       b0b0
       0b00
       000w', 4);

   my $captures = '0 0';
   my $score1 = $rulemap->compute_score ($board, $captures, {});
   is_deeply ($score1, {b=>1, w=>6.5}, 'count b enclosure point');
   my $score2 = $rulemap->compute_score ($board, $captures, {'0-1' => 1});
   is_deeply ($score2, {b=>0, w=>6.5}, 'breach b enclosure, unknown killer');
   my $score3 = $rulemap->compute_score ($board, $captures, {'3-3' => 1});
   is_deeply ($score3, {b=>13, w=>6.5}, 'the only w stone is dead');
}

