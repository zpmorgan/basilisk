package basilisk::Schema::Extra_rule;
use base qw/DBIx::Class/;

#TODO: delete this file & table

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Extra_rule');
__PACKAGE__->add_columns(
    'ruleset'    => { data_type => 'INTEGER'},
    'rule'       => { data_type => 'TEXT'},
    'priority'   => { data_type => 'INTEGER', is_nullable => 1}, #unused! (?)
);
    #boolean rules: 
    #'wrap_ns' OR 'twist_ns'
    #'wrap_ew' OR 'twist_ew'
    #'dark'
    #  -- visibility & collisions are related parameters

__PACKAGE__->set_primary_key('ruleset', 'priority');
__PACKAGE__->belongs_to (ruleset => 'basilisk::Schema::Ruleset');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_rule => fields => [qw/rule/]);
}
1
