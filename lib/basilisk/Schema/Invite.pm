package basilisk::Schema::Invite;
use base qw/DBIx::Class/;

    
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Invite');
__PACKAGE__->add_columns(
   id      => { data_type => 'INTEGER', is_auto_increment => 1},
   ruleset => { data_type => 'INTEGER'},
   
   msg     => { data_type => 'TEXT'},
   inviter => { data_type => 'INTEGER'},
   time    => { data_type => 'INTEGER'},
   status  => { data_type => 'INTEGER'}, #open, accepted, rejected ?,expired?
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (invitees => 'basilisk::Schema::Invitee', 'invite');
__PACKAGE__->belongs_to (inviter => 'basilisk::Schema::Player');
__PACKAGE__->has_one  (ruleset => 'basilisk::Schema::Ruleset');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_invt => fields => [qw/inviter time/]);
}

1
