package basilisk::Schema::Player;
use warnings;
use strict;
use basilisk::Constants qw/GAME_RUNNING/;
use List::MoreUtils qw(uniq);

use base qw/DBIx::Class/;
#use Glicko2;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Player');
__PACKAGE__->add_columns(
    'id'        => { data_type => 'INTEGER', is_auto_increment => 1 },
    'name'      => { data_type => 'TEXT'},
    'pass'      => { data_type => 'BLOB' }, #hashed
    'current_rating' => { data_type => 'INTEGER', is_nullable => 1 },
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
sub games_to_move {
   my $self = shift;
   my $name = $self->name;
   
   my $omniquery = $self->search_related ('player_to_game', 
   {
      status => GAME_RUNNING,
      #'game.phase' => {'==' => 'player_to_game.entity'}, #wrong
   },
   {
      join => ['player', {'game' => 'ruleset'} ],
      select => ['player.name', 
            'me.entity', 'me.gid', 'me.pid',
            'game.phase as phase', 
            'ruleset.phase_description as pd'
            ],
   });
   
   #die $self->player_to_game->next->game->ruleset;
   
   my %games;
   #die ${$omniquery->as_query};
   for my $game ($omniquery->all()){
      my $gid = $game->gid;
      next if $games{$gid}++;
      #die $game->get_columns;
      $games{$gid} = {
         #row => $game,
         id => $gid,
         pd => $game->get_column('pd'),
         phase => $game->get_column('phase'),
      };
   }
   for my $p2g ($omniquery->all()){
      my $gid = $p2g->get_column('gid');
      my $pid = $p2g->get_column('pid');
      my $pname = $p2g->get_column('name');
  #    my $pd = $p2g->get_column('pd');
      my $entity = $p2g->get_column('entity');
      $games{$pid}->{opponents}->{pid} = {
         id => $pid,
         name => $pname,
         entity => $p2g->entity,
    #     sides => sides_of_entity ($pd, $entity),
      };
   }
   #die join ',',map {$_->{id}} @games;
   return values %games;
}

sub sides_of_entity{ 
   my ($pd, $ent) = @_;
   #my $pd = $self->phase_description;
   my @sides =  $pd =~ /$ent([bwr])/g; 
   return [uniq @sides];
}

1;
