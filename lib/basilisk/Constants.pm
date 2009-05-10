package basilisk::Constants;
use strict;
use warnings;
use base 'Exporter';

our @EXPORT_OK = qw (IMG_BASE URL_BASE  
         GAME_RUNNING GAME_FINISHED GAME_PAUSED
         INVITEE_OPEN INVITEE_ACCEPTED INVITEE_REJECTED
         INVITE_OPEN  INVITE_ACCEPTED  INVITE_REJECTED
         INVITE_ORDER_SPECIFIED INVITE_ORDER_RANDOM
         WGAME_ORDER_RANDOM WGAME_ORDER_PROPOSER_FIRST WGAME_ORDER_PROPOSER_LAST
         MESSAGE_NOT_SEEN MESSAGE_SEEN
         FIN_INTENT_OKAY FIN_INTENT_FIN FIN_INTENT_DROP FIN_INTENT_SCORED
      wgame_order_str invite_order_str);

use constant {
   # These are different on the span server:
   IMG_BASE => '/g',
   URL_BASE => '',
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

   INVITEE_OPEN  => 1,
   INVITEE_ACCEPTED => 2,
   INVITEE_REJECTED => 3,
   # not the same as: 
   INVITE_OPEN => 1,
   INVITE_ACCEPTED => 2,
   INVITE_REJECTED => 3,

   INVITE_ORDER_SPECIFIED => 1,
   INVITE_ORDER_RANDOM => 2,

   WGAME_ORDER_RANDOM => 1,
   WGAME_ORDER_PROPOSER_FIRST => 2,
   WGAME_ORDER_PROPOSER_LAST => 3,

   MESSAGE_NOT_SEEN => 1,
   MESSAGE_SEEN => 2,

   #these values are used lot directly. (without being called)
   FIN_INTENT_OKAY => 0,
   FIN_INTENT_FIN => 1, #ready to score
   FIN_INTENT_SCORED => 2,
   FIN_INTENT_DROP => 3,
};


sub wgame_order_str{
   my $order = shift;
   return 'random' if $order == WGAME_ORDER_RANDOM;
   return 'proposer first' if $order == WGAME_ORDER_PROPOSER_FIRST;
   return 'proposer first' if $order == WGAME_ORDER_PROPOSER_LAST;
   die $order;
}

sub invite_order_str{
   my $order = shift;
   return 'random' if $order == INVITE_ORDER_RANDOM;
   return 'specified' if $order == INVITE_ORDER_SPECIFIED;
   die $order;
}
