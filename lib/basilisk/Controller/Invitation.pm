package basilisk::Controller::Invitation;

use parent 'Catalyst::Controller::HTML::FormFu';
use strict;
use warnings;
use basilisk::Util;
use List::Util qw/max shuffle/;
use List::MoreUtils qw/any/;


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
         unseen => $m->status == Util::MESSAGE_NOT_SEEN(),
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
   $msg->set_column (status => Util::MESSAGE_SEEN());
   $msg->update;
   
   $c->stash->{mail} = $msg;
  #$c->stash->{from} = $msg->sayeth;
  # $c->stash->{status_means} = \&tee_status_means;
  # $c->stash->{subject} = $msg->subject;
  # $c->stash->{invite} = $msg->invite;
}


sub invite : Global Form{
   my ($self, $c) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   my $req = $c->request;
   my $form = $self->form;
   $form->load_config_file('ruleset_proposal.yml');
   $form->load_config_file('cycle_proposal.yml');
   
   my $ent0 = $form->get_field({name => 'entity0'});
   $ent0->default ($c->session->{name});
   
   $form->element({ 
      type => 'Submit', 
      name => 'submit',
      value => 'Submit invitation',
   });
   $form->process;
   $c->stash->{form} = $form;
   
   if ($form->submitted_and_valid){
      my $h = $req->param('h');
      my $w = $req->param('w');
      my $topo = $req->param('topology');
      my $pd = $req->param('pd');
      my $heisen = $req->param('heisengo');
      my ($random_phase, $random_place);
      if ($pd eq 'other'){
         $pd = $req->param('other');
      }
      my $msg = $req->param('msg'); #todo: put in form
      
      my $ent_order = $c->req->param('ent_order');
      # determine whether ents are randomized
      if ($ent_order eq 'specified'){
         $ent_order = Util::INVITE_ORDER_SPECIFIED();
      } else { #random
         $ent_order = Util::INVITE_ORDER_RANDOM();
      }
      
      my @digits = $pd =~ /(\d)/g;
      my $max_entity =  max(@digits);
      
      #seemingly valid pd
      for my $i (0..$max_entity){
         unless (any {$i == $_} @digits){
            $c->stash->{msg} = "you must represent all entities: $i @digits";
            $c->detach();
         }
      }
      
      my $desc = $w .'x'. $h; # description of interesting rules
      $desc .= ", $topo" unless $topo eq 'plane';  #planes are not interesting
      
      unless ($pd eq '0b 1w'){ #irregular
         if ($pd eq '0b 1w 2r'){
            $desc .= ', 3-FFA';
         } elsif ($pd eq '0b 1w 2b 3w'){
            $desc .= ', rengo';
         } elsif ($pd eq '0b 1w 2b 0w 1b 2w'){
            $desc .= ', zen';
         } else{
            $desc .= ", cycle[$pd]";
         }
      }
      
      #this is pretty much duplicated in Waiting_room.pm...
      if ($heisen){
         $random_phase = $c->req->param('chance_rand_phase') || 0;
         $random_place = $c->req->param('chance_rand_placement') || 0;
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
      
      my @players; #with dupes
      for my $entnum (0..$max_entity){
         my $pname = $req->param("entity".$entnum);
         die "entity".$entnum." required" unless $pname;
         my $player = $c->model('DB::Player')->find ({name=>$pname});
         die "no such player $pname" unless $player;
         push @players, $player;
      }
      die "You should include yourself."
         unless any {$_->id == $c->session->{userid}} @players;
      
      $c->model('DB')->schema->txn_do(  sub{
         my $new_ruleset = $c->model('DB::Ruleset')->create ({ 
            h => $c->req->param('h'),
            w => $c->req->param('w'),
            rules_description => $desc,
            phase_description => $pd,
         });
         unless ($topo eq 'plane'){
            $new_ruleset->create_related ('extra_rules', {
               rule => $topo,
               priority => 1, #this should go
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
         my $invite = $c->model('DB::Invite')->create({
            ruleset => $new_ruleset->id,
            inviter => $c->session->{userid},
            time => time,
            ent_order => $ent_order,
         });
         
         my %already_invited = ($c->session->{userid} => 1);
         for (0..$max_entity){ 
            my $to_inviter = $c->session->{userid} == $players[$_]->id;
            #one invitee for every entity, even if there are 2 of the same player
            #one message sent to each player, minus the proposer
            my $invitee = $c->model('DB::Invitee')->create({
               invite => $invite->id,
               player => $players[$_]->id,
               entity => $_,
               status => $to_inviter ? Util::INVITEE_ACCEPTED() : Util::INVITEE_OPEN(),
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
      });
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
      'invite.status' => Util::INVITE_OPEN(),
   });
   
   my @invites_info;
   for my $i ($my_invites->all) {
      push @invites_info, {
         row => $i,
         rules => $i->ruleset->rules_description,
      };
   }
  # $c->stash->{invites_info} = \@invites_info;
   $c->stash->{invites} = [$my_invites->all];
  # $c->stash->{status_means} = \&tee_status_means; #translate status codes
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
   unless ($invite->status == Util::INVITE_OPEN()){
      $c->stash->{msg} = "invite $inv_id not open.";
      $c->detach ('display_invites')
   }
   
   #find & accept all entities of logged_in player
   my @my_invitees = $invite->search_related ('invitees', {
      player => $c->session->{userid},
   });
   for my $i (@my_invitees){
      $i->set_column (status => Util::INVITEE_ACCEPTED());
      $i->update;
   }
   
   my $open_invitees = $invite->search_related ('invitees', {
      status => Util::INVITEE_OPEN(),
   });
   if ($open_invitees->count({})){
      $c->stash->{msg} = "accepted invite $inv_id. invite is still open";
      $c->detach ('display_invites')
   }
   
   #everyone's accepted. start game and close invite.
   my $ruleset = $invite->ruleset;
   my $gid;
   $c->model('DB')->schema->txn_do( sub{
      $invite->set_column (status => Util::INVITE_ACCEPTED());
      $invite->update();
      
      my $game = $c->model('DB::Game')->create({
         ruleset => $ruleset->id,
        # phase => 0, #as default.
      });
      $gid = $game->id;
      
      # shuffle invitees if random order
      my @tees = $invite->search_related ('invitees',{},{order_by => 'entity DESC'});
      if ($invite->ent_order == Util::INVITE_ORDER_RANDOM()){
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
   unless ($invite->status == Util::INVITE_OPEN()){
      $c->stash->{msg} = "invite $inv_id not open.";
      $c->detach ('display_invites')
   }
   $invite->set_column (status => Util::INVITE_REJECTED());
   $invite->update;
      $c->stash->{msg} = "invite $inv_id rejected";
      $c->detach ('display_invites')
}



1
