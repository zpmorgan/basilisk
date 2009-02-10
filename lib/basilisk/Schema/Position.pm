package basilisk::Schema::Position;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Position');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_nullable => 0},
    'size'          => { data_type => 'INTEGER', is_nullable => 0, default_value => '19'},
    'position'            => { data_type => 'TEXT', is_nullable => 0},
    #'ruleset' or size?            => { data_type => 'INTEGER', is_nullable => 0 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (moves => 'basilisk::Schema::Move', 'position_id');


sub empty_pos{
   my $size = shift;
   $size = 19 unless $size;
   my @row = map {' '} (1..$size);
   my @board = map {[@row]} (1..$size);
   return \@board;
}
1
