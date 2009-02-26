package basilisk::Rulemap;
use basilisk::Util;
#use Moose; # automatically turns on strict and warnings
use strict;
use warnings;


# This class evaluates moves and determines new board positions.
# Also, it must be used to determine visible portions of the board if there's fog of war.
# So you actually MIGHT need one of these to view any game at all.

# Rulemaps are not stored in the database. However they are derived from
#   entries in the Ruleset and Extra_rule tables.

# This class is basically here to define default behavior and
#   to provide a mechanism to override it. 
# However this class will not handle rendering.

# Also: This does not involve the ko rule. That requires a database search 
#   for a duplicate position.

my %defaults = (
   size => 19,
   topology => 'grid',
   eval_move_func => sub{'plutocrat'},
   #move_is_legal_func => sub{'jazzersize'},
);


sub new{
   my $class = shift;
   my %params = @_;
   #copy & modify defaults:
   my $self = { %defaults }; 
   if ($params{size}){
      $self->{size} = $params{size};
   }
   if ($params{topology}){
      $self->{topology} = $params{topology};
   }
   bless $self, $class;
   return $self;
}

#These will be the accessible for any game.
sub move_is_valid{ #returns (true, '') or (false, err)
   my $self = shift;
   return 1 if $self->{eval_move_func}->($self, @_);
}
sub next_board_position{ #returns board or undef
   
}

sub default_evaluate_move{
   
}

1;
