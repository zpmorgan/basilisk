use strict;
use warnings;
use Test::More tests => 10;
use basilisk::Rulemap;


my $rulemap = new basilisk::Rulemap;
isa_ok ($rulemap, 'basilisk::Rulemap');

my $rulemap2 = new basilisk::Rulemap(size => 4);

#test some move on an empty board (small/generic)
{
   my $board = Util::board_from_text (
      '0000
       0000
       0000
       0000', 4);

   #alter original and compare with new:
   my ($board2,$err) = $rulemap2->evaluate_move($board, 2, 2, 2);
   $board->[2][2] = 2; 
   is_deeply ($board2, $board, "move on empty board valid (actual err?: $err)");
}

#test a small capturing move on a populated board (small/generic)
{
   my $board3 = Util::board_from_text (
      '0100
       1210
       0000
       0000', 4);
   #alter original and compare with new:
   my ($board4,$err, $caps) = $rulemap2->evaluate_move($board3, 2, 1, 1);
   $board3->[2][1] = 1; 
   $board3->[1][1] = 0; #cap
   is_deeply ($board4, $board3, "capture on empty board works (actual err?: $err)");
   is_deeply ($caps, [[1,1]], "evaluate_move returns correct capture list of 1");
}

#test death_mask_from_list on a square grid board
{
   my $boardA = Util::board_from_text (
      '0110
       1210
       0010
       0000', 4);
   #alter original and compare with new:
   my $list = [[0,2]];
   my $mask = $rulemap2->death_mask_from_list($boardA, $list);
   is_deeply( 
      [sort qw/0-1 0-2 1-2 2-2/], 
      [sort keys %$mask],
      'death_mask_from_list on a square grid board'
   );
   my $list2 = $rulemap2->death_mask_to_list($boardA, $mask);
   is (scalar @$list2, 1, 'death_mask_to_list returns correct size')
}

#wrapping variant
#test a small capturing move on a populated board (small/TORUS)
TODO: {
   local $TODO = "toroidal/cylindrical stuff not ready";
   my $rulemap3 = new basilisk::Rulemap(size => 4, topology => 'torus');
   #give this text to 2 boards. (5 & 7)
   my $tboardtext = #on torus, row2col1 kills, row1col2 doesn't
      '0121
       1000
       2001
       1000' ;
   #capture on wrapping edge:
   {
      my $board5 = Util::board_from_text ( $tboardtext, 4);
      my ($board6,$err, $caps) = $rulemap3->evaluate_move($board5, 2, 1, 1);
      $board5->[2][1] = 1; 
      $board5->[2][0] = 0; #cap
      is_deeply ($board6, $board5, "wrapping capture on tor board works (actual err?: $err)");
      is_deeply ($caps, [[2,0]], "evaluate_move on torus returns correct capture list of [[2,0]]");
   }
   #escape on wrapping edge:
   {
      my $board7 = Util::board_from_text ( $tboardtext, 4); 
      my ($board8,$err, $caps) = $rulemap3->evaluate_move($board7, 1, 2, 1);
      $board7->[1][2] = 1; 
      is_deeply ($board8, $board7, "wrapping ESCAPE on tor board works (actual err?: $err)");
      is_deeply ($caps, [], "evaluate_move on torus returns correct empty capture list");
   }
}

