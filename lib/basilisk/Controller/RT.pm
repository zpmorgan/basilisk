package basilisk::Controller::RT;

use Modern::Perl;

use parent 'Catalyst::Controller';
use JSON;


__PACKAGE__->config->{namespace} = 'rt';

#TODO: either use Catalyst::Action::DBIC::Transaction, or follow its advice.

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
   
   #should cache rulemap!
   $c->stash->{game} = $game;
   $c->forward('basilisk::Controller::Game', 'build_rulemap', [$game]);
   my $rulemap = $c->stash->{rulemap};
   my $rules = from_json $game->rules;
   
   my $total_game_events = $game->count_related('events') - 1;
   my $last_move = $game->last_move;
   
   
   if ($action eq 'enter_game'){
      $response->{status} = 'accept';
      #$response->{gameid} = $gameid;
      $response->{ruleset} = {
         rules             => $rules,
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
      my $node = $req->param('move');
      unless ($game->player_can_move ($c->session->{userid})){
         #ignore for now
    #     $c->detach ( 'err_in_shame', ['You do not have the right to make a move.']);
      }
      
      
      my $board = map {map {0} 1..$rules->{w}} 1..$rules->{h};
      my ($newboard, $evaluate_error, $caps) = $rulemap->evaluate_move($node);
      if ($evaluate_error){
         $c->forward('err_in_shame', ["not a valid move: $evaluate_error"]);
      }
      #it succeeded!
      $game->create_related('events',{
         event_number => $last_move->movenum + 1,
         
      });
      
      #die $result;
      #$c->forward('err_in_shame', [{result => $result}]);
   }
   
   $response->{after} = $after;
   my @events = $game->events();
   push @events, {
      type=> 'move', 
      delta=>{ add => {'4-5' => {stone=>'b'} } },
      movenum => 1 } if $after < 1;
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



