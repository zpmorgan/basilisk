package basilisk::Streets;
use Moose;
use XML::Simple;
use Modern::Perl;
use List::Util qw/shuffle sum min/;
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

has congeal_dist => ( #todo: base this on size of stone in pixels.
   is => 'ro',isa => 'Num', lazy => 1,
   default => sub{ my $self=shift; 
               return (min($self->h, $self->w)/20) }
);

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
         die 'blah' if $node->{ref}{$node->{id}};
         #skip if already deleted
         next unless $nodes->{$node->{id}};
         my @others = values %{$node->{ref}};
         if (@others < 2){ #delete.
            $fin=0;
            delete $others[0]->{ref}->{$node->{id}} if $others[0];
            delete $nodes->{$node->{id}};
            next;
         }
         if (@others == 2){
            if (colinearish($others[0], $node, $others[1])){
               #congeal its 2 lines. (remove 1 node) 
               $fin=0;
               $others[0]->{ref}->{$others[1]->{id}} = $others[1];
               $others[1]->{ref}->{$others[0]->{id}} = $others[0];
               delete $others[0]->{ref}->{$node->{id}};
               delete $others[1]->{ref}->{$node->{id}};
               delete $nodes->{$node->{id}}
            }
         }
      }
   }
   #now congeal groups of nodes that are somewhat close.
   $fin=0;
   until ($fin){
      $fin=1;
      warn scalar values %$nodes;
      for my $node (shuffle values %$nodes){
         next unless $nodes->{$node->{id}};
         $fin=0 if $self->congeal_adequately($node);
      }
   }
   #to be neat, here we buhlete unnecessary flags
   for my $node (values %$nodes){
      delete $node->{congealed_adequately};
   }
   #$self->draw;
   #warn join "\n", map {$_->{id}} values %$nodes;
}
sub congeal_adequately{
   my ($self, $node) = @_;
   return 0 if $node->{congealed_adequately};
   $self->draw and die if rand()<.001;
   my @others = (values %{$node->{ref}});
   for my $o (@others){
      if ($self->near_enough($node, $o)){
         $self->congeal_nodes($node, $o);
         return 1;
      }
   }
   $node->{congealed_adequately} = 1;
   return 0;
   
   my @nodes = ($node, values %{$node->{ref}});
   warn join '/',map{$_->{id}}@nodes;$self->draw and die if rand()<.001;
   for my $i (0..$#nodes-1){
      for my $j($i+1..$#nodes){
         if ($self->near_enough($nodes[$i], $nodes[$j])){
            $self->congeal_nodes($nodes[$i], $nodes[$j]);
            $nodes[$i]{congealed_adequately} = 0;
            return 1;
         }
      }
   }
   $node->{congealed_adequately} = 1;
   return 0;
}
sub near_enough{
   my ($self, $n1,$n2) = @_;
   #warn sqrt(($n2->{lat}-$n1->{lat})**2 + ($n1->{lon}-$n2->{lon})**2) . "|||" . $self->congeal_dist;
   return 1 if sqrt(($n2->{lat}-$n1->{lat})**2 + ($n1->{lon}-$n2->{lon})**2) < $self->congeal_dist;
}

sub congeal_nodes{
   my ($self, @nodes) = @_;
   #merge into the node with the smallest id
   @nodes = sort {$a->{id} <=> $b->{id}} @nodes;
   my $avg_lat = sum (map {$_->{lat}} @nodes) / @nodes;
   my $avg_lon = sum (map {$_->{lon}} @nodes) / @nodes;
   #warn join '[]',map {$_->{lat}} @nodes;
   #warn sum (map {$_->{lat}} @nodes);
   #warn $avg_lat;
   #warn "\n\n" . join "\n", map {join('|',%{$_}) . ':::::' . join'/',%{$_->{ref}}} @nodes;
   $nodes[0]{lat} = $avg_lat;
   $nodes[0]{lon} = $avg_lon;
   for my $i (1..$#nodes){
      my $melt = $nodes[$i];
      for my $meltref (values %{$melt->{ref}}){
         next if $nodes[0] == $meltref;
         $nodes[0]->{ref}{$meltref->{id}} = $meltref;
         $meltref->{ref}{$nodes[0]->{id}} = $nodes[0];
         delete $meltref->{ref}{$melt->{id}};
      }
      delete $self->data->{nodes}{$melt->{id}};
      delete $nodes[0]{ref}{$melt->{id}};
   }
}

sub colinearish{
   my ($n1,$n2,$n3) = @_;
   my @v1 = ($n2->{lat} - $n1->{lat}, $n2->{lon} - $n1->{lon});
   my @v2 = ($n3->{lat} - $n2->{lat}, $n3->{lon} - $n2->{lon});
   @v1 = normalize(@v1);
   @v2 = normalize(@v2);
   die join '|', map {$_->{'lon'}.','.$_->{'lat'}}($n1,$n2,$n3) unless (($v1[0] or $v1[1]) and ($v2[0] or $v2[1]));
   my $angle = abs acos($v1[0]*$v2[0] + $v1[1]*$v2[1]);
   #warn rad2deg $angle;
   return 1 if $angle < (pi / 6);
   #return 1 if $angle > (5* pi / 6);
} 
sub normalize{
   my ($x,$y) = @_;
   my $r = sqrt($x**2 + $y**2);
   return ($x/$r, $y/$r) if $r;
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
