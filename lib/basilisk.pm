package basilisk;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use parent qw/Catalyst/;
use Catalyst qw/-Debug
                ConfigLoader
                Static::Simple
                Session
                  Session::Store::FastMmap
                  Session::State::Cookie
/;
 #               Authentication
 #               Authorization::Roles
#our $VERSION = '0.04';

basilisk->config(
   static => {
      include_path => [
         '/root/static',
         'root',
      ],
   },
);


# Start the application
__PACKAGE__->setup();



1;
