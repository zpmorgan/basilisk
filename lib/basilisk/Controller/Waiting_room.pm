package basilisk::Controller::Waiting_room;

use parent 'Catalyst::Controller::HTML::FormFu';
use strict;
use warnings;

use basilisk::Constants qw/URL_BASE
         WGAME_ORDER_PROPOSER_FIRST WGAME_ORDER_PROPOSER_LAST WGAME_ORDER_RANDOM
         wgame_order_str/;


sub default :Path {
   my ( $self, $c ) = @_;
   $c->forward('waiting_room');
   $c->forward('render');
}


sub waiting_room :Chained('/') PathPart CaptureArgs(0) Form{
   my ( $self, $c ) = @_;
   
   my $form = $self->form;
   $form->load_config_file('ruleset_proposal.yml');
   $form->action ($c->uri_for(''));
   $form->process;
   $c->stash->{form} = $form;
   if ($form->submitted_and_valid) {
      $c->forward('add_waiting_game');
   }
}

sub render: Private{
   my ($self, $c, $msg) = @_;
   my @waiting_rs = $c->model('DB::Game_proposal')->search( #todo:join with ruleset
      {},
      {join => ['proposer', 'ruleset'],
        '+select' => ['proposer.name', 'proposer.id', 'ruleset.rules_description'], 
        '+as'     => ['name', 'proposer_id', 'description'],
      },
   );
   
   my @waiting_games_info; #for TT
   for my $waiting(@waiting_rs) {
      push @waiting_games_info,{ #todo:topology? maybe generate some description string?
         id => $waiting->id,
         proposer => $waiting->get_column('name'),
         proposer_id => $waiting->get_column('proposer_id'),
         desc => $waiting->get_column('description'),
      }
   }
   $c->stash->{waiting_games_info} = \@waiting_games_info;
   if ($msg and $msg !~ /^\d+$/){ #ignore stray urlpath args..
      $c->stash->{msg} = $msg;
   }
   
   $c->stash->{title} = 'Waiting room';
   $c->stash->{template} = 'waiting_room.tt';
}

#look at a specific proposal
sub view : PathPart('view') Chained('waiting_room') Args(1) {
   my ($self, $c, $wgame_id) = @_;
   
   my $wgame = $c->model('DB::Game_proposal')->find({id => $wgame_id});
   unless ($wgame){ #err
      $c->detach('render', ["Sorry no waiting game with id $wgame_id"]);
   }
   $c->stash->{proposal_info}->{id} = $wgame_id;
   $c->stash->{proposal_info}->{quantity} = $wgame->quantity;
   $c->stash->{proposal_info}->{proposer} = $wgame->proposer;
   $c->stash->{proposal_info}->{rules_desc} = $wgame->ruleset->rules_description;
   $c->stash->{proposal_info}->{komi} = $wgame->ruleset->komi;
   $c->stash->{proposal_info}->{ent_order} = wgame_order_str ($wgame->ent_order);
   
   $c->detach('render');
}


sub join : PathPart Chained('waiting_room') Args(1) {
   my ($self, $c, $wgame_id) = @_;
   unless ($c->session->{logged_in}){
      $c->detach('render',['log in before submiting waiting games']);
   }
   my $wgame = $c->model('DB::Game_proposal')->find({id => $wgame_id});
   $c->detach('render',["wgame $wgame_id doesn't exist."]) unless $wgame;
   my $ruleset_id = $wgame->ruleset;
   
   my ($b,$w) = ($wgame->proposer->id, $c->session->{userid});
   if ($wgame->ent_order == WGAME_ORDER_PROPOSER_LAST){
      ($b,$w) = ($w,$b)
   }
   elsif ($wgame->ent_order == WGAME_ORDER_RANDOM){
      ($b,$w) = ($w,$b) if rand()<.5;
   }
   
   $c->model('DB')->schema->txn_do( sub{
      my $game = $c->model('DB::Game')->create({
         ruleset => $ruleset_id,
        # captures => '0 0', #caps in move table now
        # phase => 0, #as default.
      });
      $c->model('DB::Player_to_game')->create({
         gid => $game->id,
         pid => $b,
         entity => 0, # 0 -- black
         expiration => 0,
      });
      $c->model('DB::Player_to_game')->create({
         gid => $game->id,
         pid => $w,
         entity => 1, # 1 -- white
         expiration => 0,
      });
      $wgame->decrease_quantity;
      $c->stash->{joined} = $game->id
   });
   $c->detach('render');
}

sub add_waiting_game: Private{
   my ($self, $c) = @_;
   my $req = $c->request;
   my $form = $c->stash->{form}; #already validated by formfu
   my $ruleset;
   
   my $player = $c->model('DB::Player')->find ({id => $c->session->{userid}});
   my $other_games_count = $player->count_related ('proposed_games',{});
   if ($other_games_count >= 5){
      $c->detach('render',['an arbitrary limit (5) has been reached.']);
   }
   
   $c->model('DB')->schema->txn_do(  sub{
      my $ruleset = $c->forward ('Game_proposal', 'ruleset_from_form', ['wroom']);
      die $c->stash->{err} unless $ruleset;
      
      my $msg = $req->param('message');
      my $ent_order = $req->param('initial');
      # determine whether ents are randomized
      if ($ent_order eq 'random'){
         $ent_order = WGAME_ORDER_RANDOM;
      } elsif ($ent_order eq 'me'){
         $ent_order = WGAME_ORDER_PROPOSER_FIRST;
      } else { #'opponent'
         $ent_order = WGAME_ORDER_PROPOSER_LAST;
      }
      
      my $proposal = $player->create_related ('proposed_games',{
         quantity => $c->req->param('quantity'),
         ruleset => $ruleset->id,
         ent_order => $ent_order,
      });
      $c->stash->{msg} = 'proposal '.$proposal->id.' added';
   });
}

sub remove : PathPart Chained('waiting_room') Args(1) {
   my ($self, $c, $wgame_id) = @_;
   my $wgame = $c->model('DB::Game_proposal')->find({id => $wgame_id});
   return $c->detach('render',["wgame $wgame_id doesn't exist."]) unless $wgame;
   unless ($c->session->{logged_in}){
      $c->detach('render', ['log in before removing waiting games']);
   }
   unless ($c->session->{userid} == $wgame->proposer->id){
      $c->detach('render', ['This waiting game was proposed by someone else']);
   }
   $wgame->delete();
   $c->stash->{msg} = 'proposal '.$wgame->id.' deleted';
   $c->detach('render');
}
1
