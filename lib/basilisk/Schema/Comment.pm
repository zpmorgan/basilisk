package basilisk::Schema::Comment;
use base qw/DBIx::Class/;

    
__PACKAGE__->load_components(qw/UTF8Columns Core/);
__PACKAGE__->table('Comment');
__PACKAGE__->add_columns(
    id      => { data_type => 'INTEGER', is_auto_increment => 1},
    gid     => { data_type => 'INTEGER'},
    comment => { data_type => 'TEXT'},
    sayeth  => { data_type => 'INTEGER'},
    time    => { data_type => 'INTEGER'},#epoch
);
__PACKAGE__->utf8_columns(qw/comment/);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to (speaker => 'basilisk::Schema::Player', 'sayeth');
__PACKAGE__->belongs_to (game => 'basilisk::Schema::Game', 'gid');


sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_gmsg => fields => [qw/sayeth gid time/]);
}

1
