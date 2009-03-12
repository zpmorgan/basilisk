use strict;
use warnings;

use Test::More tests => 12;

use_ok 'Test::WWW::Mechanize::Catalyst' => 'basilisk';

my $mech = Test::WWW::Mechanize::Catalyst->new;
$mech->get_ok("/"); # no hostname needed
is($mech->ct, "text/html", 'correct content type');

$mech->get_ok("/players");
$mech->content_contains("cannon", "players list has cannon");
$mech->content_contains("pagehead", 'page contains head');
$mech->content_contains("Save the basilisks", 'page contains foor');

$mech->get_ok("/login");
$mech->content_contains("Log in", "make sure we are not logged in");
$mech->form_with_fields( qw/username passwd/ );
$mech->submit_form_ok(
        {fields => {
            username => 'cannon',
            passwd => 'cannon',
        }}, 'login form submission');

$mech->get_ok("/waiting_room");
$mech->content_contains("Logged in as: cannon", "Logged in as: cannon");
