package basilisk::Controller::Game_proposal;
#This file contains only private parts.

use parent 'Catalyst::Controller';
use strict;
use warnings;
use List::Util qw/max/;
use List::MoreUtils qw/any/;
use JSON;


#this is common to both invites and waiting room
#returns the ruleset row...
#Should always be nested in a db transaction
sub ruleset_from_form: Private{
   my ($self, $c, $type) = @_;
   my $req = $c->request;
   my $h = $req->param('h');
   my $w = $req->param('w');
   my $topo = $req->param('topology');
   my ($heisengo,$planckgo,$schroedingo) = @{$req->parameters}{qw/heisengo planckgo schroedingo/};
   my ($heisenChance, $planckChance) = @{$req->parameters}{qw/hg_chance pg_chance/};
   my $komi = $req->param('komi');
   my $ko_rule = $req->param('ko_rule');
   
   my $msg = $req->param('message'); #'hello have game'
   my $pd = '0b 1w';
   
   #verify phases, entities, etc. (only supplied with invites)
   if ($type eq 'invite'){
      $pd = $req->param('phase_description');
      if ($pd eq 'other'){
         $pd = $req->param('other');
      }
      #verify phases
      my @digits = $pd =~ /(\d)/g;
      my $max_entity =  max(@digits);
      for my $i (0..$max_entity){
         unless (any {$i == $_} @digits){
            $c->stash->{err} = "cycle description must represent all entities: $i @digits";
            return 0;
         }
      }
      $c->stash->{invite_max_entity} = $max_entity;
      if ($max_entity>1 and $komi){
         die "sorry, komi is only applied to 2player games."
      }
      
      #now make sure these players actually exist.
      my @players;
      for my $entnum (0..$max_entity){
         my $pname = $req->param("entity".$entnum);
         die "entity".$entnum." required" unless $pname;
         my $player = $c->model('DB::Player')->find ({name=>$pname});
         die "no such player $pname" unless $player;
         push @players, $player;
      }
      die "You should include yourself."
         unless any {$_->id == $c->session->{userid}} @players;
      $c->stash->{invite_players} = \@players;
   }
   
   my $rules = {
      topo => $topo,
   };
   $rules->{heisengo} = $heisenChance if $heisengo;
   $rules->{planckgo} = $planckChance if $planckgo;
   $rules->{schroedingo} = 1 if $schroedingo;
   $rules->{ko_rule} = $ko_rule if $ko_rule ne 'situational';
   
   my $ruleset;
   $ruleset = $c->model('DB::Ruleset')->create ({ 
      h => $h,
      w => $w,
      rules_description => 'FOOBEANS',
      phase_description => $pd,
      komi => $komi // 0,
      other_rules => to_json($rules),
   });
   
   my $new_desc = $ruleset->generate_rules_description();
   $ruleset->set_column('rules_description', $new_desc);
   $ruleset->update();
   return $ruleset;
}
2
