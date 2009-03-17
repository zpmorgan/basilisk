use strict;
use warnings;
use Test::More tests => 2;
use Util;


use lib qw(t/lib);
use_ok( 'b_schema' );

my $schema;
ok($schema = b_schema->init_schema(), 'create a test db' );



$schema->resultset('Player')->create(
  {name=> $_,
   pass=> Util::pass_hash ""}
) for qw/foo bar baz a b c d e/;
is ($schema->resultset('player')->count(), 8, 'player insertion');



