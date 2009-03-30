use strict;
use warnings;
use Test::More tests => 5;
#use basilisk::Util;


use lib qw(t/lib);
use_ok( 'b_schema' );


my $schema;
ok($schema = b_schema->init_schema(1), 'create&populate a test db' );

is ($schema->resultset('Player')->count(), 8, 'players inserted');

my $game = $schema->resultset('Game')->find({});
isa_ok ($game, 'basilisk::Schema::Game');

is ($game->players->count, 2, '2 players in game');

