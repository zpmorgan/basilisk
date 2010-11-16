package basilisk::Controller::RT;

use Modern::Perl;

use parent 'Catalyst::Controller';
use JSON;


__PACKAGE__->config->{namespace} = 'rt';


sub game : Local {
   my ( $self, $c ) = @_;
   my $response = {};
   my $req = $c->request;
   
   my $action = $req->param('action');
   my $gameid = $req->param('gameid');
   my $after = $req->param('after');
   my $game = $c->model('DB::Game')->find($gameid);
   unless ($game){
      $c->detach ( 'err_in_shame', ['game not found']);
   }
   #my @players = $game->players;
   
   
   if ($action eq 'enter_game'){
      $response->{status} = 'accept';
      #$response->{gameid} = $gameid;
      $response->{ruleset} = {
         rules             => from_json $game->rules,
         phase_description => $game->phase_description,
         rules_description => $game->rules_description,
         time_system       => $game->time_system,
         main_time         => $game->main_time,
         secondary_time    => $game->secondary_time,
         time_periods      => $game->time_periods,
      };
      #$response->{players} = \@players;
      $after = 0;
   }
   if ($action eq 'ping'){ #this is basically a status update..
      $response->{status} = 'pong';
      my @events = $game->get_events_after($after);
   }
   if ($action eq 'move'){
      my $move = $req->param('move');
      my $result = $game->attempt_move($move);
   }
   
   $response->{after} = $after;
   my @events = $game->events();
   push @events, {type=> 'move', delta=>{'4-5', [add => {stone=>'b'}]} };
   $response->{events} = \@events;
   
   $c->response->content_type ('text/json');
   $c->response->body (to_json $response);
}


sub err_in_shame : Private{
   my ( $self, $c, $err ) = @_;
   my $response = {err => $err};
   $c->response->content_type ('text/json');
   $c->response->body (to_json $response);
  # $c->response->status(200);
   $c->detach;
}



