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




my @players = $schema->create_players (qw/redstorm ellpack eggshells/);


#begin with an empty board, b and w,
{
   my $game = $schema->create_game (6,6, '0b 1w', @players[0,1]);
   my $gid = $game->id;
   my $ruleset = $game->ruleset;
   
   $mech->get_ok("/game/$gid/deltas");
   is($mech->ct, "text/json", 'correct content type');
   my $deltas = $mech->content;
   is ($deltas, '[{}]');
   
   
   #now give $game an initial position
   #deltas are not cached yet
   #so game/deltas should give initial pos data
   #as first entry in response
   my $board = board_from_text ( 
   '000000
    0ww000
    000000
    000000
    0b0000
    000000', 6);
   my $pos_data = pack_board($board);
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




#begin with an irrelevant board,
#move enough to make a capture,
#and then check deltas
{
   my $game = $schema->create_game (6,6,'0b 1w', @players[0,1]);
   my $gid = $game->id;
   my $ruleset = $game->ruleset;
   
   my $board = board_from_text ( 
   '000000
    000000
    000000
    000000
    000000
    00000b', 6);
   my $pos_data = pack_board($board);
   my $pos_row = $schema->resultset('Position')->create({
      ruleset => $ruleset->id,
      position => $pos_data,
   });
   
   $game->set_column('initial_position' => $pos_row->id);
   $game->update;
   
   $mech->login_as('redstorm');
   $mech->get_ok("/game/$gid/move/0-1");
   $mech->login_as('ellpack');
   $mech->get_ok("/game/$gid/move/0-0");
   $mech->login_as('redstorm');
   $mech->get_ok("/game/$gid/move/1-0");
   $mech->get_ok("/game/$gid/deltas");
   is($mech->ct, "text/json", 'correct content type');
   my $deltas = $mech->content;
   $deltas = from_json($deltas);
   is_deeply ($deltas, 
   [
      {
         '5-5' => ['add', {stone => 'b'}],
      }, #initially not much here
      {
         '0-1' => ['add', {stone => 'b'}],
      },
      {
         '0-0' => ['add', {stone => 'w'}],
      },
      {
         '1-0' => ['add', {stone => 'b'}],
         '0-0' => ['remove', {stone => 'w'}],
      }
   ]);
}
