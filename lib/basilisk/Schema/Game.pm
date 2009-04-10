package basilisk::Schema::Game;

use base qw/DBIx::Class/;
use basilisk::Util;
use List::MoreUtils qw(uniq);

#values for status column
sub RUNNING {1}
sub FINISHED {2}
sub PAUSED {3}

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Game');
__PACKAGE__->add_columns(
    'id'             => { data_type => 'INTEGER', is_auto_increment => 1 },
    'ruleset'        => { data_type => 'INTEGER'},
    'status'        => { data_type => 'INTEGER', default_value => 1 }, #1=util::running
    'result'        => { data_type => 'TEXT', is_nullable => 1},
    #'num_moves'      => { data_type => 'INTEGER', default_value => 0 },
    'initial_position' => { data_type => 'INTEGER', is_nullable => 1 },
    #phase-- rule description is in ruleset
    'phase' => { data_type => 'INTEGER', default_value => 0 },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset', 'ruleset');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'gid');
__PACKAGE__->many_to_many( players => 'player_to_game', 'player');
__PACKAGE__->has_many(moves => 'basilisk::Schema::Move', 'gid');
__PACKAGE__->belongs_to (initial_pos => 'basilisk::Schema::Position', 'initial_position');
__PACKAGE__->has_many(comments => 'basilisk::Schema::Comment', 'gid');

sub sqlt_deploy_hook { #indices
    my($self, $table) = @_;
    $table->add_index(name => idx_status => fields => [qw/status/]);
}
sub num_moves{
   my $self = shift;
   return $self->count_related('moves');
}

sub player_name_to_move_next{
   my $self = shift;
   my ($entity, $side) = $self->turn;
   my $p = $self->find_related ('player_to_game', {entity => $entity});
   return $p->player->name if $p;
   die "no player as entity $entity in game ".$self->id;
}
sub shift_phase{
   my $self = shift;
   my $np = $self->ruleset->num_phases;
   $self->set_column('phase', ($self->phase + 1) % $np);
 #  $self->set_column('num_moves', $self->num_moves + 1);
   $self->update;
}
sub turn{ #return 'who' and 'what'
   my $self = shift;
   my $pd = $self->ruleset->phase_description;
   my @phases = split ' ', $pd;
   my ($entity, $side) = split '', $phases[$self->phase];
   return ($entity, $side);
}
sub num_entities{
   my $self = shift;
   return $self->ruleset->num_entities;
}
sub num_phases{
   my $self = shift;
   return $self->ruleset->num_phases;
}

sub last_move{
   my $self = shift;
   my $mvnum = $self->num_moves;
   return $self->find_related ('moves', {}, {order_by => 'movenum DESC'});
}
sub last_move_string{ 
   my $c = shift;
   #my $mvnum = $c->stash->{game}->num_moves;
   return $c->stash->{game}->find_related ('moves', {}, {order_by => 'movenum DESC'})->get_columns ('phase', 'move');
}

sub current_position{
   my $self = shift;
   my $move = $self->moves->find({
      gid => $self->id,
      movenum => $self->num_moves,
   });
   if ($move and $move->position){ 
      return $move->position->position;
   }
   #either no moves have taken place yet,
   #or the only moves have been passes
   my $initial_pos = $self->initial_pos;
   if ($initial_pos){
      return $initial_pos->position;
   }
   return Util::empty_pos($self->h, $self->w);
}
sub current_position_id{
   my $self = shift;
   return 0 if $self->num_moves == 0;
   my $move = $self->find_related ('moves', {
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
sub phase_description{
   my $self = shift;
   return $self->ruleset->phase_description
}

#TODO: getridof? not generic
sub side_of_entity{ 
   my ($self, $ent) = @_;
   my $pd = $self->phase_description;
   my @matches =  scalar $pd =~ /($ent)/g;
   return undef if @matches > 1; #return undef if zen,etc
   $pd =~ /$ent([bwr])/;
   return $1;
}

sub sides_of_entity{ 
   my ($self, $ent) = @_;
   my $pd = $self->phase_description;
   my @sides =  $pd =~ /$ent([bwr])/g; 
   return uniq @sides;
}
sub entities_of_side{ 
   my ($self, $side) = @_;
   my $pd = $self->phase_description;
   my @ents =  $pd =~ /(\d)$side/g;
   return uniq @ents
}

sub captures{
   my ($self, $move) = @_;
   my $last_move = $self->find_related ('moves', {}, {order_by => 'movenum DESC'});
   return $last_move->captures if $last_move;
   return join ' ', map {'0'} (1..$self->num_phases); # normally '0 0';
}

1;
