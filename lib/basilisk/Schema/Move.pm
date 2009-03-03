package basilisk::Schema::Move;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Move');
__PACKAGE__->add_columns(
    'gid'         => { data_type => 'INTEGER', is_nullable => 0 },
    'movenum'     => { data_type => 'INTEGER', is_nullable => 0 },
    'position_id' => { data_type => 'INTEGER', is_nullable => 0 },
    'movestring'  => { data_type => 'TEXT', is_nullable => 0 }, #'pass' or 'b t4' etc
    'dead_groups' => { data_type => 'TEXT', is_nullable => 1 }, #like '2-3_5-0_5-6'
    'time'        => { data_type => 'INTEGER', is_nullable => 0 },
);
__PACKAGE__->set_primary_key('gid', 'movenum');
__PACKAGE__->belongs_to(game => 'basilisk::Schema::Game', 'gid');
__PACKAGE__->belongs_to(position => 'basilisk::Schema::Position', 'position_id');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    #$table->add_index(name => idx_mv => fields => [qw/gid movenum/]);
}

1
