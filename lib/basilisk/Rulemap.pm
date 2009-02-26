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
# This is also where parameters relevant to specific rulesets are stored.
#   Example: 'size' might be meaningless for some boards.
#   Example: 'visibility' with fog of war.
#   Example: 'collisions' with fog of war.

# This class is basically here to define default behavior and
#   to provide a mechanism to override it.
# However this class will not handle rendering.

# Also: This does not involve the ko rule. That requires a database search 
#   for a duplicate position.

#TODO: absorb get_string,etc
#TODO: shifting turns&teams&colors in new ways (rengo,zen,consensus?)

my %defaults = (
   size => 19,
   topology => 'plane',
   eval_move_func => \&default_evaluate_move,
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
sub evaluate_move{ #returns (board,'',caps) or (undef, err)
   my $self = shift;
   return  $self->{eval_move_func}->($self, @_);
}

#This is the default. Used for normal games on rect grid
sub default_evaluate_move{
   my ($self, $board, $row, $col, $color) = @_;
   die "badcolor $color" unless $color =~ /^[12]$/;
   die "blah" unless $row and $col;
   die 'badboard' unless ref $board eq 'ARRAY';
   
   if ($board->[$row][$col]){
      return (undef,"stone exists at row $row col $col"); }
   
   #produce copy of board for evaluation -> add stone at $row $col
   my $newboard = [ map {[@$_]} @$board ];
   $newboard->[$row]->[$col] = $color;
   # $string is a list of strongly connected stones: $foes=enemies adjacent to $string
   my ($string, $libs, $foes) = Util::get_string($newboard, $row, $col);
   my $caps = Util::find_captured ($newboard, $foes);
   if (@$libs == 0 and @$caps == 0){
      return (undef,'suicide');
   }
   for my $cap(@$caps){ # just erase captured stones
      $newboard->[$cap->[0]]->[$cap->[1]] = 0;
   }
   return ($newboard, '', $caps);#no err
}

1;
