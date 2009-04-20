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
    #to sort by most recently active, this stores a time.
    #'perturbation' => { data_type => 'INTEGER', default_value => 0 },
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
   my ($self, $phase) = @_;
   unless (defined $phase){
      $phase = ($self->phase + 1) % $self->ruleset->num_phases
   }
   $self->set_column('phase', $phase);
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
sub fin{
   my $self = shift;
   my $lastmove = $self->last_move;
   return $lastmove->fin if $lastmove and $lastmove->fin;
   #make a default one..
   return join ' ', map {0} (1..$self->ruleset->num_phases)
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
   my $move = $self->find_related ('moves', {
      movenum => $self->num_moves,
   });
   return 0 unless $move;
   return $move->position_id;
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

sub phases{
   my ($self) = @_;
   my $pd = $self->phase_description;
   my @phases = map {[split '',$_]} split ' ', $pd;
   return @phases;
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


sub okay_phasesBLAH{
   my ($self) = @_;
   my $last_move = $self->find_related ('moves', {}, {order_by => 'movenum DESC'});
   my $fin = $last_move->fin;
   unless ($fin) { #all okay
      return (0..$self->num_phases-1);
   }
   my @okay_phases;
   my @fins = split ' ', $fin;
   for my $pnum (0..$self->num_phases-1){
      push @okay_phases, $pnum if $fins[$pnum] == Util::FIN_INTENT_OKAY();
      #TODO: some dropped phases will be okay..
   }
   return @okay_phases;
}

#take the most recent move, and adjust its fin column
#  to signal intent to score, drop, or finish.
#  I dont see a reason to signal okay...
#call this right after it's created
sub signal_fin_intent{
   my ($self, $intent, $for_all_phases_of_ent) = @_;
   my ($last_move, $move_before_last) = $self->search_related ('moves', {}, {
      order_by => 'movenum DESC',
      limit    => 2,
   });
   
   #can not use $self->fin() here. it would be circular because this is
   # what sets last_move->fin, which self->fin wraps
   my $prev_fin; #'0 0',etc
   if ($move_before_last){
      $prev_fin = $move_before_last->fin
   }
   unless ($prev_fin){
      $prev_fin = join ' ', map {0} (1..$self->num_phases);
   }
   my @fins = split ' ', $prev_fin;
   
   my @phases_to_signal;
   if ($for_all_phases_of_ent){
      @phases_to_signal = $self->phases_of_ent ($last_move->entity)
   }
   else {
      @phases_to_signal = $last_move->phase;
   }
   for my $phase (@phases_to_signal){
      $fins[$phase] = $intent;
   }
   my $newfin = join ' ', @fins;
   $last_move->set_column('fin', $newfin);
   $last_move->update();
}

#someone made a move?
#reset FIN and SCORED to OKAY
#leave DROP as it is
#call this right after it's created
sub clear_fin_intent{
   my ($self, $intent, $for_all_phases_of_ent) = @_;
   my ($last_move) = $self->find_related ('moves', {}, {
      order_by => 'movenum DESC',
   });
   
   #can not always use $self->fin() here. see above..
   my $fin = $last_move->fin;
   unless ($fin){
      $fin = join ' ', map {0} (1..$self->num_phases);
   }
   
   my @fins = split ' ', $fin;
   for my $f (@fins){
      unless ($f == Util::FIN_INTENT_DROP()){
         $f = Util::FIN_INTENT_OKAY();
      }
   }
   my $newfin = join ' ', @fins;
   $last_move->set_column('fin', $newfin);
   $last_move->update();
}

#return all phases with FIN_INTENT_OKAY
sub okay_phases{
   my ($self) = @_;
   my @fins = split ' ', $self->fin; #'0 0',etc
   my @phases = (0..$self->num_phases-1);
   return grep {$fins[$_] == Util::FIN_INTENT_OKAY()} @phases
}
#return all phases with FIN_INTENT_OKAY
sub fin_phases{
   my ($self) = @_;
   my @fins = split ' ', $self->fin; #'0 0',etc
   my @phases = (0..$self->num_phases-1);
   return grep {$fins[$_] == Util::FIN_INTENT_FIN()} @phases
}
#return all phases without FIN_INTENT_DROP
sub active_phases{
   my ($self) = @_;
   my @fins = split ' ', $self->fin; #'0 0',etc
   my @phases = (0..$self->num_phases-1);
   return grep {$fins[$_] != Util::FIN_INTENT_DROP()} @phases
}

#TODO: take basis into account?
#return undef if none
sub active_sides{
   my ($self) = @_;
   my @phases = $self->phases;
   my @a_phases = $self->active_phases;
   my %notdropped_sides;
   for (@a_phases){
      my $side = $phases[$_]->[1];
      $notdropped_sides{$side}++ #$_ ~~ [0,'b']
   }
   return keys %notdropped_sides;
}

sub winner_by_resignation{
   my ($self) = @_;
   my @a_sides = $self->active_sides;
   return undef unless @a_sides==1;
   return $a_sides[0];
}
1;
