package basilisk::Controller::Invitation;

use parent 'Catalyst::Controller::HTML::FormFu';
use strict;
use warnings;
use List::Util qw/max shuffle/;
use List::MoreUtils qw/any/;

use basilisk::Constants qw/MESSAGE_NOT_SEEN MESSAGE_SEEN
         INVITE_ORDER_SPECIFIED INVITE_ORDER_RANDOM
         INVITE_OPEN INVITE_ACCEPTED INVITE_REJECTED
         INVITEE_ACCEPTED INVITEE_OPEN/;
__PACKAGE__->config->{namespace} = '';


#   $c->stash->{message} = 'Hello. Here\'s some wood:<br>' . 
#      '<img src="[% img_base %]/wood.gif" />';
#   $c->stash->{template} = 'message.tt';
      
#inbox, etc
sub messages :Global{
   my ( $self, $c ) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   
   my @messages = $c->model('DB::Message')->search(
      {
         heareth => $c->session->{userid},
      },
      {
         join => 'sayeth',
         select => ['me.id','subject','status','sayeth','sayeth.name', 'time'],
         as     => ['id','subject','status','sayeth_id','sayeth_name', 'time'],
      }
   );
   my @messages_info;
   for my $m (@messages){
      push @messages_info, {
         id => $m->id,
         subject => $m->subject || '(no subject)',
         sayeth => $m->get_column('sayeth_name'),
         sayeth_id => $m->get_column('sayeth_id'),
         unseen => $m->status == MESSAGE_NOT_SEEN,
         time => $m->time,
      };
   }
   
   $c->stash->{messages_info} = \@messages_info;
   $c->stash->{template} = 'mailbox.tt';
}

sub mail : Global Args(1){
   my ($self, $c, $id) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   my $msg = $c->model('DB::Message')->find ({id=>$id});
   
   unless ($msg){
      $c->stash->{msg} = "no such message $id";
      $c->detach('messages');
   }
   unless ($msg->get_column('heareth') == $c->session->{userid}){
      $c->stash->{msg} = "not your message $id";
      $c->detach('messages');
   }
   $msg->set_column (status => MESSAGE_SEEN);
   $msg->update;
   
   $c->stash->{mail} = $msg;
}



sub invite : Global Form{
   my ($self, $c) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   my $req = $c->request;
   my $form = $self->form;
   $form->load_config_file('ruleset_proposal.yml');
  # $form->load_config_file('cycle_proposal.yml');
   
   my $ent0 = $form->get_field({name => 'entity0'});
   $ent0->default ($c->session->{name});
   
   $form->process;
   $c->stash->{form} = $form;
   
   if ($form->submitted_and_valid){
     $c->model('DB')->schema->txn_do(  sub{
      my $ruleset = $c->forward ('Game_proposal', 'ruleset_from_form', ['invite']);
      die $c->stash->{err} unless $ruleset;
      
      my $msg = $req->param('message');
      my $ent_order = $req->param('invite_initial');
      # determine whether ents are randomized
      if ($ent_order eq 'specified'){
         $ent_order = INVITE_ORDER_SPECIFIED;
      } else { #random
         $ent_order = INVITE_ORDER_RANDOM;
      }
      my $invite = $c->model('DB::Invite')->create({
         ruleset => $ruleset->id,
         inviter => $c->session->{userid},
         time => time,
         ent_order => $ent_order,
      });
      
      my $max_entity = $c->stash->{invite_max_entity};
      die unless defined $max_entity;
      
      my @players = @{$c->stash->{invite_players}};
      my %already_invited = ($c->session->{userid} => 1); #aka seen
      for (0..$max_entity){
         my $to_inviter = $c->session->{userid} == $players[$_]->id;
         #one invitee for every entity, even if there are 2 of the same player
         #one message sent to each player, minus the proposer
         $invite->create_related ('invitees',{
            player => $players[$_]->id,
            entity => $_,
            status => $to_inviter ? INVITEE_ACCEPTED : INVITEE_OPEN,
         });
         next if $already_invited{$players[$_]->id}++;
         my $msg = $c->model('DB::Message')->create({
            subject => "Game invitation from " . $c->session->{name},
            invite => $invite->id,
            sayeth => $c->session->{userid},
            heareth=> $players[$_]->id,
            time => time,
            message => $msg,
         });
      }
     }); #/txn
     if ($@) { # Transaction failed
         die "Failure: $@";
     }
     else{
         $c->stash->{msg} = 'invite submitted.';
     }
   }
}




sub display_invites : Path('/invites'){
   my ($self, $c) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   
   my $my_invitees = $c->model('DB::Invitee')->search({
      player => $c->session->{userid},
   });
   my $my_invites = $my_invitees->search_related ('invite',{
      'invite.status' => INVITE_OPEN,
   });
   
   #remove dupes
   my %seen_inv;
   my @invites;
   for my $i ($my_invites->all) {
      next if $seen_inv{$i->id};
      $seen_inv{$i->id} = 1;
      push @invites, $i
   }
   $c->stash->{invites} = \@invites;
   $c->stash->{template} = 'list_invites.tt'
}


sub accept_invite :Path('/invite/accept') Args(1){
   my ($self, $c, $inv_id) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   
   my $invite = $c->model('DB::Invite')->find ({id => $inv_id});
   unless ($invite){
      $c->stash->{msg} = "no such invite $inv_id";
      $c->detach ('display_invites')
   }
   unless ($invite->status == INVITE_OPEN){
      $c->stash->{msg} = "invite $inv_id not open.";
      $c->detach ('display_invites')
   }
   
   #find & accept all entities of logged_in player
   my @my_invitees = $invite->search_related ('invitees', {
      player => $c->session->{userid},
   });
   for my $i (@my_invitees){
      $i->set_column (status => INVITEE_ACCEPTED);
      $i->update;
   }
   
   my $open_invitees = $invite->search_related ('invitees', {
      status => INVITEE_OPEN,
   });
   if ($open_invitees->count({})){
      $c->stash->{msg} = "accepted invite $inv_id. invite is still open";
      $c->detach ('display_invites')
   }
   
   #everyone's accepted. start game and close invite.
   my $ruleset = $invite->ruleset;
   my $gid;
   $c->model('DB')->schema->txn_do( sub{
      $invite->set_column (status => INVITE_ACCEPTED);
      $invite->update();
      
      my $game = $c->model('DB::Game')->create({
         ruleset => $ruleset->id,
        # phase => 0, #as default.
      });
      $gid = $game->id;
      
      my @tees = $invite->search_related ('invitees',{},{order_by => 'entity DESC'});
      if ($invite->ent_order == INVITE_ORDER_RANDOM){
         # shuffle invitees if random order
         @tees = shuffle (@tees);
      }
      for (0..$#tees){
         my $tee = $tees[$_];
         $c->model('DB::Player_to_game')->create({
            gid => $gid,
            pid => $tee->player->id,
            entity => $_,
            expiration => 0,
         });
      }
   });
   
   $c->stash->{msg} = "accepted invite $inv_id. <a href='[%url_base%]/game/$gid'>Game $gid</a> created.";
   $c->detach ('display_invites');
}


sub reject_invite :Path('invite/reject') Args(1){
   my ($self, $c, $inv_id) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   
   my $invite = $c->model('DB::Invite')->find ({id => $inv_id});
   unless ($invite){
      $c->stash->{msg} = "no such invite $inv_id";
      $c->detach ('display_invites')
   }
   unless ($invite->status == INVITE_OPEN){
      $c->stash->{msg} = "invite $inv_id not open.";
      $c->detach ('display_invites')
   }
   $invite->set_column (status => INVITE_REJECTED);
   $invite->update;
      $c->stash->{msg} = "invite $inv_id rejected";
      $c->detach ('display_invites')
}



1
