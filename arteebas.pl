#!/usr/bin/perl
use Modern::Perl;
use JSON;
use FCGI;
my $json = new JSON;

use lib 'lib';
use lib::basilisk::Rulemap;



#my $fcgi_socket = FCGI::OpenSocket( '/tmp/realtime_basilisk.socket', 100000 );
#my $request = FCGI::Request(\*STDIN, \*STDOUT, \*STDERR, \%ENV, $fcgi_socket);

my $req = FCGI::Request();

# $games{id} = {events => [game events], rulemap => $rulemap, players => @players, result=>'B+2.5'}
# example $game_event = {type => 'move','message',etc. , msg=>$str' or move=> 'B H2', diff=>{diff}, }
my %games;
my %tables;
my %players;



sub process_input{
   my $input = shift;
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




while($req->Accept() >= 0) {
   
   my $input;
   {
      local $\;
      $input = <STDIN>;
   }
   #say STDERR $input;
   my $response = process_input ($json->decode ($input));
   #say STDERR $json->encode($output);
   
   print("Content-type: text/json\r\n\r\n");
   say $json->encode ($response);
   
   #$req->Finish();
}

say  $req->Accept();
