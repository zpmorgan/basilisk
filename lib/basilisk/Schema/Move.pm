package basilisk::Schema::Move;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Move');
__PACKAGE__->add_columns(
    gid         => { data_type => 'INTEGER', is_nullable => 0 },
    movenum     => { data_type => 'INTEGER', is_nullable => 0 },
    position_id => { data_type => 'INTEGER', is_nullable => 0 },
    dead_groups => { data_type => 'TEXT' }, #like '2-3_5-0_5-6'
    time        => { data_type => 'INTEGER', is_nullable => 0 },
      #2+ ways to count captures--space-separated values, 
      #Let rulemap take care of it. Both could be done in a game.
      #1. (Positive, as in FFA): has sum of all captures per phase 
      #2. (Negative)Keep track of each side's own lost stones.
      # (atm, it only does 1.)
    captures => { data_type => 'TEXT', is_nullable => 0}, #'0 0'
    
  #  movestring  => { data_type => 'TEXT', default_value => 'blah'}, #replacing with both 'phase' and 'move'
    phase  => { data_type => 'INTEGER', is_nullable => 0}, #0, 1, etc
    move   => { data_type => 'TEXT', is_nullable => 0}, #pass, submit(?), {node}, etc
);
__PACKAGE__->set_primary_key('gid', 'movenum');
__PACKAGE__->belongs_to(game => 'basilisk::Schema::Game', 'gid');
__PACKAGE__->belongs_to(position => 'basilisk::Schema::Position', 'position_id');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    #$table->add_index(name => idx_mv => fields => [qw/gid movenum/]);
}

1
