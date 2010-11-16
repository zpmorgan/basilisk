package basilisk::Constants;
use strict;
use warnings;
use base 'Exporter';

our @EXPORT_OK = qw (IMG_BASE URL_BASE STATIC_BASE 
         GAME_RUNNING GAME_FINISHED GAME_PAUSED
         MESSAGE_NOT_SEEN MESSAGE_SEEN
         FIN_INTENT_OKAY FIN_INTENT_FIN FIN_INTENT_DROP FIN_INTENT_SCORED
      wgame_order_str invite_order_str);

use constant {
   # These are different on the span server:
   IMG_BASE => '/g',
   URL_BASE => '',
   STATIC_BASE => '/static',
   # IMG_BASE => '/basilisk/g,
   # URL_BASE => '/basilisk/go,

   # using 1 byte per intersection in storage, hopefully in the most natural order
   EMPTY => 0,
   BLACK => 'b',
   WHITE => 'w',
   RED => 'r',
   
   #values for game's status column
   GAME_RUNNING => 1,
   GAME_FINISHED => 2,
   GAME_PAUSED => 3, #unused..

   MESSAGE_NOT_SEEN => 1,
   MESSAGE_SEEN => 2,

   #these values are used lot directly. (without being called)
   FIN_INTENT_OKAY => 0,
   FIN_INTENT_FIN => 1, #ready to score
   FIN_INTENT_SCORED => 2,
   FIN_INTENT_DROP => 3,
};


