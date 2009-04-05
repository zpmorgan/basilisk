#!/usr/bin/perl
use lib qw(lib);
use strict;
use warnings;

die 'need 3 players' unless @ARGV == 3;

use basilisk::Schema;
my $dbfile = "basilisk.db";         
my $dsn = "dbi:SQLite:$dbfile";
my $schema = basilisk::Schema->connect( $dsn,)  or die "can't connect to database";

my @players = map {
   $schema->resultset('Player')->find(
      {name => $_}
   )
} @ARGV;

@ARGV = grep {$_} @ARGV;
die 'need 3 players' unless @ARGV == 3;


my $new_ruleset = $schema->resultset('Ruleset')->create({
   h=>13,w=>13,
   phase_description => '0b 1w 2r',
   rules_description => '3-FFA',
}); #3-player ffa
my $game = $new_ruleset->create_related('games',{});
$game->create_related ('player_to_game', {
   pid  => $players[0]->id,
   entity => 0,
});
$game->create_related ('player_to_game', {
   pid  => $players[1]->id,
   entity => 1,
});
$game->create_related ('player_to_game', {
   pid  => $players[2]->id,
   entity => 2,
});
