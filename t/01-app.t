use strict;
use warnings;
use Test::More tests => 2;

use lib qw/lib/;

BEGIN { use_ok 'Catalyst::Test', 'basilisk' }

ok( request('/')->is_success, 'Request should succeed' );
