use strict;
use warnings;

use Test::More tests => 17;

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;

$mech->get_ok("/");
is($mech->ct, "text/html", 'correct content type');

my @players = $schema->create_players  qw/Microscopium Cancer/;
my $micros_id = $players[0]->id;

my $oldRcount = $schema->resultset('Ruleset')->count({});
my $oldWcount = wgames_from_page();

$mech->get_ok("/waiting_room"); #diag $mech->content;
$mech->content_lacks('Logged in');
$mech->content_lacks('<form'); #must login to propose to room

$mech->login_as('Microscopium');
$mech->content_contains('Logged in');
$mech->get_ok("/waiting_room");
$mech->content_contains('<form'); #can propose to room

$mech->form_with_fields( qw/topology/ );
$mech->submit_form_ok(
        {fields => {
            topology => 'torus',
            h => $_,
            w => $_,
        }}, 'wgame-add form submission') for (10..12);
$mech->content_contains('added');

is ($schema->resultset('Ruleset')->count({}), $oldRcount+3, 
   'some ruleset created');
my @wgames = wgames_from_page();
is (@wgames, $oldWcount+3,
   'some waiting game created');

$mech->get_ok("/waiting_room/join/".$wgames[1]);
$mech->content_contains('oined', 'looks like waiting game is joined'); #can propose to room

is (wgames_from_page(), $oldWcount+2, 'one less wgame from page');

sub wgames_from_page{
   $mech->get('/waiting_room');
   my @waitings = $mech->content =~ m|waiting_room/view/(\d+)"|g;
   return (@waitings);
}
