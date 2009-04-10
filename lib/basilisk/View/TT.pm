package basilisk::View::TT;

use strict;
use base 'Catalyst::View::TT';
use basilisk;

__PACKAGE__->config({
   TEMPLATE_EXTENSION => '.tt',
   INCLUDE_PATH => [
                basilisk->path_to( 'templates' ),
            ],

});


1;
