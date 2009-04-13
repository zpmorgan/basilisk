package basilisk::Schema::Invite;
use basilisk::Util;
use base qw/DBIx::Class/;

    
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Invite');
__PACKAGE__->add_columns(
   id      => { data_type => 'INTEGER', is_auto_increment => 1},
   ruleset => { data_type => 'INTEGER'},
   
   #msg     => { data_type => 'TEXT', is_nullable => 1},
   inviter => { data_type => 'INTEGER'},
   time    => { data_type => 'INTEGER'},
   
    #open, accepted, rejected ?,expired?
   status  => { data_type => 'INTEGER', default_value => Util::INVITEE_OPEN() },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (invitees => 'basilisk::Schema::Invitee', 'invite');
__PACKAGE__->belongs_to (inviter => 'basilisk::Schema::Player');
__PACKAGE__->has_one  (ruleset => 'basilisk::Schema::Ruleset');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_invt => fields => [qw/inviter time/]);
}

#used by a template
sub is_open{
   my $self = shift;
   $self->status == Util::INVITEE_OPEN();
}

sub status_string{
   my $self = shift;
   my $s = $self->status;
   return 'open' if $s == Util::INVITE_OPEN();
   return 'accepted' if $s == Util::INVITE_ACCEPTED();
   return 'rejected';
};

1
