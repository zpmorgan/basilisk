use strict;
use warnings;

use Test::More tests => 18;

use lib qw(t/lib lib);
use_ok 'b_schema';
my $schema = b_schema->init_schema('populate');
use_ok 'b_mech';
my $mech = b_mech->new;

$mech->get_ok("/"); # no hostname needed
is($mech->ct, "text/html", 'correct content type');

$mech->get_ok("/players"); #diag $mech->content;
$mech->content_contains("foo", "players list has cannon");
$mech->content_contains("pagehead", 'page contains head');
$mech->content_contains("Save the basilisks", 'page contains foot');

$mech->get_ok("/login");
$mech->content_contains("Log in", "make sure we are not logged in");
$mech->form_with_fields( qw/username passwd submit/ );
$mech->submit_form_ok(
        {fields => {
            username => 'foo',
            passwd => 'foo',
        }}, 'login form submission');
#diag $mech->content if $mech->title =~ /message/;

#$mech->get_ok("/waiting_room");
$mech->content_contains("Logged in as: foo", "Logged in as: foo");

$mech->get_ok("/logout");
$mech->content_contains("Log in", "logging out");


#Now, make sure that data modifications made in this test script
# will show up on the web server

$schema->resultset('Player')->create(
        {name=> 'Bruyer',
         pass=> Util::pass_hash ('Bruyer')});
is ($schema->resultset('Player')->count ({name => 'Bruyer'}), 1, 'inserted 1 more player');

$mech->get_ok("/login");
$mech->form_with_fields( qw/username passwd/ );
$mech->submit_form_ok(
        {fields => {
            username => 'Bruyer',
            passwd => 'Bruyer',
        }}, 'login form submission');

#diag $mech->content;
$mech->content_contains("Logged in as: Bruyer", "login immediately after creating the player");



