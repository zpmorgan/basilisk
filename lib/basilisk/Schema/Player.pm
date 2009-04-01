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

1;
