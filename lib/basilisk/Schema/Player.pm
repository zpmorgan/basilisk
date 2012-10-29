package basilisk::Schema::Player;
use warnings;
use strict;
use basilisk::Constants qw/GAME_RUNNING/;
use List::MoreUtils qw(uniq any all indexes);

use base qw/DBIx::Class/;
#use Glicko2;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Player');
__PACKAGE__->add_columns(
    'id'        => { data_type => 'INTEGER', is_auto_increment => 1 },
    'name'      => { data_type => 'TEXT'},
    'pass'      => { data_type => 'BLOB' }, #hashed
    'current_rating' => { data_type => 'INTEGER', default_value => 1 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'pid');
__PACKAGE__->many_to_many( games => 'player_to_game', 'game');
__PACKAGE__->has_many(proposed_games => 'basilisk::Schema::Game_proposal', 'proposer');
__PACKAGE__->might_have (rating => 'basilisk::Schema::Rating', {'foreign.id' => 'self.current_rating'});
__PACKAGE__->has_many(all_ratings => 'basilisk::Schema::Rating', 'pid');
__PACKAGE__->has_many (comments => 'basilisk::Schema::Comment', 'sayeth');
__PACKAGE__->has_many (invites => 'basilisk::Schema::Invite', 'inviter');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_name => fields => [qw/name/]);
}

sub grant_rating{ #initially, before any games, player must have rating
   my ($self, $value) = @_;
   my $rating = $self->rating->resultsource->resultset->create(
      pid => $self->id,
      time => time,
      rating => $value,
      rating_deviation => 1.85,
      rating_volatility => 0.06,
   );
}
sub update_rating{
   my $self = shift;
}

#used for status page, and rss feed.
#return game id, your side...,
#opponents in game, with sides,
#Time of last move is important for both, I think.
sub games_to_move{
   my ($self, $all_turnwise) = shift;
   my $name = $self->name;
   
   my $omniquery = $self->search_related ('player_to_game', 
   {
      status => GAME_RUNNING,
      #ignore if phase != me.entity's phases
   },
   {
      join => {'game' => [{'player_to_game' => 'player'}, 'ruleset']},
      select => [
         'player.name', 'player.id', 'player_to_game.entity',
         'game.id', 'game.phase', #from game
         'phase_description', #from ruleset
         'perturbation', 'number_of_moves', #from game
      ],
      as => [qw/name pid entity   gid phase pd perturbation number_moves/],
   });
   my %games;
   for my $game ($omniquery->all()){
      my $gid = $game->gid;
      next if $games{$gid};
      $games{$gid} = {
         id => $gid,
         pd => $game->get_column('pd'),
         phase => $game->get_column('phase'),
         players => {},
         perturbation => ($game->get_column('perturbation') or $gid),
         number_moves => $game->get_column('number_moves'),
      };
   }
   my %seen_ent; #if user has 2+ entities in the same game, rows for that game are repeated 
   for my $p2g ($omniquery->all()){
      my $gid = $p2g->gid;
      next unless $games{$gid};
      
      my ($pid, $pname, $entity) = @{{$p2g->get_columns}}{qw/pid name entity/};
      my ($phase,$pd) = @{{$p2g->get_columns}}{qw/phase pd/};
      next if $seen_ent{"$gid $entity"}++;
      
      my @sides = sides_of_entity ($pd, $entity);
      my @phases = phases_of_entity ($pd, $entity);
      if ($pid != $self->id){
         next if $all_turnwise;
         if (any {$_ == $phase} @phases){
            delete $games{$gid};
            next;
         }
      }
      
      $games{$gid}->{players}->{$entity} = {
         id => $pid,
         name => $pname,
         entity => $entity,
         sides => \@sides,
      };
   }
   #oldest first? sure.
   my @games = sort {$a->{perturbation} <=> $b->{perturbation}} values %games;
   #see if user == all opponents.
   for my $game(@games){
      if (all {$_->{id} == $self->id} values %{$game->{players}}) {
         $game->{only_self} = 1
      }  
   }
   return @games;
}


sub sides_of_entity{ 
   my ($pd, $ent) = @_;
   my @sides =  $pd =~ /$ent([bwr])/g; 
   return uniq @sides;
}
sub phases_of_entity{ 
   my ($pd, $ent) = @_;
   my @phases = split ' ', $pd;
   return indexes {$_ =~ /$ent/} @phases;
}

1;
