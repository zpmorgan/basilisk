#!/usr/bin/perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../lib";
use basilisk::Schema;

my ($dsn, $user, $pass) = ('dbi:SQLite:basilisk.db');

my $schema = basilisk::Schema->connect($dsn, $user, $pass) or
  die "Failed to connect to database";

print "Deploying schema to $dsn\n";
$schema->deploy;


#make up some data
my @players;
my $rs = $schema->resultset('Player');
my $row = $rs->create({
    name=>"guest",
    pass=>"guestpass"
});
push @players, $row->get_column('id');
$row = $rs->create({
    name=>"cannon",
    pass=>"cannon"
});
push @players, $row->get_column('id');$row = $rs->create({
    name=>"georgia",
    pass=>"p"
});
push @players, $row->get_column('id');


my $ruleset_rs = $schema->resultset('Ruleset');

my $new_ruleset = $ruleset_rs->create({size => 19}); #default everything
my $ruleset_id = $new_ruleset->get_column('id');

my $game_rs = $schema->resultset('Game');
my $new_game = $game_rs->create({
   ruleset => $ruleset_id,
});
my $newgame_id = $new_game->get_column('id');

my $p2g_rs = $schema->resultset('Player_to_game');
$p2g_rs->create({
   pid  => $players[1],
   gid  => $newgame_id,
   side => 0,
   'time_remaining' => 0,
});
$p2g_rs->create({
   pid  => $players[2],
   gid  => $newgame_id,
   side => 1,
   'time_remaining' => 0,
});


