package basilisk::Schema::Move;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Move');
__PACKAGE__->add_columns(
    'gid'            => { data_type => 'INTEGER', is_nullable => 0 },
    'position_id'    => { data_type => 'INTEGER', is_nullable => 0 },
    'x'      => { data_type => 'INTEGER', is_nullable => 0 }, #from top left
    'y'      => { data_type => 'INTEGER', is_nullable => 0 }, #from top left
    'movenum'            => { data_type => 'INTEGER', is_nullable => 0 },
    'time'      => { data_type => 'INTEGER', is_nullable => 0 },
);
__PACKAGE__->set_primary_key('gid', 'position_id');
__PACKAGE__->belongs_to(game => 'basilisk::Schema::Game', 'gid');
__PACKAGE__->belongs_to(position => 'basilisk::Schema::Position', 'position_id');



1
