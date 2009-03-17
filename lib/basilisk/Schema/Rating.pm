package basilisk::Schema::Rating;
use base qw/DBIx::Class/;

# This stores glicko2 data
# Each row represents a rating change, after each game, or at initial assignment

#Ratings are on the glicko2 spectrum.
#about 1500 from chess becomes 0 in glicko2, 1700 =>1.1513
#maybe players with established ratings could serve as anchors to the bgs go ratings

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Rating');
__PACKAGE__->add_columns(
    id     => { data_type => 'INTEGER', is_auto_increment => 1 },
    pid    => { data_type => 'INTEGER', is_auto_increment => 0},
    game   => { data_type => 'INTEGER', is_nullable => 1},
    time   => { data_type => 'INTEGER', is_nullable => 0},
    rating           => { data_type => 'INTEGER', is_nullable => 0}, #Glicko-2
    rating_deviation => { data_type => 'INTEGER', is_nullable => 0},
    rating_volatility=> { data_type => 'INTEGER', is_nullable => 0},
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to (player => 'basilisk::Schema::Player', 'pid');
__PACKAGE__->belongs_to (game => 'basilisk::Schema::Game', 'game');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_pidtime => fields => [qw/pid time/]);
}

#convert from something like \d(\.\d+)? to something like '\d\d? (kyu|dan)'
#require database for this, as it anchors go ratings to glicko2 ratings
#loss of precision doing this
sub glicko2_to_go{
   my ($self, $g_r) = @_;
   
}

1;
