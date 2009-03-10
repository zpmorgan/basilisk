package basilisk::Schema::Game;

use basilisk::Util;
use base qw/DBIx::Class/;

#values for status column
sub RUNNING {1}
sub FINISHED {2}
sub PAUSED {3}

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Game');
__PACKAGE__->add_columns(
    'id'             => { data_type => 'INTEGER', is_auto_increment => 1 },
    'ruleset'        => { data_type => 'INTEGER', is_nullable => 0 },
    'status'        => { data_type => 'INTEGER', default_value => 1 },
    'result'        => { data_type => 'TEXT', is_nullable => 1 },
    'num_moves'      => { data_type => 'INTEGER', is_nullable => 0, default_value => 0 },
    'initial_position' => { data_type => 'INTEGER', is_nullable => 1 },
    #phase-- rule description is in ruleset
    'phase' => { data_type => 'INTEGER', is_nullable => 0, default_value => 0 },
    #captures--space separated string, has sum of all captures per phase
    'captures' => { data_type => 'TEXT', is_nullable => 0} #'0 0'
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset', 'ruleset');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'gid');
__PACKAGE__->many_to_many( players => 'player_to_game', 'player');
__PACKAGE__->has_many(moves => 'basilisk::Schema::Move', 'gid');
__PACKAGE__->belongs_to (initial_pos => 'basilisk::Schema::Position', 'initial_position');

sub sqlt_deploy_hook { #indices
    my($self, $table) = @_;
    $table->add_index(name => idx_game => fields => [qw/num_moves/]);
}
#unused:
sub player_to_move_next{
   my $self = shift;
   my ($entity, $side) = $self->turn;
   my $player = $self->players->find ({entity => $entity});
   return $player if $player;
   die "no player as entity $entity in game ".$self->id;
}
sub shift_phase{
   my $self = shift;
   #my $num_players = $self->num_players;
   my $np = $self->ruleset->num_phases;
   $self->set_column('phase', ($self->phase + 1) % $np);
   $self->set_column('num_moves', $self->num_moves + 1);
   $self->update;
}
sub turn{ #return 'who' and 'what'
   my $self = shift;
   my $pd = $self->ruleset->phase_description;
   my @phases = split ' ', $pd;
   my ($entity, $side) = split '', $phases[$self->phase];
   return ($entity, $side);
}
sub num_players{
   my $self = shift;
   return $self->ruleset->num_players;
}
sub num_phases{
   my $self = shift;
   return $self->ruleset->num_phases;
}

sub last_move{ #'pass' or 'b t4' etc
   my $self = shift;
   my $mvnum = $self->num_moves;
   return $self->moves->find ({movenum => $mvnum});
}
sub last_move_string{ #'pass' or 'b t4' etc
   my $c = shift;
   my $mvnum = $c->stash->{game}->num_moves;
   return $c->stash->{game}->moves->find ({movenum => $mvnum})->movestring;
}

sub current_position{
   my $self = shift;
   if ($self->num_moves == 0){ #no moves have taken place yet.
      my $initial_pos = $self->initial_pos;
      if ($initial_pos){
         return $initial_pos->position;
      }
      else{
         return Util::empty_pos($self->h, $self->w); #blob
      }
   }
   my $move = $self->moves->find({
      gid => $self->id,
      movenum => $self->num_moves,
   });
   return $move->position->position;#blob
}
sub current_position_id{
   my $self = shift;
   return 0 if $self->num_moves == 0;
   my $move = $self->moves->find({
      gid => $self->id,
      movenum => $self->num_moves,
   });
   return $move->position->id;
}

sub current_board{
   my $self = shift;
   return Util::unpack_position($self->current_position, $self->size);
}

sub h{
   my $self = shift;
   return $self->ruleset->h
}
sub w{
   my $self = shift;
   return $self->ruleset->w
}
sub sides{
   my $self = shift;
   return $self->ruleset->sides
}
sub captures_per_side{ #{w=>3,b=>1}
   my $self = shift;
   my @caps = split ' ', $self->captures;
   my @phases = split ' ', $self->phase_description;
   my %cps;
   for (0..@phases-1){ #1w
      $phases[$_] =~ /([bwr])/; #w
      $cps{$1} += $caps[$0];
   }
   return \%cps
}

1;
