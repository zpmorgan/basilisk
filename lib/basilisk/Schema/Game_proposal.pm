package basilisk::Schema::Game_proposal;

#use basilisk::Util;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Game_proposal');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'quantity'      => { data_type => 'INTEGER', default_value => 1},
    'ruleset'      => { data_type => 'INTEGER', is_nullable => 0 },
    'proposer'        => { data_type => 'INTEGER', is_nullable => 0 },
    #'to'        => { data_type => 'INTEGER', is_nullable => 0 }, #to all for now
);

sub size{
   my $self = shift;
   return $self->ruleset->size
}


__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset');
__PACKAGE__->belongs_to(proposer => 'basilisk::Schema::Player');
1;
