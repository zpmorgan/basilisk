package basilisk::Rulemap::Planckgo;
#rulemap modifier
use Moose::Role;
use List::Util qw/shuffle/;

#0 produces no effect, 1 is completely random
has planckChance => (
   is => 'rw',
   isa => 'Num',
   default => '0'
);


sub apply{
   my ($rulemap, $param) = @_;
   __PACKAGE__->meta->apply ($rulemap);
   $rulemap->planckChance ($param);
}


#next phase may be random.
around 'determine_next_phase' => sub {
   my ($orig, $self, $phase, $okay_phases) = @_;
   if (rand() < $self->planckChance){
      return $self->random_phase($okay_phases);
   }
   return $orig->($self, $phase, $okay_phases);
};

sub random_phase{
   my ($self, $okay_phases) = @_;
#   my @phases = split ' ', $self->phase_description;
   return $okay_phases->[int rand(@$okay_phases)]
}

1;
