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
    'status'        => { data_type => 'INTEGER', default => 1 },
    'result'        => { data_type => 'TEXT', is_nullable => 1 },
    #turn--player currently with the initiative(index as 'side' col from player_to_game)
    'turn'           => { data_type => 'INTEGER', is_nullable => 0, default_value => 1 },
    'num_moves'      => { data_type => 'INTEGER', is_nullable => 0, default_value => 0 },
    'initial_position' => { data_type => 'INTEGER', is_nullable => 1 },
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

sub player_to_move_next{
   my $self = shift;
   my $player = $self->players->search({side => $self->turn})->next;
   return $player if $player;
   die "no player as side ".$self->turn." in game ".$self->id;
}
sub shift_turn{
   my $self = shift;
   $self->set_column('turn', ($self->turn)%2 + 1);
   $self->set_column('num_moves', $self->num_moves + 1);
   $self->update;
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
         return Util::empty_pos($self->size); #blob
      }
   }
   my $move = $self->moves->find({
      gid => $self->id,
      movenum => $self->num_moves,
   });
   return $move->position->position;#blob
}

sub current_board{
   my $self = shift;
   return Util::unpack_position($self->current_position, $self->size);
}

sub size{
   my $self = shift;
   return $self->ruleset->size
}

1;
