use strict;
use warnings;
use JSON;
use Test::More tests => 13;


use lib qw(t/lib lib);
use b_schema;
use b_mech;
my $schema = b_schema->init_schema('populate');
my $mech = b_mech->new;



my @players = $schema->create_players (qw/Sauron Deceiver/);

my $game = $schema->create_game (9,9, '0b 1w', @players);
my $gid = $game->id;

$mech->get_ok("/game/$gid/moves_after/0");

is($mech->ct, "text/json", 'correct moves_after content type');

my $res = from_json($mech->content);
is_deeply ($res, []);

#move 1
$mech->login_as('Sauron');
$mech->get_ok('/game/' . $game->id . '/move/0-0'); #a1 (excellent 1st move)

$mech->get_ok("/game/$gid/moves_after/0");
#warn $mech->content . "\n";
$res = from_json($mech->content);
is_deeply ($res, 
   [
      {
         delta => {"0-0" => ["add", {stone => "b"}]},
         phase => 0,
         move => '{0-0}',
      }
   ],
   'correct 1st move (delta,etc)'
);

$mech->get_ok("/game/$gid/moves_after/1");
$res = from_json($mech->content);
is_deeply ($res, [], 'present nothing after last move');



#move 2
$mech->login_as('Deceiver');
$mech->get_ok('/game/' . $game->id . '/move/1-1'); #b2


$mech->get_ok("/game/$gid/moves_after/2");
$res = from_json($mech->content);
is_deeply ($res, [], 'nothing after last move');



$mech->get_ok("/game/$gid/moves_after/0");
$res = from_json($mech->content);
is_deeply ($res, [
      {
         delta => {"0-0" => ["add", {stone => "b"}]},
         phase => 0,
         move => '{0-0}',
      },
      {
         delta => {"1-1" => ["add", {stone => "w"}]},
         phase => 1,
         move => '{1-1}',
      }
      
   ],
   'correct moves and order');
