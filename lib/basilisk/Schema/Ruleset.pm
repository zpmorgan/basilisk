package basilisk::Schema::Ruleset;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Ruleset');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'size'          => { data_type => 'INTEGER', is_nullable => 0, default_value => '19'},
    'handicap'       => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'initial_time'   => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'byo'            => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'byo_periods'    => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    #variant rules:
    'num_players'    => { data_type => 'INTEGER', is_nullable => 0, default_value => '2'},
    
    'rules_description' => { data_type => 'TEXT', is_nullable => 1},
    #'turn_mode'       => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'}, for rengo, zen, normal, etc
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (positions => 'basilisk::Schema::Position', 'ruleset');
__PACKAGE__->has_many (games => 'basilisk::Schema::Game', 'ruleset');
__PACKAGE__->has_many (proposed_games => 'basilisk::Schema::Game_proposal', 'ruleset');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_size => fields => [qw/size/]);
    $table->add_index(name => idx_itime => fields => [qw/initial_time/]);
    $table->add_index(name => idx_hcp => fields => [qw/handicap/]);
}
1
