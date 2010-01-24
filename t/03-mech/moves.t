use strict;
use warnings;
use Test::More tests => 17;
use JSON;

use lib qw(t/lib lib);
use_ok( 'b_schema' );
my $schema;
ok($schema = b_schema->init_schema('populate'), 'create, populate a test db' );

use_ok( 'b_mech' );
my $mech = b_mech->new;

my @players = $schema->create_players (qw/Vaurien/);
my $game = $schema->create_game (6,6, '0b 1w', @players[0,0]);
my $gid = $game->id;

$mech->get_ok("/");
$mech->login_as('Vaurien');
$mech->content_contains("Logged in as: Vaurien", "login as Vaurien");

is ($schema->game($gid)->phase, 0, 'starting phase of new game');

$mech->get_ok('/game/' . $game->id);
$mech->title_like ( qr/move 0/i , 'correct initial movenum in title');
$mech->get_ok('/game/' . $game->id . '/move/3-5'); #f3
$mech->title_like ( qr/move 1/i , 'move succeeds');
#diag $mech->title;

is ($schema->game($gid)->phase, 1, 'game phase after move1');
my $move = $schema->game($gid)->find_related ('moves', {});
is ($move->phase, 0, '1st move\'s phase is 0');
is ($move->move, '{3-5}', '1st move\'s points to correct node');

$mech->get_ok('/game/' . $game->id . '/allmoves');
is($mech->ct, 'text/json', 'correct content type');
my $res = from_json ($mech->content);

is ($res->[0], 'success', 'success response from /game/\d/allmoves');
is (@{$res->[1]}, 1, 'correct number of moves');
