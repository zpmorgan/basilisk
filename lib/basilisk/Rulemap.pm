package basilisk::Rulemap;
use basilisk::Util;
#use Moose; # automatically turns on strict and warnings
use strict;
use warnings;





sub new{
   my $class = shift;
   my %params = @_;
   my $self = {
      size => 19,
      topology => 'grid',
   };
   if ($params{size}){
      $self->{size} = $params{size};
   }
   if ($params{topology}){
      $self->{topology} = $params{topology};
   }
   bless $self, $class;
   return $self;
}




1;
