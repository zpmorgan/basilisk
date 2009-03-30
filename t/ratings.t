use strict;
use warnings;
use Test::More tests => 2;
use Util;


use lib qw(t/lib);
use_ok( 'b_schema' );

my $schema;
ok($schema = b_schema->init_schema(1), 'create a test db' );





