package basilisk::Schema::Position;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Position');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1},
    'ruleset'       => { data_type => 'INTEGER'}, #here to specify size/shape
    'position'      => { data_type => 'TEXT'},
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (start_of_game => 'basilisk::Schema::Game', 'initial_position');
__PACKAGE__->has_many (moves => 'basilisk::Schema::Move', 'position_id');
__PACKAGE__->belongs_to (ruleset => 'basilisk::Schema::Ruleset');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_pos => fields => [qw/position/]);
}

1
