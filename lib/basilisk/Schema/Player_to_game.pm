package basilisk::Schema::Player_to_game;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Player_to_game');
__PACKAGE__->add_columns(
    'pid'            => { data_type => 'INTEGER', is_nullable => 0 },
    'gid'            => { data_type => 'INTEGER', is_nullable => 0 },
    'side'            => { data_type => 'INTEGER', is_nullable => 0 }, #typically either 0(b) or 1(w)
    'time_remaining'      => { data_type => 'INTEGER', is_nullable => 0 },#after most recent move?
    #or, could store time of a player's 'expiration'
    'captures'      => { data_type => 'INTEGER', is_nullable => 0 , default_value => 0},
);
__PACKAGE__->set_primary_key('pid', 'gid', 'side');
__PACKAGE__->belongs_to (player => 'basilisk::Schema::Player', 'pid');
__PACKAGE__->belongs_to (game => 'basilisk::Schema::Game', 'gid');

1;
