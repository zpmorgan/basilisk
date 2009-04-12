package basilisk::Schema::Invitee;
use basilisk::Util;
use base qw/DBIx::Class/;

    
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Invitee');
__PACKAGE__->add_columns(
   invite => { data_type => 'INTEGER'},
   entity => { data_type => 'INTEGER'},
   player => { data_type => 'INTEGER'},
   
    #open, accepted, rejected ?,expired?
   status => { data_type => 'INTEGER', default_value => Util::INVITEE_OPEN() },
);

__PACKAGE__->set_primary_key ('invite', 'entity', 'player');
__PACKAGE__->belongs_to  (invite => 'basilisk::Schema::Invite');
__PACKAGE__->belongs_to  (player => 'basilisk::Schema::Player');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => 'idx_invitee' , fields => [qw/player invite entity status/]);
}

1
