#!/usr/bin/perl -w

use lib qw(t/lib lib);
use b_schema;
my $schema = b_schema->init_schema('populate');

eval "use Test::WWW::Selenium::Catalyst 'basilisk'";
use Test::More;
if $@{
   plan skip_all => 'requires Test::WWW::Selenium::Catalyst';
   exit
}
plan tests => 5;


my @players = $schema->create_players (qw/elwin viper/);
my $game = $schema->create_game (6,6,'0b 1w',@players);
my $gid = $game->id;


my $sel = Test::WWW::Selenium::Catalyst->start ({port => 3030});

$sel->open_ok("/");
$sel->is_text_present_ok("Log in");
$sel->click_ok("link=Log in"); #probably sends you to the same page.
$sel->wait_for_page_to_load_ok("30000", 'wait');





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
