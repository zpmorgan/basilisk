use strict;
use warnings;
use JSON;
use Test::More tests => 13;
use lib qw(t/lib lib);

use basilisk::Util qw/board_from_text pack_board/;

use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;


my @players = $schema->create_players (qw/ Izar Shaula Lesath /);


#begin with an empty board, b and w,
{
   my $game = $schema->create_game (6,6, '0b 1w', @players[0,1]);
   my $gid = $game->id;
   my $ruleset = $game->ruleset;
   $ruleset->set_column(other_rules => q|{"topo":"torus", "clumpgo":{"cloudset":"B2"}}|); #single allowed.
   $ruleset->update;
   $mech->login_as ('Izar');
   $mech->get_ok("/game/$gid/move/1-1");
   $mech->content_contains('move is success');
   $game = $game->get_from_storage();
   is ($game->player_to_move->name, 'Shaula');
   
   $mech->login_as ('Shaula');
   $mech->get_ok("/game/$gid/move/2-2_nw");
   is ($game->player_to_move->name, 'Izar');
   my $board = board_from_text (
      'b0w000
       0ww000
       www000
       000000
       000000
       000000', 6);
}








