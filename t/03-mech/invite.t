use strict;
use warnings;
use Test::More tests => 23;

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;

$mech->get_ok("/invite");
$mech->content_contains("passwd", "not logged in: go to login");


my @players = create_players ($schema, qw/stinky_pete exactly_man pointy_haired_carl/);


$mech->login_as('stinky_pete');
$mech->get_ok("/invite");
$mech->content_like (qr/form.*cycle.*text.*form/i, "/invite probably has movecycle controls");

$mech->login_as('exactly_man');
$mech->get_ok("/messages");
$mech->content_like (qr'stinky_pete', "exactly_man has invite message from stinky_pete");

