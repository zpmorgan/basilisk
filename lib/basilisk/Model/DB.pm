package basilisk::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'basilisk::Schema',
    connect_info => [
        'dbi:SQLite:basilisk.db', 
        #'dbi:mysql:basilisk',
        #'user', 'password',
    ],
);

1;
