#!/usr/bin/perl
use lib qw(lib);
use strict;
use warnings;
use basilisk::Schema;
my $dbfile = "basilisk.db";         
my $dsn = "dbi:SQLite:$dbfile";
my $schema = basilisk::Schema->connect( $dsn,)  or die "can't connect to database";

my @players = map {
   $schema->resultset('Player')->find(
      {name => $_}
   )
} qw/zpmorgan zpmorgan/;

my $new_ruleset = $schema->resultset('Ruleset')->create({
   h=>13,w=>13,
   phase_description => '0b 1w 0r 1b 0w 1r',
   rules_description => '2|3--antizen', 
}); 
$new_ruleset->create_related('extra_rules',{
               rule => 'torus',
	priority => 2,
});
my $game = $new_ruleset->create_related('games',{});
$game->create_related ('player_to_game', {
   pid  => $players[$_]->id,
   entity => $_,
}) for (0,1);

