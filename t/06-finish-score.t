use strict;
use warnings;
use Test::More tests => 7;

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;

 # game(1)->num_moves,etc
sub game{
   $schema->resultset('Game')->find ({id => $_[0]});
}

my @players = map {
   $schema->resultset('Player')->create( {
      name=> $_,
      pass=> Util::pass_hash ($_)
   })}
   (qw/Pekehentes Mecheel Benjemen Cthelhe Erter Stephen Bembe/);

#begin with an empty board, b and w, no komi defined,
# so score should be {w=>0,b=>0}
{
   my $ruleset = $schema->resultset('Ruleset')->create({
      h=>6,w=>6,
      phase_description => '0b 1w',
   }); #2-player normal
   
   my $game = $ruleset->create_related('games',{});
   my $gid = $game->id;
   
   $game->create_related ('player_to_game', {
      pid  => $players[0]->id, #Pekehentes
      entity => 0,
   });
   $game->create_related ('player_to_game', {
      pid  => $players[1]->id, #Mecheel
      entity => 1,
   });
   
   $mech->login_as('Pekehentes');
   $mech->get_ok("/game/$gid/think/");
   is (game($gid)->num_moves, 1);
   $mech->login_as('Mecheel');
   $mech->get_ok("/game/$gid/think/");
   is (game($gid)->num_moves, 2);
   is (game($gid)->status, 2);
   is (game($gid)->status, Util::FINISHED(), 'game finished');
   is (game($gid)->result, 'b 0 w 0')
}
