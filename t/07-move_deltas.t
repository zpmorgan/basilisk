use strict;
use warnings;
use JSON;
use Test::More tests => 7;

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;




my @players = map {
   $schema->resultset('Player')->create( {
      name=> $_,
      pass=> Util::pass_hash ($_)
   })}
   (qw/redstorm ellpack eggshells/);



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
      pid  => $players[0]->id, #redstorm
      entity => 0,
   });
   $game->create_related ('player_to_game', {
      pid  => $players[1]->id, #ellpack
      entity => 1,
   });
   
   $mech->get_ok("/game/$gid/deltas");
   is($mech->ct, "text/json", 'correct content type');
   my $deltas = $mech->content;
   is ($deltas, '[{}]');
   
   
   #now give $game an initial position
   #deltas are not cached yet
   #so game/deltas should give initial pos data
   #as first entry in response
   my $board = Util::board_from_text ( 
   '000000
    0ww000
    000000
    000000
    0b0000
    000000', 6);
   my $pos_data = Util::pack_board($board);
   my $pos_row = $schema->resultset('Position')->create({
      ruleset => $ruleset->id,
      position => $pos_data,
   });
   $game->set_column ('initial_position' => $pos_row->id);
   $game->update;
   
   
   $mech->get_ok("/game/$gid/deltas");
   is($mech->ct, "text/json", 'correct content type');
   $deltas = $mech->content;
   like ($deltas, qr/^ \[\{ .* \}\] $/x); #at least looks like json nested arrays; display if fail
   $deltas = from_json($deltas);
   is_deeply ($deltas, 
   [
      {
         '1-1' => ['add', {stone => 'w'}],
         '1-2' => ['add', {stone => 'w'}],
         '4-1' => ['add', {stone => 'b'}],
      }
   ]);
}
