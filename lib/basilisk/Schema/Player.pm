package basilisk::Schema::Player;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Player');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'name'      => { data_type => 'TEXT', is_nullable => 0 },
    'pass'      => { data_type => 'TEXT', is_nullable => 1 },
  #  'glicko2_rating' => { data_type => 'INTEGER', is_nullable => 1 },
  #TODO: make new table with these
#    'rating'    => { data_type => 'INTEGER', is_nullable => 1 }, #Glicko-2
#    'rating_deviation'=> { data_type => 'INTEGER', is_nullable => 1 },
#    'rating_volatility'=> { data_type => 'INTEGER', is_nullable => 1 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'pid');
__PACKAGE__->many_to_many( games => 'player_to_game', 'game');
__PACKAGE__->has_many(proposed_games => 'basilisk::Schema::Game_proposal', 'proposer');
#__PACKAGE__->might_have(current_rating => 'basilisk::Schema::Rating', 'glicko2_rating');
#__PACKAGE__->belongs_to(all_ratings => 'basilisk::Schema::Rating', 'player');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_name => fields => [qw/name/]);
}

1;
