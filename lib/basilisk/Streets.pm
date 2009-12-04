package basilisk::Streets;
use Moose;
use XML::Simple;
use Modern::Perl;
#This module fetches & processes & inserts street map data from openstreetmaps.

has osc_file => (
   is => 'ro',
   isa => 'Str',
);

has data => (
   is => 'rw',
   isa => 'HashRef',
);


sub fetch {
   my $self = shift;
   if ($self->osc_file){
      my $ref = XMLin ($self->osc_file, 
         #ForceArray => [ 'way' ],
         KeyAttr => { node => 'id' },
         ValueAttr => [ 'value', 'ref' ],
      );
      $self->data($ref);
   }
   else {die}
}

#processing goals:
  #identify intersections
  #eliminate singletons. 
  #congeal colinear sequential 2-nodes, not perpendicular ones.... 
sub process{
   my ($self) = @_;
   my $nodes = $self->{data}{nodes};
   my $ways = $self->{data}{way};
   #warn %{$self->data->{way}{27067577}{nd}[0]};
   #count each node's references from ways
   #actually no...
   #for my $way (@{$ways}){
   #   for my $node (@{$way->{nd}}){
   #      $nodes->{$node->{ref}}->{count}++;
   #   }
   #}
   #Actually forget Ways, just use the nodes, with sequential connections from the ways :)
   for my $i (1 .. $#{$ways}){
      my $m = $ways->[$i-1];
      my $n = $ways->[$i];
      $nodes->{$n}{ref}{$m}++;
      $nodes->{$m}{ref}{$n}++;
      #for my $node (@{$way->{nd}}){
      #   $nodes->{$node->{ref}}->{count}++;
      #}
   }
}

sub draw{
   my ($self) = @_;
   
}

sub insert_dbic{
   my ($self, $schema) = @_;
   
}



1
