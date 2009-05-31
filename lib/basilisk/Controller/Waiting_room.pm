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

#This is to be removed.
sub add : PathPart Chained('waiting_room') {
   my ($self, $c) = @_;
   unless ($c->session->{logged_in}){
      $c->detach('render',['log in before submiting waiting games']);
   }
   my $player = $c->model('DB::Player')->find ({id => $c->session->{userid}});
   my $req = $c->request;
   my $form = $c->stash->{form}; #form from /waiting_room above
   if ($form->submitted_and_valid) {
      $c->stash->{msg} = 'form submitted...';
      
      my $other_games_count = $player->count_related ('proposed_games',{});
      if ($other_games_count >= 5){
         $c->detach('render',['an arbitrary limit (5) has been exceeded.']);
      }
      
      my $topo = $req->param('topology');
      my $h = $req->param('h');
      my $w = $req->param('w');
      my $ent_order = $req->param('ent_order');
      my $heisen = $req->param('heisengo');
      my ($random_phase, $random_place);
      
      # determine who goes first (as black)
      if ($ent_order eq 'p_first'){
         $ent_order = WGAME_ORDER_PROPOSER_FIRST;
      } elsif ($ent_order eq 'p_last'){
         $ent_order = WGAME_ORDER_PROPOSER_LAST;
      } else { #random
         $ent_order = WGAME_ORDER_RANDOM;
      }
      
      my $desc = $w .'x'. $h; # description of interesting rules
      $desc .= ", $topo" unless $topo eq 'plane';  #planes are not interesting
      
      #this is pretty much duplicated in Invitation.pm
      if ($heisen){
         $random_phase = $req->param('chance_rand_phase') || 0;
         $random_place = $req->param('chance_rand_placement') || 0;
         if ($random_phase or $random_place){
            $desc .= ", HeisenGo: ";
         }
         if ($random_phase == 1) {
            $desc .= "random squence of turns";
         }
         elsif ($random_phase) {
            $desc .= "turns " . int($random_phase*100) . "% random";
         }
            $desc .= ", " if $random_phase and $random_place;
         if ($random_place == 1) {
            $desc .= "inaccurate placement of stones";
         }
         elsif ($random_place) {
            $desc .= "stone placement " . int($random_place*100) . "% inaccurate";
         }
      }
      
      $c->model('DB')->schema->txn_do (sub{
         my $new_ruleset = $c->model('DB::Ruleset')->create ({ 
            h => $h,
            w => $w,
            rules_description => $desc,
         });
         unless ($topo eq 'plane'){
            $c->model('DB::Extra_rule')->create({
               rule => $topo,
               priority => 1,
               ruleset  => $new_ruleset->id,
            });
         }
         if ($heisen){
            #chop off decimal places less than .01
            my $rph = int($random_phase*100)/100;
            my $rpl = int($random_place*100)/100;
            my $heisenRule = "heisengo $rph,$rpl";
            $new_ruleset->create_related ('extra_rules', {
               rule => $heisenRule,
               priority => 2, #this should go?
            });
         }
         my $proposal = $player->create_related ('proposed_games',{
            quantity => $c->req->param('quantity'),
            ruleset => $new_ruleset->id,
            ent_order => $ent_order,
         });
         $c->stash->{msg} = 'proposal '.$proposal->id.' added';
      });
   }
   $c->detach('render');
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
