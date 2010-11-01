#!/usr/bin/perl -w

use lib qw(t/lib lib);
use b_schema;
use b_mech;
my $schema = b_schema->init_schema('populate');
my $mech = b_mech->new;

#not sure if we need this...
#$ENV{CATALYST_DEBUG}=0;
#specify test db path:
#$ENV{BASILISK_DSN}= 'dbi:SQLite:t/var/basilisk.db';

use Test::More;


BEGIN {
   $ENV{CATALYST_DEBUG}=0;
   $ENV{BASILISK_DSN}= 'dbi:SQLite:t/var/basilisk.db';
   #eval {require Test::WWW::Selenium::Catalyst};
   eval "use Test::WWW::Selenium::Catalyst 'basilisk'";
   plan skip_all => 'Selenium tests need Test::WWW::Selenium::Catalyst'
      if $@;
   plan tests => 3;
   
}
 
my @players = $schema->create_players (qw/elwin viper/);
my $game = $schema->create_game (6,6,'0b 1w',@players);
my $gid = $game->id;

#Test::WWW::Selenium::Catalyst->import('basilisk');
my $sel = Test::WWW::Selenium::Catalyst->start ({ port=>1500 });

$sel->open_ok("/game/$gid", 'confirm that we\'re talking to a db');
$sel->is_text_present_ok("elwin", 'confirm that we\'re talking to the same db');

$mech->login_as('elwin');
$mech->get_ok("/game/$gid/move/1-0");
$mech->login_as('viper');
$mech->get_ok("/game/$gid/move/0-0");
$mech->login_as('elwin');
$mech->get_ok("/game/$gid/move/0-1");

$sel->eval_ok('poll_for_update();');

#$sel->click_ok("link=Log in"); #probably sends you to the same page.
#$sel->wait_for_page_to_load_ok("30000", 'wait');
#$sel->wait_for_element_present($locator, $timeout);




__END__
BEGIN {
  $ENV{MOJOMOJO_CONFIG}='t/app/mojomojo.yml';
};
eval "use Test::WWW::Selenium::Catalyst 'MojoMojo'";
use Test::More;
plan skip_all => 'requires Test::WWW::Selenium::Catalyst' if $@;
plan tests => 11;

my $sel = Test::WWW::Selenium::Catalyst->start;

$sel->open_ok("/");
$sel->is_text_present_ok("Log in");
$sel->click_ok("link=Log in");
$sel->wait_for_page_to_load_ok("30000", 'wait');
$sel->type_ok("loginField", "admin");
$sel->type_ok("pass", "admin");
$sel->click_ok("//input[\@value='log in']");
$sel->wait_for_page_to_load_ok("30000");
$sel->is_text_present_ok("admin");
$sel->is_text_present_ok("Log out");
$sel->click_ok("link=Log out");


