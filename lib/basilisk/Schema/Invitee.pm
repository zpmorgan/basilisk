package basilisk::Schema::Invitee;
use base qw/DBIx::Class/;

    
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Invitee');
__PACKAGE__->add_columns(
   invite => { data_type => 'INTEGER'},
   entity => { data_type => 'INTEGER'},
   status => { data_type => 'INTEGER'}, #open, accepted, rejected
);

__PACKAGE__->set_primary_key ('invite', 'entity');
__PACKAGE__->belongs_to  (invite => 'basilisk::Schema::Invite');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => 'idx_invitee' , fields => [qw/invite entity status/]);
}

1
