package basilisk::Schema::Streetmap;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Streetmap');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'name'          => { data_type => 'TEXT' }, #nearby town..
    'data'          => { data_type => 'TEXT' },
    'original_osm'  => { data_type => 'TEXT' },
    
    'minlat'        => { data_type => 'FLOAT' },
    'maxlat'        => { data_type => 'FLOAT' },
    'minlon'        => { data_type => 'FLOAT' },
    'maxlon'        => { data_type => 'FLOAT' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (rulesets => 'basilisk::Schema::Ruleset', 'streetmap');



1
