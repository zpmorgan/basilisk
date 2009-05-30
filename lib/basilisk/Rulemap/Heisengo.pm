package basilisk::Rulemap::Heisengo;
#rulemap modifier
use Moose::Role;
use List::Util qw/shuffle/;


has chance_random_turn => (
   is => 'rw',
   isa => 'Num',
   default => '0'
);

has heisenChance => (
   is => 'rw',
   isa => 'Num',
   default => '0'
);


sub apply{
   my ($rulemap, $param) = @_;
   __PACKAGE__->meta->apply ($rulemap);
   $rulemap->heisenChance ($param);
}

#find adjacent nodes, and perhaps try moving there randomly
around 'evaluate_move' => sub{
   my ($orig, $self,  $board, $node, $side) = @_;
   if (rand() > $self->heisenChance){
      return $orig->($self,$board, $node, $side);
   }
   
   #This would probably be a bad idea, if half the players don't realize it's possible.
   if ($self->stone_at_node ($board, $node)){
      return ('', 'You may not move on an occupied node...');
   }
   
   my @nodes = ($node);
   push @nodes, $self->node_liberties($node);
   for my $n (shuffle @nodes){
      my ($newboard, $err, $caps, $newnode) = $orig->($self, $board, $n, $side);
      return ($newboard, $err, $caps, $newnode) unless $err;
   }
   return ('', 'what you thinking willy?'); #at least $node should be valid..
};




1
