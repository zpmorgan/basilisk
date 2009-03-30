package basilisk::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

my $dsn = $ENV{BASILISK_DSN};
$dsn ||= 'dbi:SQLite:basilisk.db';

__PACKAGE__->config(
   schema_class => 'basilisk::Schema',
   connect_info => [
      $dsn,
      #'dbi:SQLite:basilisk.db', 
   ],
);

1;
