package basilisk::Schema::Player;
use warnings;
use strict;
use basilisk::Constants qw/GAME_RUNNING/;
use List::MoreUtils qw(uniq any indexes);

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
         'player.name', 'player.id', 
         'me.entity', 'me.gid',
         'phase', #from game
         'phase_description', #from ruleset
         #'player_2.id AS p2id','player_2.name AS p2name',
      ],
      as => [qw/name pid entity   gid phase pd/],
   });
   #die ${$omniquery->as_query};
   #die $omniquery->next->get_columns;
   my %games;
   for my $game ($omniquery->all()){
      my $gid = $game->gid;
      next if $games{$gid};
      #die $game->get_columns;
      $games{$gid} = {
         #row => $game,
         id => $gid,
         pd => $game->get_column('pd'),
         phase => $game->get_column('phase'),
         players => {},
      };
   }
   for my $p2g ($omniquery->all()){
      my $gid = $p2g->gid;
      next unless $games{$gid};
      
      my $pid = $p2g->get_column('pid');
      my $pname = $p2g->get_column('name');
      my $entity = $p2g->get_column('entity');
      my ($phase,$pd) = @{{$p2g->get_columns}}{qw/phase pd/};
      die ($phase,$pd);
      my @sides = sides_of_entity ($pd, $entity);
      my @phases = phases_of_entity ($pd, $entity);
      
      unless ($pid == $self->id or $all_turnwise){
         #delete game info from %games, if it's someone else's turn
         if (any {$_ == $phase} @phases){
            delete $games{$gid};
            next;
         }
      }
      
      $games{$gid}->{players}->{$pid} = {
         id => $pid,
         name => $pname,
         entity => $entity,
         sides => \@sides,
      };
   }
   #die join ',',map {$_->{id}} @games;
   return values %games;
}


sub sides_of_entity{ 
   my ($pd, $ent) = @_;
   #my $pd = $self->phase_description;
   my @sides =  $pd =~ /$ent([bwr])/g; 
   return uniq @sides;
}
sub phases_of_entity{ 
   my ($pd, $ent) = @_;
   #my $pd = $self->phase_description;
   my @phases = split ' ', $pd;
   return indexes {$_ =~ /$ent/} @phases;
}

1;
