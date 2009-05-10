use strict;
use warnings;
use Test::More tests => 62;
use lib qw(t/lib lib);

use basilisk::Constants qw/GAME_FINISHED/;
use basilisk::Util qw/board_from_text pack_board/;

use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;

my $gid;
#set $gid, then use these
sub move_count{
   return $schema->resultset('Game')->find({id=>$gid})->count_related('moves',{});
}
sub game_fin{
   return $schema->resultset('Game')->find({id=>$gid})->fin;
}
sub game_active{
   return [$schema->resultset('Game')->find({id=>$gid})->active_phases];
}
sub game_phase{
   return $schema->resultset('Game')->find({id=>$gid})->phase;
}
sub game_finished{
   my $game = $schema->resultset('Game')->find({id=>$gid});
   return  0 if $game->status != GAME_FINISHED;
   die "finished but no result!" unless $game->result;
   return $game->result;
}
   
   
my @players = $schema->create_players (qw/lamp athame bag/);

{
   my $game = $schema->create_game (6,6,'0b 1w 2r',@players);
   $gid = $game->id;
   
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/move/2-2");
   is (move_count(), 1);
   is (game_fin(), '0 0 0');
   is_deeply(game_active(), [0,1,2]);
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/pass");
   is (move_count(), 2);
   is (game_fin(), '0 1 0');
   is_deeply(game_active(), [0,1,2]);
   $mech->login_as('bag');
   $mech->get_ok("/game/".$game->id."/resign");
   is (move_count(), 3);
   is (game_fin(), '0 0 3');
   is_deeply(game_active(), [0,1]);
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/pass");
   is (move_count(), 4);
   is (game_fin(), '1 0 3');
   is_deeply(game_active(), [0,1]);
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/pass");
   is (move_count(), 5);
   is (game_fin(), '1 1 3');
   is_deeply(game_active(), [0,1]);
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/move/0-0");
   is (move_count(), 6);
   is (game_fin(), '0 0 3');
   is_deeply(game_active(), [0,1]);
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/resign");
   is (move_count(), 7);
   is (game_fin(), '0 3 3');
   is_deeply(game_active(), [0]);
}


#test zen, supply an initial position, and end the game by scoring
#let all stones live, except for the w stone at 1-1
{
   #3|2-player zen
   my $game = $schema->create_game (6,6,'0b 1w 2b 0w 1b 2w',@players);
   $gid = $game->id;
   my $ruleset = $game->ruleset;
   
   my $board = board_from_text ( #give b 6, w 0
   'bbbbbb
    0w0000
    bbbbbb
    ww00ww
    000000
    ww00ww', 6);
   my $pos_data = pack_board($board);
   my $pos_row = $schema->resultset('Position')->create({
      ruleset => $ruleset->id,
      position => $pos_data,
   });
   
   $game->set_column ('initial_position', $pos_row->id);
   $game->update;
   
   is (game_phase(), 0);
   #give lamp 1 ponnuki, have athame resign, have bag
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/move/4-1");
   is (game_phase(), 1);
   is (game_fin(), '0 0 0 0 0 0');
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/move/4-3");
   is (game_phase(), 2);
   $mech->login_as('bag');
   $mech->get_ok("/game/".$game->id."/pass");
   is (game_phase(), 3);
   is (game_fin(), '0 0 1 0 0 0');
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/pass?pass_all=1");
   is (game_phase(), 4);
   is (game_fin(), '1 0 1 1 0 0');
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/pass");
   is (game_phase(), 5);
   is (game_fin(), '1 0 1 1 1 0');
   $mech->login_as('bag');
   $mech->get_ok("/game/".$game->id."/pass");
   is (game_phase(), 1, 'skip a fin phase after pass');
   is (game_fin(), '1 0 1 1 1 1');
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/pass");
   is (game_phase(), 2, 'after everyphase is fin, it is time for next phase to score..');
   is (game_fin(), '1 1 1 1 1 1');
   
   #start the process of scoring
   $mech->login_as('bag');
   $mech->get_ok("/game/".$game->id."/think/1-1_0-0");   #think_all would be implied..
   is (game_phase(), 3, 'score phases 2,5');
   is (game_fin(), '1 1 2 1 1 2');
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/think/1-1");   #think_all would be implied..
   is (game_phase(), 4, 'score differently phases 0,3');
   is (game_fin(), '2 1 1 2 1 1');
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/think/1-1");   #think_all would be implied..
   is (game_phase(), 5, 'score (agree) phases 1,4');
   is (game_fin(), '2 2 1 2 2 1');
   $mech->login_as('bag');
   $mech->get_ok("/game/".$game->id."/think/1-1");   #think_all would be implied..
   $mech->content_contains("success", 'bag notified of mv success');
   #is (game_phase(), 0, 'score (agree) phases 2,5');
   is (game_fin(), '2 2 2 2 2 2');
   ok (game_finished(), 'GAME status is FINISHED');
}

#now do a team drop/recovery/surrogate thing

