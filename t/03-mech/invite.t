use strict;
use warnings;
use Test::More tests => 23;

use lib qw(t/lib lib);
use b_schema;
use b_mech;

my $schema = b_schema->init_schema('populate');

use Test::WWW::Mechanize::Catalyst  qw/basilisk/;
my $mech = Test::WWW::Mechanize::Catalyst->new;

$mech->get_ok("/invite");
$mech->content_contains("passwd", "not logged in: go to passwd");


my @players = map {
   $schema->resultset('Player')->create( {
      name=> $_,
      pass=> Util::pass_hash ($_)
   })}
   (qw/stinky_pete exactly_man pointy_haired_carl/);


login_as ($mech, 'stinky_pete');
$mech->get_ok("/invite");
$mech->content_like (qr/game type/i, "/invite has controls");


