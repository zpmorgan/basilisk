use strict;
use warnings;
use Test::More tests => 2;

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;


{
   my @players = map {
      $schema->resultset('Player')->create( {
         name=> $_,
         pass=> Util::pass_hash ($_)
      })}
      (qw/lamp athame bag/);


   my $new_ruleset = $schema->resultset('Ruleset')->create({
      h=>6,w=>6,
      phase_description => '0b 1w 2r',
   }); #3-player ffa
   
   my $game = $new_ruleset->create_related('games',{});
   my $gid = $game->id;
   sub move_count{
      return $schema->resultset('Game')->find({id=>$gid})->count_related('moves',{});
   }
   sub game_fin{
      return $schema->resultset('Game')->find({id=>$gid})->fin;
   }
   sub game_okay{
      return [$schema->resultset('Game')->find({id=>$gid})->okay_phases];
   }
   
   $game->create_related ('player_to_game', {
      pid  => $players[0]->id, #lamp
      entity => 0,
   });
   $game->create_related ('player_to_game', {
      pid  => $players[1]->id, #athame
      entity => 1,
   });
   $game->create_related ('player_to_game', {
      pid  => $players[2]->id, #bag
      entity => 2,
   });
   
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/move/2-2");
   is (move_count(), 1);
   is (game_fin(), '0 0 0');
   is_deeply(game_okay(), [0,1,2]);
   $mech->login_as('athame');
   $mech->get_ok("/game/".$game->id."/pass");
   is (move_count(), 2);
   is (game_fin(), '0 1 0');
   is_deeply(game_okay(), [0,1,2]);
   $mech->login_as('bag');
   $mech->get_ok("/game/".$game->id."/resign");
   is (move_count(), 3);
   is (game_fin(), '0 1 3');
   is_deeply(game_okay(), [0,1]);
   $mech->login_as('lamp');
   $mech->get_ok("/game/".$game->id."/resign");
   is (move_count(), 4);
   is (game_fin(), '3 1 3');
   is_deeply(game_okay(), [1]);
   
   
}





