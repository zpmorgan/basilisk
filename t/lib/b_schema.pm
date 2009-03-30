package # hide from PAUSE
    b_schema;

#This creates & populates a basilisk.db for testing purposes

use strict;
use warnings;
use basilisk::Schema;


sub _sqlite_dbfilename {
    return "t/var/basilisk.db";
}

sub init_schema {
   my $self = shift;
   my $populate = shift;
   
   my $dbfile = _sqlite_dbfilename();
   unlink $dbfile if -e $dbfile ;
   
   my $dsn = "dbi:SQLite:$dbfile";
   my $dbuser = '';
   my $dbpass = '';
   my $schema;
   $schema = basilisk::Schema->connect( $dsn, $dbuser, $dbpass),
       or die "can't connect to database";
   $schema->deploy;
   
   if ($populate){
      #create 8 players
      $schema->resultset('Player')->create(
        {name=> $_,
         pass=> Util::pass_hash ($_)}
      ) for qw/foo bar baz a b c d e/;
      
      my $new_ruleset = $schema->resultset('Ruleset')->create({h=>6,w=>6}); #default everything
      my $new_game = $new_ruleset->create_related( 'games', {});
      $new_game->create_related ('player_to_game', {
         pid  => 1, #foo
         entity => 0,
      });
      $new_game->create_related ('player_to_game', {
         pid  => 2, #bar
         entity => 1,
      });
      
   }
   
   return $schema;
}
   
1
