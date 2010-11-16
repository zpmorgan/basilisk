package basilisk::Schema::Player_to_game;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Player_to_game');
__PACKAGE__->add_columns(
    'pid'            => { data_type => 'INTEGER'},
    'gid'            => { data_type => 'INTEGER'},
    'entity'         => { data_type => 'INTEGER'}, #typically either 0 or 1
    #time remaining:  store a time of a player's 'expiration', 0=nolimit
    #TODO: implement
);
__PACKAGE__->set_primary_key('gid', 'entity');
__PACKAGE__->belongs_to (player => 'basilisk::Schema::Player', 'pid');
__PACKAGE__->belongs_to (game => 'basilisk::Schema::Game', 'gid');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_p2g_players , fields => [qw/pid/]);
    $table->add_index(name => idx_p2g_games , fields => [qw/gid/]);
}

1;
