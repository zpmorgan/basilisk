#!/usr/bin/perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../lib";
use basilisk::Schema;
use basilisk::Util;

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
    name=>"guest",
    pass=> Util::pass_hash "guestpass"
});
$row = $player_rs->create({
    name=>"cannon",
    pass=> Util::pass_hash "cannon"
});
$row = $player_rs->create({
    name=>"georgia",
    pass=> Util::pass_hash "georgia"
});

#make generic empty game with cannon and georgia
my $ruleset_rs = $schema->resultset('Ruleset');
my $new_ruleset = $ruleset_rs->create({size => 6}); #default everything

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


#2nd game--make toroidal, with some initial position#initialize with some position.
my $ruleset_2 = $ruleset_rs->create({
   size => 9,
 #  wrap_ns => 1,
 #  wrap_ew => 1, #need extra_rule entries for these
});
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
   side => 1,
   expiration => 0,
});
$p2g_rs->create({
   pid  => 2,
   gid  => $new_game_2->id,
   side => 2,
   expiration => 0,
});
