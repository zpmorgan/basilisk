package arteebas;

use Modern::Perl;
use JSON;
#use FCGI;
my $json = new JSON;

use lib 'lib';
use basilisk::Rulemap;


#this file is meh.


# $games{id} = {events => [game events], rulemap => $rulemap, players => @players, result=>'B+2.5'}
# example $game_event = {type => 'move','message',etc. , msg=>$str' or move=> 'B H2', diff=>{diff}, }
my %games;
my %tables;
my %players;



sub process_input{
   my $blah = shift;
   my $cgi = shift;
   warn $cgi->PrintEnv;
   #warn values %{$cgi};
   die $cgi->{".cgi_error"} if $cgi->{".cgi_error"};
   my $input = {};
   my $context = $input->{context};
   my $action = $input->{action};
   my $response = {};
   
   if ($context eq 'game'){
      if ($action eq 'enter_game'){
         $response->{status} = 'accept';
         $response->{gameid} = 42;
      }
      if ($action eq 'ping'){ #this is basically a status update..
         $response->{status} = 'pong';
      }
      if ($action eq 'move'){
         
      }
   }
   return $response;
}

1;
