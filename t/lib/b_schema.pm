package # hide from PAUSE?
    b_schema;

#This creates & populates a basilisk.db for testing purposes
#and returns a schema with player/game creation methods

use strict;
use warnings;
use parent 'basilisk::Schema';

use basilisk::Util qw/pass_hash/;

#So cat doesn't print out all its junk:
$ENV{CATALYST_DEBUG}=0;
#specify test db path:
$ENV{BASILISK_DSN}= 'dbi:SQLite:t/var/basilisk.db'; 

sub _sqlite_dbfilename {
    return "t/var/basilisk.db";
}

sub init_schema {
   my $class = shift;
   my $action = shift;
   
   my $dbfile = _sqlite_dbfilename(); 
   unless ($action eq 'use existing'){
      unlink $dbfile if -e $dbfile
   }
   
   my $dsn = "dbi:SQLite:$dbfile";
   my $dbuser = '';
   my $dbpass = '';
   my $schema;
   $schema = basilisk::Schema->connect( $dsn, $dbuser, $dbpass),
       or die "can't connect to database";
   
   unless ($action eq 'use existing'){
      $schema->deploy
   }
   if ($action eq 'populate'){
      #create 8 players
      $schema->resultset('Player')->create(
        {name=> $_,
         pass=> pass_hash ($_)}
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
   bless $schema, $class;
   return $schema;
}


sub create_players{
   my ($self, @names) = @_;
   my @rows;
   for (@names){
      my $row = $self->resultset('Player')->create({
         name=> $_,
         pass=> pass_hash ($_),
      });
      push @rows, $row;
   }
   return @rows;
}

sub create_game{
   my ($self, $h, $w, $pd, @players) = @_;
   
   my $ruleset = $self->resultset('Ruleset')->create({
      h=>6,w=>6,
      phase_description => $pd,
   });
   
   my $game = $ruleset->create_related('games',{});
   
   for (0..$#players){
      $game->create_related ('player_to_game', {
         pid  => $players[$_]->id,
         entity => $_,
      });
   }
   return $game
}

sub game{
   my ($self, $gid) = @_;
   return $self->resultset('Game')->find ({id => $gid})
}


1
