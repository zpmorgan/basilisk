package basilisk::Streets;
use Moose;
use XML::Simple;
use Modern::Perl;
use List::Util qw/shuffle/;
use Math::Trig qw/acos pi rad2deg/;
use Imager;
#This module fetches & processes & inserts street map data from openstreetmaps.

has osm_filename => (
   is => 'ro',
   isa => 'Str',
);
has osm_src => (
   is => 'rw',
   isa => 'Str',
);

has data => (
   is => 'rw',
   isa => 'HashRef',
);
has minlat => (is=>'ro', isa=>'Num',lazy=>1,default=> sub {$_[0]->data->{bounds}{minlat}} );
has minlon => (is=>'ro', isa=>'Num',lazy=>1,default=> sub {$_[0]->data->{bounds}{minlon}} );
has maxlat => (is=>'ro', isa=>'Num',lazy=>1,default=> sub {$_[0]->data->{bounds}{maxlat}} );
has maxlon => (is=>'ro', isa=>'Num',lazy=>1,default=> sub {$_[0]->data->{bounds}{maxlon}} );
has h => (is => 'ro',isa => 'Num',lazy => 1, default => sub{$_[0]->maxlat - $_[0]->minlat} );
has w => (is => 'ro',isa => 'Num',lazy => 1, default => sub{$_[0]->maxlon - $_[0]->minlon} );

sub fetch {
   my $self = shift;
   if ($self->osm_filename){
      eval "use File::Slurp";
      my $src = read_file ($self->osm_filename);
      my $ref = XMLin ($src, 
         ForceArray => [ 'tag' ],
         KeyAttr => { node => '+id' },
         ValueAttr => [ 'value', 'ref' ],
      );
      $self->data($ref);
      $self->osm_src($src);
   }
   else {die}
}

#processing goals:
  #identify intersections
  #eliminate singletons. 
  #congeal colinear sequential 2-nodes, not perpendicular ones.... 
sub process{
   my ($self) = @_;
   my $nodes = $self->{data}{node};
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
   for my $way (@$ways){
      #only roads
      next unless grep {$_->{k} eq 'highway'} @{$way->{tag}};
      for my $i (1..$#{$way->{nd}}){
         my $m = $way->{nd}[$i-1];
         my $n = $way->{nd}[$i];
         #see if it's a building or something.
         unless ($nodes->{$n} and $nodes->{$m}){
            next;
         }
         $nodes->{$n}{ref}{$m} = $nodes->{$m};
         $nodes->{$m}{ref}{$n} = $nodes->{$n};
      }
   }
   #now delete those which are out of the map 
   for my $node (values %$nodes){
      next if $node->{lat} < $self->maxlat
          and $node->{lat} > $self->minlat
          and $node->{lon} < $self->maxlon
          and $node->{lon} > $self->minlon;
      #apparently we're out of bounds.
      for my $other (values %{$node->{ref}}){ #make other nodes forget
         delete $other->{ref}{$node->{id}};
      }
      delete $nodes->{$node->{id}};
   }
   
   #now forget ways, and congeal nodes with 2 colinear colinear segments
   my $fin = 0;
   until ($fin){
      $fin=1;
      for my $node (shuffle values %$nodes){
         #my $node = $nodes->{$key};
         my @others = values %{$node->{ref}};
         if (@others < 2){ #delete.
            $fin=0;
            delete $others[0]->{ref}->{$node->{id}};
            delete $nodes->{$node->{id}};
            next;
         }
         next unless @others == 2;
         if (colinearish($others[0], $node, $others[1])){
            #congeal. (remove 1 node) 
            $fin=0;
            #die %$node unless $node->{id};
            #die "\n\n\n" .  join ('|',%{$others[0]->{ref}}) . "\n\n\n" . join ('|',%{$others[1]->{ref}}) . "\n\n\n" unless $node->{id};
            $others[0]->{ref}->{$others[1]->{id}} = $others[1];
            $others[1]->{ref}->{$others[0]->{id}} = $others[0];
            #die %{$others[0]->{ref}};
            delete $others[0]->{ref}->{$node->{id}};
            delete $others[1]->{ref}->{$node->{id}};
            delete $nodes->{$node->{id}}
         }
      }
   }
   #$self->draw;
   #warn join "\n", map {$_->{id}} values %$nodes;
}

sub colinearish{
   my ($n1,$n2,$n3) = @_;
   my @v1 = ($n2->{lat} - $n1->{lat}, $n2->{lon} - $n1->{lon});
   my @v2 = ($n3->{lat} - $n2->{lat}, $n3->{lon} - $n2->{lon});
   @v1 = normalize(@v1);
   @v2 = normalize(@v2);
   my $angle = abs acos($v1[0]*$v2[0] + $v1[1]*$v2[1]);
   #warn rad2deg $angle;
   return 1 if $angle < (pi / 6);
   #return 1 if $angle > (5* pi / 6);
} 
sub normalize{
   my ($x,$y) = @_;
   my $r = sqrt($x**2 + $y**2);
   return ($x/$r, $y/$r);
}

sub draw{
   my ($self) = @_;
   my $im = Imager->new(xsize => 400, ysize => 400);
   my $blk = Imager::Color->new( 0, 0, 0 );
   my $yellow = Imager::Color->new( 220, 220, 200 );
   $im->flood_fill(x=>50, y=>50, color=>$yellow);


   for my $n1 (values %{$self->data->{node}}){
      for my $n2 (values %{$n1->{ref}}){
         my $y1 = ($n1->{lat} - $self->minlat) / $self->h * 400;
         my $y2 = ($n2->{lat} - $self->minlat) / $self->h * 400;
         my $x1 = ($n1->{lon} - $self->minlon) / $self->w * 400;
         my $x2 = ($n2->{lon} - $self->minlon) / $self->w * 400;
         #die "$x1 $x2 $y1 $y2   $n1->{id} $n2->{id}";
         $im->line (color=>$blk, aa=>1,
                    x1=>$x1, x2=>$x2,
                    y1=>$y1, y2=>$y2);
      }
   }
   $im->write(file=>'/tmp/osm.png')

}

sub insert_dbic{
   my ($self, $schema) = @_;
   my $rs = $schema->resultset('basilisk::Schema::Streetmap');
   $rs->create({
      name => 'spoo',
      data => Storable::nfreeze $self->data,
      original_osm => $self->osm_src,
      minlon => $self->minlon,
      minlat => $self->minlat,
      maxlon => $self->maxlon,
      maxlat => $self->maxlat,
   });
}



1
