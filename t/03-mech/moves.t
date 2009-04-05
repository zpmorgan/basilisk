use strict;
use warnings;
use Test::More tests => 18;
use JSON;

use lib qw(t/lib lib);
use_ok( 'b_schema' );
use_ok( 'b_mech' );
my $schema;
ok($schema = b_schema->init_schema('populate'), 'create, populate a test db' );

my $gid;
sub thegame{
   $schema->resultset('Game')->find ({id => $gid})
}

use_ok 'Test::WWW::Mechanize::Catalyst' => 'basilisk';
my $mech = Test::WWW::Mechanize::Catalyst->new;

my $p = $schema->resultset('Player')->create( {
   name=> 'Vaurien',
   pass=> Util::pass_hash ('Vaurien')
});
my $new_ruleset = $schema->resultset('Ruleset')->create ({h=>6,w=>6});
my $game = $new_ruleset->create_related('games',{});
$gid = $game->id;
$game->create_related ('player_to_game', {
   pid  => $p->id,
   entity => $_,
})  for (0,1);

$mech->get_ok("/");

login_as ($mech, 'Vaurien');
$mech->content_contains("Logged in as: Vaurien", "login as Vaurien");

is (thegame->phase, 0, 'starting phase of new game');

$mech->get_ok('/game/' . $game->id);
$mech->title_like ( qr/move 0/i , 'correct initial movenum in title');
$mech->get_ok('/game/' . $game->id . '/move/3-5'); #f3
$mech->title_like ( qr/move 1/i , 'move succeeds');
diag $mech->title;

is (thegame->phase, 1, 'game phase after move1');
my $move = thegame->find_related ('moves', {});
is ($move->phase, 0, '1st move\'s phase is 0');
is ($move->move, '{3-5}', '1st move\'s points to correct node');

$mech->get_ok('/game/' . $game->id . '/allmoves');
is($mech->ct, 'text/json', 'correct content type');
my $res = from_json ($mech->content);

is ($res->[0], 'success', 'success response from /game/\d/allmoves');
is (@{$res->[1]}, 1, 'correct number of moves');
