package basilisk::Schema::Game_proposal;

#use basilisk::Util;

#games are created elsewhere, since creation data depends heavily on the ruleset used

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Game_proposal');
__PACKAGE__->add_columns(
    id        => { data_type => 'INTEGER', is_auto_increment => 1 },
    quantity  => { data_type => 'INTEGER', default_value => 1},
    ruleset   => { data_type => 'INTEGER'},
    proposer  => { data_type => 'INTEGER'},
    ent_order     => { data_type => 'INTEGER', default_value => Util::WGAME_ORDER_RANDOM()},
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset');
__PACKAGE__->belongs_to(proposer => 'basilisk::Schema::Player');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_prop => fields => [qw/proposer/]);
}

sub size{
   my $self = shift;
   return $self->ruleset->w . 'x' . $self->ruleset->h
}
sub h{
   my $self = shift;
   return $self->ruleset->h
}
sub w{
   my $self = shift;
   return $self->ruleset->w
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





1;
