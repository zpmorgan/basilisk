use strict;
use warnings;
use Test::More tests => 13;


use lib qw(t/lib lib);
use_ok( 'b_schema' );


my $schema;
ok($schema = b_schema->init_schema('populate'), 'create&populate a test db' );

is ($schema->resultset('Player')->count(), 8, 'players inserted');


my @players = $schema->create_players (qw/helm bat gurret/);
for (@players){
   isa_ok ($_, 'basilisk::Schema::Player');
}
isnt($players[0]->id, $players[1]->id, 'players have unique ids'); 

{
   my $game = $schema->resultset('Game')->find({});
   isa_ok ($game, 'basilisk::Schema::Game');
   is ($game->players->count, 2, '2 players in game');
}
{
   my $game = $schema->create_game (5,5, '0b 1w 2r', @players);
   is ($game->players->count, 3, '3 players in newgame');
   my @also_players = $game->players; 
   is ($players[0]->id, $also_players[0]->id);
   is ($players[1]->id, $also_players[1]->id);
   is ($players[2]->id, $also_players[2]->id);
   
}

{
   my @other_players = $schema->create_players (qw/thelma bthathbth gambith/);
   my $game1 = $schema->create_game (5,5, '0b 1w', @players[0,1]);
   my $game2 = $schema->create_game (5,5, '0b 1w', @players[1,2]);
   my $game3 = $schema->create_game (5,5, '0b 1w', @players[2,0]);
   my $3pgame = $schema->create_game (5,5, '0b 1w 2r', @players);
   
   my @games = $players[0]->games_to_move();
   sort {$a->{gid} <=> $b->{gid})} @games;
   
   is (@games, 2);
   is ($games[0]->{gid}, $game1->id);
   is ($games[1]->{gid}, $3pgame->id);
   is ($games[0]->{side}, 'b');
   is ($games[1]->{side}, 'b');
   is ($games[0]->{opponents}, ['bthathbth']);
   is ($games[0]->{opponents}, [qw/bthathbth gambith/]);
}

