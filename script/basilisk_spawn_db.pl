#!/usr/bin/env perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../lib";
use basilisk::Schema;
use basilisk::Util qw/pass_hash pack_board board_from_text/;

my $dbfile = 'basilisk.db';
unlink $dbfile if -e $dbfile;

my ($dsn, $user, $pass) = ("dbi:SQLite:$dbfile");

my $schema = basilisk::Schema->connect($dsn, $user, $pass) or
  die "Failed to connect to database";

print "Deploying schema to $dsn\n";
$schema->deploy;


#make up some data
my $player_rs = $schema->resultset('Player');
my $row = $player_rs->create({
    name=>"plutocrat",
    pass=> pass_hash "s4p5i6k7e"
});
$row = $player_rs->create({
    name=>"cannon",
    pass=> pass_hash "cannon"
});
$row = $player_rs->create({
    name=>"georgia",
    pass=> pass_hash "georgia"
});

#make empty vanilla game with cannon and georgia
my $ruleset_rs = $schema->resultset('Ruleset');
my $new_ruleset = $ruleset_rs->create({h=>6,w=>6}); #default everything

my $game_rs = $schema->resultset('Game');
my $new_game = $game_rs->create({
   ruleset => $new_ruleset->id,
});

my $p2g_rs = $schema->resultset('Player_to_game');
$p2g_rs->create({
   pid  => 2, #cannon
   gid  => $new_game->id,
   entity => 0,
   expiration => 0,
});
$p2g_rs->create({
   pid  => 3, #georgia
   gid  => $new_game->id,
   entity => 1,
   expiration => 0,
});


#2nd game--make toroidal, with some initial position#initialize with some position.
my $ruleset_2 = $ruleset_rs->create({
   h => 9,
   w => 9,
 # other_rules => {topo: foo}
});
my $board2 = 
'000w00000
00000000b
b000000bw
00wbw0000
0wbbbw000
00www0000
00000000w
0000000wb
00bwb00b0';
my @board2 = map {[split '', $_]} split "\n",$board2;
my $pos_data = pack_board(\@board2);
my $pos_row = $schema->resultset('Position')->create({
   ruleset => $ruleset_2->id,
   position => $pos_data,
});

my $new_game_2 = $game_rs->create({
   ruleset => $ruleset_2->id,
   initial_position => $pos_row->id,
});
#give cannon both sides.
$p2g_rs->create({
   pid  => 2,
   gid  => $new_game_2->id,
   entity => 0,
   expiration => 0,
});
$p2g_rs->create({
   pid  => 2,
   gid  => $new_game_2->id,
   entity => 1,
   expiration => 0,
});

#game 3 is ready for scoring
my $board3 = 
'w w 0 w b b b 0 0
 w b w b 0 b b 0 b
 w 0 w w b b b b 0
 w w w 0 w b 0 0 b
 0 w w 0 0 w b b 0
 0 0 w w w w w b 0
 0 w w w 0 b w b w
 w b 0 w 0 b b w 0
 0 w 0 w b 0 w 0 0';
my $pos_row3 = $schema->resultset('Position')->create({
   ruleset => $ruleset_2->id,
   position => pack_board (board_from_text($board3, 9)),
});
my $new_game_3 = $game_rs->create({
   ruleset => $ruleset_2->id,
   initial_position => $pos_row3->id,
});
#give cannon both sides again.
$p2g_rs->create({
   pid  => 2,   gid  => $new_game_3->id,
   entity => 0,   expiration => 0,
});
$p2g_rs->create({
   pid  => 2,   gid  => $new_game_3->id,
   entity => 1,   expiration => 0,
});
