use strict;
use warnings;
use Test::More tests => 7;
use lib qw(t/lib lib);

use basilisk::Constants qw/GAME_FINISHED/;

use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;


my @players = $schema->create_players
      (qw/Pekehentes Mecheel Benjemen Cthelhe Erter Stephen Bembe/);

#begin with an empty board, b and w, no komi defined,
# so score should be {w=>0,b=>0}
{
   my $game = $schema->create_game(6,6,'0b 1w', @players[0,1]);
   my $gid = $game->id;
   
   $mech->login_as('Pekehentes');
   $mech->get_ok("/game/$gid/think/");
   is ($schema->game($gid)->num_moves, 1);
   $mech->login_as('Mecheel');
   $mech->get_ok("/game/$gid/think/");
   
   $game = $schema->game($gid);
   is ($game->num_moves, 2);
   is ($game->status, 2);
   is ($game->status, GAME_FINISHED, 'game finished');
   is ($game->result, 'b 0 w 0')
}
