package basilisk::Schema::Player;
use base qw/DBIx::Class/;
use Glicko2;

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
   
   my $relevant_p2g = $self->search_related('player_to_game', 
   {
   },{
      select => ['entity as my_entity'],
      as => ['entity'],
   });
   my $games = $relevant_p2g->search_related ('game', 
   {
      status => GAME_RUNNING,
      phase => 'p2g.entity',
   },
   {
      join => ['ruleset', 'player_to_game'],
      select => ['me.entity as entity', 'phase', 'game.id as gid', 'ruleset.phase_description as pd'],
      as =>     ['entity', 'phase', 'gid', 'pd'],
   });
   my @opponents = $games->search_related('player_to_game',
   {
      'player.name' => {'!=', $name}
   }, {
      join => 'player',
      select => ['player.name as name', 'game.id as gid', 'player.id as pid', 'me.entity'],
   });
   my @games;
   for my $game ($games->all()){
      push @games, {
         $game->id,
      };
   }
   
}

1;
