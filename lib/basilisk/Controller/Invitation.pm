package basilisk::Controller::Invitation;

use strict;
use warnings;
use parent 'Catalyst::Controller';
#TODO: use parent 'Catalyst::Controller::HTML::FormFu';


__PACKAGE__->config->{namespace} = '';


#inbox, etc
sub messages :Global{
   my ( $self, $c ) = @_;
   
   $c->stash->{template} = 'mailbox.tt';
   
   $c->stash->{message} = 'Hello. Here\'s some wood:<br>' . 
      '<img src="[% img_base %]/wood.gif" />';
   $c->stash->{template} = 'message.tt';
}


sub invite : Global {
   my ($self, $c) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   
   my $req = $c->request;
   my $form=$c->stash->{form};
   if ($req->param('invitate')){
      #TODO: something more elegant for form validation!
      my $topo = $c->req->param('topology');
      return "$topo topology is unsupported" 
         unless grep{$_ eq $topo} @Util::acceptable_topo;
      my $h = $c->req->param('h');
      my $w = $c->req->param('w');
      die 'I will not allow boards of that size!' if $w>25 or $h>25;
      die 'no sire' unless $h and $w;
      my $desc = $w .'x'. $h; # description of interesting rules
      $desc .= ", $topo" unless $topo eq 'plane';  #planes are not interesting
      
      my $pd = $req->param('cycle_type');
      die unless $pd;
      my %ok_pd = (
         '0b 1w' => 2,
         '0b 1w 2r' => 3,
         '0b 1w 2b 3w' => 4, #rengo
         '0b 1w 2b 0w 1b 0w' => 2, #zen
      );
      die 'sorry' unless $ok_pd{$pd}; #todo custom
      my $num_entities = $ok_pd{$pd};
      
      unless ($pd eq '0b 1w'){ #irregular
         if ($pd eq '0b 1w 2r'){
            $desc .= ', 3-FFA';
         } elsif ($pd eq '0b 1w 2b 3w'){
            $desc .= ', rengo';
         } elsif ($pd eq '0b 1w 2b 0w 1b 0w'){
            $desc .= ', zen';
         } else{
            $desc .= ", cycle[$pd]";
         }
      }
      
      my @players;
      for my $entnum (0..$num_entities-1){
         my $pname = $req->param("entity".$entnum);
         die "entity".$entnum."required" unless $pname;
         my $player = $c->model('DB::Player')->find ({name=>$pname});
         die "no such player $pname" unless $player;
         push @players, $player;
      }
      for (@players){
         
      }
      die "You should include yourself." 
         unless grep {$_->id == $c->session->{userid}} @players;
      
      $c->model('DB')->schema->txn_do(  sub{
         my $new_ruleset = $c->model('DB::Ruleset')->create ({ 
            h => $c->req->param('h'),
            w => $c->req->param('w'),
            rules_description => $desc,
         });
         unless ($topo eq 'plane'){
            $c->model('DB::Extra_rule')->create({
               rule => $topo,
               priority => 2, #this should go
               ruleset  => $new_ruleset->id,
            });
         }
         my $invite = $c->model('DB::Invite')->create({
            ruleset => $new_ruleset->id,
            inviter => $c->session->{userid},
            time => time,
            
         });
      });
      if ($@) {                                  # Transaction failed
         die "Failure: $@";
      }
      else{
         $c->stash->{msg} = 'invite submitted.';
      }
   }
   
   
   $c->stash->{template} = 'invite.tt';
}





1
