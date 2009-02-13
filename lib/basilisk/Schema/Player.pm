package basilisk::Schema::Player;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Player');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'name'      => { data_type => 'TEXT', is_nullable => 0 },
    'pass'      => { data_type => 'TEXT', is_nullable => 1 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'pid');
__PACKAGE__->many_to_many( games => 'player_to_game', 'game');

#sub games{
#   
#}

1;
