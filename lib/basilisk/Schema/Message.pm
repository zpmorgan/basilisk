package basilisk::Schema::Message;
use base qw/DBIx::Class/;

    
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Message');
__PACKAGE__->add_columns(
    'id'       => { data_type => 'INTEGER',  is_auto_increment => 1},
    'subject'  => { data_type => 'TEXT', is_nullable => 1},
    'message'  => { data_type => 'TEXT', is_nullable => 0},
    'sayeth'   => { data_type => 'INTEGER', is_nullable => 0},
    'heareth'  => { data_type => 'INTEGER', is_nullable => 0},
    'time'     => { data_type => 'INTEGER', is_nullable => 0},#epoch
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to (from => 'basilisk::Schema::Player', 'sayeth');
__PACKAGE__->belongs_to (to => 'basilisk::Schema::Player', 'heareth');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_msg => fields => [qw/sayeth heareth time/]);
}


1
