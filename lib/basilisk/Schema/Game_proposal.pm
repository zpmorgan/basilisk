package basilisk::Schema::Game_proposal;

#use basilisk::Util;

#games are created elsewhere, since creation data depends heavily on the ruleset used

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Game_proposal');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'quantity'      => { data_type => 'INTEGER', default_value => 1},
    'ruleset'      => { data_type => 'INTEGER', is_nullable => 0 },
    'proposer'        => { data_type => 'INTEGER', is_nullable => 0 },
    #'to'        => { data_type => 'INTEGER', default => 0 }, #to all for now
);

sub size{
   my $self = shift;
   return $self->ruleset->size
}
sub decrease_quantity{ #by just one
   my $self = shift;
   my $q = $self->quantity;
   if ($q==1){ #remove.
      $self->delete;
      return;
   }
   $self->set_column('quantity', $q-1);
   $self->update;
   #$self->delete if $self->quantity < 1
}


__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset');
__PACKAGE__->belongs_to(proposer => 'basilisk::Schema::Player');
1;
