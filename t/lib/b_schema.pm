package # hide from PAUSE
    b_schema;

use strict;
use warnings;
use basilisk::Schema;


sub _sqlite_dbfilename {
    return "t/var/basilisk.db";
}



sub init_schema {
   my $self = shift;
   
   my $dbfile = "t/var/mojomojo.db";
   unlink $dbfile if -e $dbfile ;
   
   my $dsn = "dbi:SQLite:$dbfile";
   my $dbuser = '';
   my $dbpass = '';
   my $schema;
   $schema = basilisk::Schema->connect( $dsn, $dbuser, $dbpass),
       or die "can't connect to database";
   $schema->deploy;
   return 1;
}
   
1
