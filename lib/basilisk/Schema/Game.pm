package basilisk::Schema::Game;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Game');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
#    'white'      => { data_type => 'INTEGER', is_nullable => 1 },
#    'black'      => { data_type => 'INTEGER', is_nullable => 1 },
#    'size'          => { data_type => 'INTEGER', is_nullable => 0 },
    'ruleset'      => { data_type => 'INTEGER', is_nullable => 0 },
    'turn'      => { data_type => 'INTEGER', is_nullable => 0, default_value => 0 },

);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset', 'ruleset');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'gid');
__PACKAGE__->many_to_many( players => 'basilisk::Schema::Player_to_game', 'pid');
1;
