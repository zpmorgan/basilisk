use strict;
use warnings;
use Test::More tests => 2;

use lib qw/lib/;

#So cat doesn't print out all it's junk:
$ENV{CATALYST_DEBUG}=0;

BEGIN { use_ok 'Catalyst::Test', 'basilisk' }

ok( request('/')->is_success, 'Request should succeed' );
