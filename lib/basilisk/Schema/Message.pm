package basilisk::Schema::Message;
use base qw/DBIx::Class/;

use basilisk::Constants qw/MESSAGE_NOT_SEEN/;
    
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Message');
__PACKAGE__->add_columns(
    'id'       => { data_type => 'INTEGER',  is_auto_increment => 1},
    'status'   => { data_type => 'INTEGER', default_value => MESSAGE_NOT_SEEN},
    'subject'  => { data_type => 'TEXT', is_nullable => 1},
    'message'  => { data_type => 'TEXT', is_nullable => 1},
    'sayeth'   => { data_type => 'INTEGER', is_nullable => 0},
    'heareth'  => { data_type => 'INTEGER', is_nullable => 0},
    'time'     => { data_type => 'INTEGER', is_nullable => 0},#epoch
    'invite'   => { data_type => 'TEXT', is_nullable => 1},
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to (sayeth => 'basilisk::Schema::Player', 'sayeth');
__PACKAGE__->belongs_to (heareth => 'basilisk::Schema::Player', 'heareth');
__PACKAGE__->belongs_to (invite => 'basilisk::Schema::Invite'); #sometimes

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_msg => fields => [qw/sayeth heareth time/]);
    $table->add_index(name => idx_invtmsg => fields => [qw/invite/]);
}


1
