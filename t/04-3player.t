use strict;
use warnings;
use Test::More tests => 29;
use JSON;

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;

#modify db
my @players = $schema->create_players (qw/king bishop pawn/);
my $game = $schema->create_game (6,6, '0b 1w 2r', @players);
my $gid = $game->id;

sub rx_side_on_board {
   my $side = shift;
   return qr/board_position [^\n]*"$side"/
}

$mech->login_as('king');
$mech->get_ok("/game/".$game->id);
#diag $mech->content;
$mech->content_contains("king", "/game/$gid contains 1st player name, 'king'");
$mech->content_contains("bishop", "/game/$gid contains 2nd player name, 'bishop'");
$mech->content_contains("pawn", "/game/$gid contains 3rd player name, 'pawn'");

$mech->content_contains("b.gif", "/game/$gid player1 stone img, b.gif");
$mech->content_contains("w.gif", "/game/$gid player2 stone img, w.gif");
$mech->content_contains("r.gif", "/game/$gid player3 stone img, r.gif");

#w and r players not allowed to move
$mech->login_as('bishop');
$mech->get_ok("/game/".$game->id."/move/2-2");
$mech->content_contains("not your turn", "w not allowed 1st move");
$mech->login_as('pawn');
$mech->get_ok("/game/".$game->id."/move/2-2");
$mech->content_contains("not your turn", "r not allowed 1st move");

$mech->login_as('king');
$mech->get_ok("/game/".$game->id."/move/0-0");
$mech->content_contains("success", "b allowed 1st move");
$mech->content_like (rx_side_on_board('b'), "b img on board");
like ($game->current_position, qr/b/, 'pos has b');

$mech->login_as('bishop');
$mech->get_ok("/game/".$game->id."/move/0-1");
$mech->content_contains("success", "r allowed 1st move");
$mech->content_like (rx_side_on_board('w'), "w img on board");
like ($game->current_position, qr/w/, 'pos has w');

$mech->login_as('pawn');
$mech->get_ok("/game/".$game->id."/move/1-0");
$mech->content_contains("success", "r allowed 1st move");
$mech->content_like (rx_side_on_board('r'), "r img on board");
like ($game->current_position, qr/r/, 'pos has r');

unlike ($game->current_position, qr/b/, 'b in corner was captured in db pos');
$mech->content_unlike (rx_side_on_board('b'), "no b stone on board after cap");

$mech->login_as('king');
$mech->get_ok("/game/".$game->id."/move/0-0");
$mech->content_contains("suicide", "b move with no libs is suicide");
unlike ($game->current_position, qr/b/, 'b suicide didnt work');

is ($game->last_move->captures, '0 0 1', 'capture is red');
