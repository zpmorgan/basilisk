use strict;
use warnings;

use Test::More tests => 3;

$ENV{CATALYST_DEBUG}=0; 
use_ok 'Test::WWW::Mechanize::Catalyst' => 'basilisk';

my $mech = Test::WWW::Mechanize::Catalyst->new;

$mech->get_ok("/"); # no hostname needed
is($mech->ct, "text/html", 'correct content type');
