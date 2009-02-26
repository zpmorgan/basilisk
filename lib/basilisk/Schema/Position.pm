package basilisk::Schema::Position;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Position');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_nullable => 0},
    'size'          => { data_type => 'INTEGER', is_nullable => 0, default_value => '19'},
    'position'            => { data_type => 'BLOB', is_nullable => 0},
    #'ruleset' or size?            => { data_type => 'INTEGER', is_nullable => 0 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (moves => 'basilisk::Schema::Move', 'position_id');
__PACKAGE__->has_many (games_initially => 'basilisk::Schema::Game', 
      { 'foreign.initial_position' => 'self.id' });
sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_pos => fields => [qw/position/]);
    $table->add_index(name => idx_possize => fields => [qw/size/]);
}

sub empty_pos{
   my $size = shift;
   $size = 19 unless $size;
   my @row = map {' '} (1..$size);
   my @board = map {[@row]} (1..$size);
   return \@board;
}
1
