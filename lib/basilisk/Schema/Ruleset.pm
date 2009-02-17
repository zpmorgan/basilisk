package basilisk::Schema::Ruleset;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Ruleset');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 0 },
    'size'          => { data_type => 'INTEGER', is_nullable => 0, default_value => '19'},
    'handicap'       => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'initial_time'   => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'byo'            => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'byo_periods'    => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    #variant rules:
    #'turn_mode'       => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'}, for rengo, zen, normal, etc
    'num_players'    => { data_type => 'INTEGER', is_nullable => 0, default_value => '2'},
    'initial_pos'    => { data_type => 'INTEGER', is_nullable => 1 },
    #boolean settings:
    'wrap_ns'           => { data_type => 'INTEGER', is_nullable => 0, default_value => '0' },
    'wrap_ew'           => { data_type => 'INTEGER', is_nullable => 0, default_value => '0' },
    'dark'           => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (games => 'basilisk::Schema::Game', 'ruleset');
__PACKAGE__->has_many (proposed_games => 'basilisk::Schema::Game_proposal', 'ruleset');
__PACKAGE__->might_have(initial_pos => 'basilisk::Schema::Position', 'id');

1
