use strict;
use warnings;
use Test::More tests => 2;

use lib qw(t/lib lib);
use_ok( 'b_schema' );

my $schema;
ok($schema = b_schema->init_schema(1), 'create a test db' );





