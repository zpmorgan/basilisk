package basilisk::Schema::Game;

use basilisk::Util;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Game');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
#    'white'      => { data_type => 'INTEGER', is_nullable => 1 },
#    'black'      => { data_type => 'INTEGER', is_nullable => 1 },
#    'size'          => { data_type => 'INTEGER', is_nullable => 0 },
    'ruleset'      => { data_type => 'INTEGER', is_nullable => 0 },
    #turn--player currently with the initiative(index as 'side' col from player_to_game)
    'turn'      => { data_type => 'INTEGER', is_nullable => 0, default_value => 0 },

);

sub last_move{
   my $self = shift;
   my $mv_count = $self->moves->count({});
   return $mv_count;
}
sub next_move{
   my $self = shift;
   my $mv_count = $self->moves->count({});
   return $mv_count + 1;
}
sub player_to_move_next{
   my $self = shift;
   my $player = $self->players->search({side => $self->turn})->next;
   return $player if $player;
   die "no player as side ".$self->turn." in game ".$self->id;
}


sub current_position{
   my $self = shift;
   my $lastmove = $self->last_move;
   if ($lastmove == 0){
      return Util::empty_pos($self->size); #blob
   }
   my $move = $self->moves->find({
      gid => $self->id,
      movenum => $lastmove,
   });
   return $move->position->position;#blob
}

sub board{
   my $self = shift;
   return Util::unpack_position($self->current_position, $self->size);
}

sub size{
   my $self = shift;
   return $self->ruleset->size
}

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset', 'ruleset');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'gid');
__PACKAGE__->many_to_many( players => 'player_to_game', 'player');
__PACKAGE__->has_many(moves => 'basilisk::Schema::Move', 'gid');
1;
