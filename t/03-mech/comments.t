use strict;
use warnings;
use Test::More tests => 23;
use JSON;

use lib qw(t/lib lib);
use_ok( 'b_schema' );
use_ok( 'b_mech' );

my $schema;
ok($schema = b_schema->init_schema('populate'), 'create, populate a test db' );

use_ok 'Test::WWW::Mechanize::Catalyst' => 'basilisk';
my $mech = Test::WWW::Mechanize::Catalyst->new;

$mech->get_ok("/"); # no hostname needed
is($mech->ct, "text/html", 'correct content type');


#modify db
my @players = map {
   $schema->resultset('Player')->create( {
      name=> $_,
      pass=> Util::pass_hash ($_)
   })}
   (qw/Rat_King oscar blargles/);

my $new_ruleset = $schema->resultset('Ruleset')->create({h=>6,w=>6}); #default everything
my $game = $new_ruleset->create_related('games',{});
$game->create_related ('player_to_game', {
   pid  => $players[0]->id, #Rat_King
   entity => 0,
});
$game->create_related ('player_to_game', {
   pid  => $players[1]->id, #oscar
   entity => 1,
});


login_as ($mech, 'oscar');
$mech->get_ok("/game/$game->id");
$mech->content_contains("Logged in as: oscar", "login as oscar");
login_as ($mech, 'Rat_King');
$mech->get_ok("/game/$game->id");
$mech->content_contains("Logged in as: Rat_King", "change login");

# now insert a few intertwined moves and comments
# their time fields must all be different.
{
   #0 | Rat_King:Mark Hand Hector
   $game->create_related ('comments', {
      sayeth => $players[0]->id, #Rat_King
      comment => 'Mark Hand Hector',
      time => 1234567890,
   });

   $game->create_related ('moves', {
      movenum => 1,
      time => 1234567892,
      position_id => 1444,
      move => 'doesn"t surrender',
      phase => '0',
      captures => '0 0',
   });

   #1 | oscar:jadeite Arlene dnubietna
   $game->create_related ('comments', {
      sayeth => $players[1]->id, #oscar
      comment => 'jadeite Arlene dnubietna',
      time => 1234567894,
   });

   $game->create_related ('moves', {
      movenum => 2,
      time => 1234567896,
      position_id => 66,
      move => 'doesn"t surrender',
      phase => '1',
      captures => '0 0',
   });
   $game->create_related ('moves', {
      movenum => 3,
      time => 1234567898,
      position_id => 8888,
      moves => 'doesn"t surrender',
      phase => '0',
      captures => '0 0',
   });
   
   #3 | blargles:Christiane_Vlassi zo
   $game->create_related ('comments', {
      sayeth => $players[2]->id, #blargles
      comment => 'Christiane Vlassi zo',
      time => 1234567900,
   });
}

$mech->get_ok("/comments/" . $game->id);
is($mech->ct, "text/json", 'json content type for comments');
my $res = from_json ($mech->content);
isa_ok ($res, 'ARRAY');
is ($res->[0], 'success', '/comments/id returned success');

my @comments = @{$res->[1]};

is ($comments[0]{movenum}, 0, '1st comment movenum 0');
is ($comments[0]{comment}, 'Mark Hand Hector', '1st comment msg');
is ($comments[0]{commentator}, 'Rat_King', '1st commentator');

is ($comments[1]{movenum}, 1, '2nd comment movenum 1');
is ($comments[1]{comment}, 'jadeite Arlene dnubietna', '2nd comment msg');
is ($comments[1]{commentator}, 'oscar', '2nd commentator');

is ($comments[2]{movenum}, 3, '3rd comment movenum 3');
is ($comments[2]{comment}, 'Christiane Vlassi zo', '3rd comment msg');
is ($comments[2]{commentator}, 'blargles', '3rd commentator(blargles)');
