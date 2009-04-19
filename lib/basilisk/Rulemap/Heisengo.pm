package basilisk::Rulemap::Heisengo;
#rulemap modifier
use Moose::Role;
use List::Util qw/shuffle/;


has chance_random_turn => (
   is => 'rw',
   isa => 'Num',
   default => '0'
);

has chance_random_placement => (
   is => 'rw',
   isa => 'Num',
   default => '0'
);



sub apply{
   my ($rulemap, $rule) = @_;
   __PACKAGE__->meta->apply ($rulemap);
   
   $rule =~ /^heisengo (.*)$/;
   my ($randturn, $randplace) = split ',', $1;
   $rulemap->chance_random_turn ($randturn);
   $rulemap->chance_random_placement ($randplace);
}

#next phase may be random.
around 'determine_next_phase' => sub {
   my ($orig, $self, $phase) = @_;
   if (rand() < $self->chance_random_turn){
      return $self->random_phase();
   }
   return $orig->($self, $phase);
};

sub random_phase{
   my $self = shift;
   my @phases = split ' ', $self->phase_description;
   return int rand(@phases)
}

#find adjacent nodes, and perhaps try moving there randomly
around 'evaluate_move' => sub{
   my ($orig, $self,  $board, $node, $side) = @_;
   if (rand() < $self->chance_random_placement){
      my @nodes = ($node);
      push @nodes, $self->node_liberties($node);
      for my $n (shuffle @nodes){
         my ($newboard, $err, $caps, $newnode) = $orig->($self, $board, $n, $side);
         return ($newboard, $err, $caps, $newnode) unless $err;
      }
      return ('', 'what you thinking willy?'); #at least $node should be valid..
   }
   return $orig->($self,$board, $node, $side);
};




1
