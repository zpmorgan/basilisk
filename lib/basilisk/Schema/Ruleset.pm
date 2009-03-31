package basilisk::Schema::Ruleset;
use List::Util;
use base qw/DBIx::Class/;

# Each game could has a 'phase' to determine who's turn it is 
# Each ruleset has a 'phase description' to describe the recurring sequence of turns
#  default description is  '0b 1w'
#  maybe handicap would be '1w 0b'
#  zen's is '0b 1w 2b 0w 1b 2w'
#  rengo is '0b 1w 2b 3w'
#  3-color could be '0b 1w 2r'
# Within a phase description:
#  b and w are the 'sides'
#  0 and 1 are the 'entities', mapped to 'entity' col in p2g table
# Idea: entities could be something other than players, such as 'random' or 'consensus'

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Ruleset');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'h'          => { data_type => 'INTEGER', is_nullable => 0, default_value => '19'},
    'w'          => { data_type => 'INTEGER', is_nullable => 0, default_value => '19'},
    'handicap'       => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'initial_time'   => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'byo'            => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'byo_periods'    => { data_type => 'INTEGER', is_nullable => 0, default_value => '0'},
    'rules_description' => { data_type => 'TEXT' }, #just for humans to read
    #for machines to read & shift phase: #like '0b 1w 2r'
    'phase_description' => { data_type => 'TEXT', is_nullable => 0, default_value => '0b 1w'},
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (positions => 'basilisk::Schema::Position', 'ruleset');
__PACKAGE__->has_many (games => 'basilisk::Schema::Game', 'ruleset');
__PACKAGE__->has_many (proposed_games => 'basilisk::Schema::Game_proposal', 'ruleset');
__PACKAGE__->has_many (extra_rules => 'basilisk::Schema::Extra_rule', 'ruleset');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_size => fields => [qw/h w/]);
    $table->add_index(name => idx_itime => fields => [qw/initial_time/]);
    $table->add_index(name => idx_hcp => fields => [qw/handicap/]);
}

sub num_entities{
   my $self = shift;
   my $pd = $self->phase_description;
   #return max digit in desc
   my @digits = $pd =~ /(\d)/g;
   return max(@digits) + 1
}
sub num_phases{
   my $self = shift;
   my $pd = $self->phase_description;
   #return num of words in description. '0b 1w' -> 2
   my @phases = split ' ', $pd;
   return scalar @phases;
}

sub sides { #returns ('w','r','b'), etc
   my $self = shift;
   my $pd = $self->phase_description;
   my %sides;
   for my $p (split ' ', $pd){
      $p =~ /([bwr])/;
      $sides {$1} = 1;
   }
   return keys %sides;
}

1
