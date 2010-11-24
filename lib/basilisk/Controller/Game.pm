package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use JSON;

#use basilisk::Rulemap;

__PACKAGE__->config->{namespace} = 'game';

sub selfgame : Global{
   my ( $self, $c ) = @_;
   $c->detach('game',[1]);
   $c->stash->{gameid} = 1;
   $c->stash->{template} = 'game.tt';
}
sub game : Global{
   my ( $self, $c, $gameid ) = @_;
   $c->stash->{gameid} = $gameid;
   my $game = $c->model('DB::Game')->find($gameid);
   $c->stash->{game} = $game;
   $c->forward('build_rulemap', [$game]);
   
   $c->stash->{template} = 'game.tt';
}



sub build_rulemap : Private{
   my ($self, $c, $game) = @_;
   $game //= $c->stash->{game};
   my $pd = $game->phase_description;
   
   my $rules = from_json ($game->rules // '{}');
   my $topo = $rules->{topo} // 'plane';
   
   my $ko_rule = $rules->{ko_rule} // 'situational';
   
   my $rulemap = new basilisk::Rulemap::Rect(
      h => $rules->{h},
      w => $rules->{w},
      wrap_ew => ($topo eq 'torus' or $topo eq 'cylinder' or $topo eq 'klein') ?1:0,
      wrap_ns => ($topo eq 'torus') ?1:0,
      twist_ew => 0,
      twist_ns => ($topo eq 'klein' or $topo eq 'mobius') ?1:0,
      topology => $topo,
      phase_description => $pd,
      komi => $rules->{komi} // 0,
      ko_rule => $ko_rule,
   );
   if ($rules->{heisengo}){
      $rulemap->apply_rule_role ('heisengo', $rules->{heisengo});
   }
   if ($rules->{planckgo}){
      $rulemap->apply_rule_role ('planckgo', $rules->{planckgo});
   }
   if ($rules->{schroedingo}){ #hehe
      $rulemap->apply_rule_role ('schroedingo');
   }
   $c->stash->{rulemap} = $rulemap;
}
