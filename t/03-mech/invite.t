use strict;
use warnings;
use Test::More tests => 13;

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;

$mech->get_ok("/invite");
$mech->content_contains("passwd", "not logged in: go to login");


my @players = $schema->create_players qw/stinky_pete exactly_man pointy_haired_carl/;


$mech->login_as('stinky_pete');
$mech->get_ok("/invite");
$mech->content_like (qr/topology.*pd.*entity0/s, "/invite probably has movecycle controls");


$mech->form_with_fields( qw/topology pd entity0/ );
$mech->submit_form_ok(
        {fields => {
            pd => '0b 1w',
            entity0 => 'exactly_man',
            entity1 => 'stinky_pete',
            topology => 'plane',
            w => 12,
            h => 6,
        }}, 'invite form submission');

$mech->login_as('exactly_man');
$mech->get_ok("/messages");
$mech->content_like (qr'stinky_pete', "exactly_man has invite message from stinky_pete");


my $msg = $schema->resultset('Message')->find(
   {},
   { order_by => 'id DESC' }
);

$mech->login_as('stinky_pete');
$mech->get_ok("/mail/".$msg->id);
$mech->content_contains ('not your message');

$mech->login_as('exactly_man');
$mech->get_ok("/mail/".$msg->id);
$mech->content_lacks ('not your message');
$mech->content_contains ('stinky_pete');
$mech->content_contains ('invitation');



