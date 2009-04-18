package basilisk::Controller::Waiting_room;

use parent 'Catalyst::Controller::HTML::FormFu';
use strict;
use warnings;
#__PACKAGE__->config->{namespace} = '';


sub default :Path {
   my ( $self, $c ) = @_;
   $c->forward('waiting_room');
   $c->forward('render');
}


sub waiting_room :Chained('/') PathPart CaptureArgs(0) Form{
   my ( $self, $c ) = @_;
   
   #1st define the form to add waiting games
   my $form = $self->form;
   $form->action (Util::URL_BASE() .'/waiting_room/add');
   my $gamecount = $form->element({ 
      type => 'Text', 
      name => 'quantity',
      label => 'Quantity',
      default  => 1,
      size  => 1,
   });
   $gamecount->constraint('Integer');
   $gamecount->constraint('Required');
   $gamecount->constraint ({type=> 'Range', min => 1, max => 9});
   #the other fields:
   $form->load_config_file('ruleset_proposal.yml');
   my $sbmt = $form->element({ 
      type => 'Submit', 
      name => 'submit',
      value => 'Submit waiting game',
   });
   $form->process;
   $c->stash->{form} = $form;
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
   $c->stash->{proposal_info}->{ent_order} = Util::wgame_order_str ($wgame->ent_order);
   
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
   if ($wgame->ent_order == Util::WGAME_ORDER_PROPOSER_LAST()){
      ($b,$w) = ($w,$b)
   }
   elsif ($wgame->ent_order == Util::WGAME_ORDER_RANDOM()){
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

sub add : PathPart Chained('waiting_room') {
   my ($self, $c) = @_;
   unless ($c->session->{logged_in}){
      $c->detach('render',['log in before submiting waiting games']);
   }
   my $form = $c->stash->{form}; #form from /waiting_room above
   if ($form->submitted_and_valid) {
      $c->stash->{msg} = 'form submitted...';
      
      my $topo = $c->req->param('topology');
      my $h = $c->req->param('h');
      my $w = $c->req->param('w');
      my $ent_order = $c->req->param('ent_order');
      
      # determine who goes first (as black)
      if ($ent_order eq 'p_first'){
         $ent_order = Util::WGAME_ORDER_PROPOSER_FIRST();
      } elsif ($ent_order eq 'p_last'){
         $ent_order = Util::WGAME_ORDER_PROPOSER_LAST();
      } else { #random
         $ent_order = Util::WGAME_ORDER_RANDOM();
      }
      
      my $desc = $w .'x'. $h; # description of interesting rules
      $desc .= ", $topo" unless $topo eq 'plane';  #planes are not interesting
      
      $c->model('DB')->schema->txn_do (sub{
         my $new_ruleset = $c->model('DB::Ruleset')->create ({ 
            h => $c->req->param('h'),
            w => $c->req->param('w'),
            rules_description => $desc,
         });
         unless ($topo eq 'plane'){
            $c->model('DB::Extra_rule')->create({
               rule => $topo,
               priority => 2,
               ruleset  => $new_ruleset->id,
            });
         }
         my $proposal = $c->model('DB::Game_proposal')->create({
            quantity => $c->req->param('quantity'),
            proposer => $c->session->{userid},
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
