package basilisk::Rulemap::Atom;
#rulemap modifier
use Moose::Role;

requires ('remove_caps');

#after 'remove_caps' => sub{
sub remove_caps{
   my ($self, $board, $caps) = @_;
   for my $cap (@$caps){
      for my $adj ($self->get_adjacents($board,$cap)){
         $self->remove_stone $adj
      }
      $self->remove_stone $cap
   }
}

#__PACKAGE__->meta->apply ($rulemap);


