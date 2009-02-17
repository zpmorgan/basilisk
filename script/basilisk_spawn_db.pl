#!/usr/bin/perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../lib";
use basilisk::Schema;
use basilisk::Util;

my ($dsn, $user, $pass) = ('dbi:SQLite:basilisk.db');

my $schema = basilisk::Schema->connect($dsn, $user, $pass) or
  die "Failed to connect to database";

print "Deploying schema to $dsn\n";
$schema->deploy ({add_drop_table => 1});


#make up some data
my $player_rs = $schema->resultset('Player');
my $row = $player_rs->create({
    name=>"guest",
    pass=>"guestpass"
});
$row = $player_rs->create({
    name=>"cannon",
    pass=>"cannon"
});
$row = $player_rs->create({
    name=>"georgia",
    pass=>"georgia"
});

#make generic empty game with cannon and georgia
my $ruleset_rs = $schema->resultset('Ruleset');
my $new_ruleset = $ruleset_rs->create({size => 19}); #default everything

my $game_rs = $schema->resultset('Game');
my $new_game = $game_rs->create({
   ruleset => $new_ruleset->id,
});

my $p2g_rs = $schema->resultset('Player_to_game');
$p2g_rs->create({
   pid  => 2, #cannon
   gid  => $new_game->id,
   side => 1,
   expiration => 0,
});
$p2g_rs->create({
   pid  => 3, #georgia
   gid  => $new_game->id,
   side => 2,
   expiration => 0,
});


#2nd game--make toroidal, with some initial position
my $board = 
'000200000
000000001
100000012
002120000
021112000
002220000
000000002
000000021
001210010';
my @board = map {[split '', $_]} split "\n",$board;
my $pos_data = Util::pack_board(\@board);
my $pos_row = $schema->resultset('Position')->create({
   size => 9,
   position => $pos_data,
});

#initialize with some position.
my $ruleset_2 = $ruleset_rs->create({
   size => 9,
   initial_position => $pos_row->id,
   wrap_ns => 1,
   wrap_ew => 1,
});

my $new_game_2 = $game_rs->create({
   ruleset => $ruleset_2->id,
});
#give cannon both sides.
$p2g_rs->create({
   pid  => 2,
   gid  => $new_game_2->id,
   side => 1,
   expiration => 0,
});
$p2g_rs->create({
   pid  => 2,
   gid  => $new_game_2->id,
   side => 2,
   expiration => 0,
});
