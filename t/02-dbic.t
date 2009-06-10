use strict;
use warnings;
use Test::More tests => 27;


use lib qw(t/lib lib);
use_ok( 'b_schema' );


my $schema;
ok($schema = b_schema->init_schema('populate'), 'create&populate a test db' );

is ($schema->resultset('Player')->count(), 8, 'players inserted');

{
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
}

#here, test $player->games_to_move, which returns info on games in which it is $player's turn
{
   my @players = $schema->create_players (qw/thelma bthathbth gambith/);
   my $game1 = $schema->create_game (5,5, '0b 1w', @players[0,1]);
   my $game2 = $schema->create_game (5,5, '0b 1w', @players[1,2]);
   my $game3 = $schema->create_game (5,5, '0b 1w', @players[2,0]);
   my $p3game = $schema->create_game (5,5, '0b 1w 2r', @players);
   my $selfgame = $schema->create_game (5,5, '0b 1w', @players[0,0]);
   
   my @games = $players[0]->games_to_move();
   @games = sort {$a->{id} <=> $b->{id}} @games;
   
   is (@games, 3, 'themla has 4 games.');
   #diag join '|||', map {$_->{id}} @games;
   #is ($games[0]->{id}, $game1->id, 'game1 id');
   #is ($games[1]->{id}, $game3->id);
   #is ($games[2]->{id}, $p3game->id);
   #is ($games[3]->{id}, $selfgame->id);
   for my $g ($game1,$p3game,$selfgame){
      ok ((grep {$_->{id} == $g->id} @games), 'returns game '.$g->id.' for thelma')
   }
   ok ((grep {$_->{id} == $game3->id} @games) == 0,
      "games_to_move doesnt return game3. it's gambith's turn."); 
   is ($games[0]->{number_moves}, 0);
   is ($games[0]->{players}->{0}->{name}, 'thelma');
   is ($games[0]->{players}->{1}->{name}, 'bthathbth');
   is ($games[0]->{players}->{0}->{id}, $players[0]->id);
   ok (!$games[0]->{only_self});
   ok (!$games[1]->{only_self});
   ok ( $games[2]->{only_self});
   is (keys %{$games[1]->{players}}, 3);
   is (keys %{$games[2]->{players}}, 2);
}

