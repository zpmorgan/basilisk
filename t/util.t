use strict;
use warnings;
use Test::More tests => 5;
use basilisk::Util;

my $board1 = Util::board_from_text (
   '0000
    0000
    0000
    0000', 4);
my $board2 = [ map {[0,0,0,0]} (1..4) ];
is_deeply ($board1, $board2, 'board_from_text test');


my $board3 = Util::board_from_text (
   'b0b0
    00ww
    ww00
    0bw0', 4);
my $board4 = [
 ['b',0,'b',0],
 [0,0,'w','w'],
 ['w','w',0,0],
 [0,'b','w',0], ];
is_deeply ($board3, $board4, 'board_from_text test2');


is_deeply (chr(0)x16, Util::empty_pos(4), 'empty position(packed)');
is_deeply ($board1, Util::empty_board(4), 'empty board');

my $board5 = Util::unpack_position(Util::pack_board($board4), 4);
is_deeply ($board4, $board5, 'board-data packing & unpacking test');

