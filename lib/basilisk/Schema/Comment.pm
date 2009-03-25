package basilisk::Schema::Comment;
use base qw/DBIx::Class/;

    
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Comment');
__PACKAGE__->add_columns(
    'id'      => { data_type => 'INTEGER', is_auto_increment => 1},
    'gid'     => { data_type => 'INTEGER', is_nullable => 0},
    'comment' => { data_type => 'TEXT', is_nullable => 0},
    'sayeth'  => { data_type => 'INTEGER', is_nullable => 0},
    'time'    => { data_type => 'INTEGER', is_nullable => 0},#epoch
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to (speaker => 'basilisk::Schema::Player', 'sayeth');
__PACKAGE__->belongs_to (game => 'basilisk::Schema::Game', 'gid');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_gmsg => fields => [qw/sayeth gid time/]);
}

1