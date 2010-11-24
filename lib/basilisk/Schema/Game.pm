package basilisk::Schema::Game;
use warnings;
use strict;

use base qw/DBIx::Class/;
use basilisk::Util qw/empty_pos unpack_position empty_board/;
use List::MoreUtils qw(uniq);

use basilisk::Constants qw{ GAME_RUNNING GAME_FINISHED GAME_PAUSED 
         FIN_INTENT_DROP FIN_INTENT_OKAY FIN_INTENT_FIN FIN_INTENT_SCORED};

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Game');
__PACKAGE__->add_columns(
   id               => { data_type => 'INTEGER', is_auto_increment => 1 },
   #initial_position => { data_type => 'INTEGER', is_nullable => 1 },
   #phase-- one of those defined by phase_description
   #phase => { data_type => 'INTEGER', default_value => 0 },
   #to sort by most recently active, this stores a time.
   #perturbation => { data_type => 'INTEGER', default_value => 0 },
   #use a trigger in db after new moves
   #number_of_moves => { data_type => 'INTEGER', default_value => 0 },


   #ruleset is not a table any more... it's now a few columns in the Game table.
  # ruleset          => { data_type => 'INTEGER'},
   rules => { data_type => 'TEXT', default_value => '{h:19,w:19}'}, #json.
   rules_description => { data_type => 'TEXT', default_value => 'Moo'}, #english.
   phase_description => { data_type => 'TEXT', default_value => '0b 1w'},
   time_system => { data_type => 'INTEGER', default_value => 0}, #0 == no time limits.
   main_time   => { data_type => 'INTEGER', default_value => '0'}, #in seconds
   secondary_time   => { data_type => 'INTEGER', default_value => '0'}, #in seconds
   time_periods   => { data_type => 'INTEGER', default_value => '0'}, #various systems seem to use something of the sort.

   status           => { data_type => 'INTEGER', default_value => GAME_RUNNING },
   result   => { data_type => 'TEXT', is_nullable => 1 }, # B+resign, etc
);



#Here's the num_moves trigger:
#BEGIN
#UPDATE Game SET num_moves = (SELECT COUNT (*) FROM Move WHERE gid = new.gid) WHERE id=new.gid;
#END;
#To reset it in every row:
#update Game set number_of_moves=(SELECT COUNT (*) FROM Move WHERE gid = id);
__PACKAGE__->set_primary_key('id');
#__PACKAGE__->belongs_to(ruleset => 'basilisk::Schema::Ruleset', 'ruleset');
__PACKAGE__->has_many(player_to_game => 'basilisk::Schema::Player_to_game', 'gid');
__PACKAGE__->many_to_many( players => 'player_to_game', 'player');
__PACKAGE__->has_many (events => 'basilisk::Schema::Game_event', 'gameid');
#__PACKAGE__->has_many(moves => 'basilisk::Schema::Move', 'gid');
#__PACKAGE__->belongs_to (initial_pos => 'basilisk::Schema::Position', 'initial_position');
#__PACKAGE__->has_many(comments => 'basilisk::Schema::Comment', 'gid');

sub sqlt_deploy_hook { #indices
    my($self, $table) = @_;
    $table->add_index(name => idx_status => fields => [qw/status/]);
}

sub get_events_after{
   my ($self, $eventnum) = @_;
   return $self->search_related ('events' , {
      'event_number' => {'>' => $eventnum},
   });
}


sub player_can_move{
   my ($self, $playerid) = @_;
   my ($entity, $side) = $self->current_phase;
   return 0 unless defined $entity;
   my $p2g = $self->find_related('player_to_game', {entity=>$entity} );
   return $side if $p2g->pid == $playerid; 
}

sub current_phase{
   my $self = shift;
   my $pd = $self->phase_description;
   my $phase_num = $self->current_phase_num;
   return unless defined $phase_num;
   my @phases = split ' ', $pd;
   my ($entity, $side) = split '', $phases[$phase_num];
   return ($entity, $side);
   
}

sub current_phase_num{
   my $self = shift;
   #return if $self->active == 0;
   my $lastmove = $self->last_move;
   if ($lastmove){ 
      return $lastmove->now_phase;
   }
   return 0;
   #else die'no lastmove'
}

sub num_entities{
   my $self = shift;
   return $self->num_entities;
}
sub num_phases{
   my $self = shift;
   return $self->num_phases;
}

sub initial_phase{
   my $self = shift;
   my @phases = split ' ', $self->phase_description;
   return $phases[0];
}

sub last_move{
   my $self = shift;
   my $lastmove = $self->search_related( 'events', {
      type => 'move',
   }, {
      order_by => { -desc => 'movenum' },
   }) -> first;
   return $lastmove;
}

sub num_moves{ 
   my $self = shift;
   return $self->last_move->movenum('moves');
}


################################################################33333


sub player_to_move{
   my $self = shift;
   my ($entity, $side) = $self->turn;
   my $p2g = $self->find_related ('player_to_game', {entity => $entity});
   return $p2g->player if $p2g;
   die "no player as entity $entity in game ".$self->id;
}
sub player_to_move_name{ #rm?
   my $self = shift;
   my $p = $self->player_to_move_next;
   return $p->name;
   #die "no player as entity $entity in game ".$self->id;
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

#return string of representative nodes that were marked dead in last move.
sub deads{
   my $self = shift;
   my $lastmove = $self->last_move;
   return $lastmove->dead_groups if $lastmove and $lastmove->dead_groups;
   return '';
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
   return empty_pos($self->size);
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
   return unpack_position($self->current_position, $self->size);
}
sub initial_board{
   my $self = shift;
   my $initial_pos = $self->initial_pos;
   if ($initial_pos){
      return unpack_position ($initial_pos->position, $self->size);
   }
   return empty_board($self->size);
}

#~ sub size{
   #~ my $self = shift;
   #~ return $self->ruleset->size
#~ }
#~ 
#~ sub h{
   #~ my $self = shift;
   #~ return $self->ruleset->h
#~ }
#~ sub w{
   #~ my $self = shift;
   #~ return $self->ruleset->w
#~ }
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

sub phases_of_entity{ 
   my ($self, $ent) = @_;
   my @phases = $self->phases;
   my @pnums;
   for (0..@phases-1){
      push @pnums,$_  if $phases[$_][0] == $ent;
   }
   return @pnums;
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
sub side_of_phase{ 
   my ($self, $phasenum) = @_;
   my @phases = $self->phases;
   return $phases[$phasenum][1];
}

sub captures{
   my ($self, $move) = @_;
   my $last_move = $self->search_related ('moves', {}, {order_by => 'movenum DESC'})->first;
   return $last_move->captures if $last_move;
   return join ' ', map {'0'} (1..$self->num_phases); # normally '0 0';
}

#take the most recent move, and adjust its fin column
#  to signal intent to score, drop, or finish.
#  I dont see a reason to signal okay...
#call this right after it's created
sub signal_fin_intent{
   my ($self, $intent, $for_all_phases_of_ent) = @_;
   my ($last_move) = $self->find_related ('moves', {}, {
      order_by => 'movenum DESC',
   });
   
   my @fins = split ' ',  $self->fin;
   my @phases_to_signal;
   
   if ($for_all_phases_of_ent){
      @phases_to_signal = $self->phases_of_entity ($last_move->entity)
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
   my ($self) = @_;
   my ($last_move) = $self->search_related ('moves', {}, {
      order_by => 'movenum DESC',
      rows=>1
   });
   
   #can not always use $self->fin() here. see above..
   my $fin = $self->fin;
   unless ($fin){
      $fin = join ' ', map {0} (1..$self->num_phases);
   }
   
   my @fins = split ' ', $fin;
   for my $f (@fins){
      unless ($f == FIN_INTENT_DROP()){
         $f = FIN_INTENT_OKAY();
      }
   }
   my $newfin = join ' ', @fins;
   $last_move->set_column('fin', $newfin);
   $last_move->update();
}
#if there's disagreement, turn all _SCORED back into _FIN
sub clear_fin_scored{
   my ($self) = @_;
   my ($last_move) = $self->find_related ('moves', {}, {
      order_by => 'movenum DESC',
   });
   
   my $fin = $self->fin;
   unless ($fin){
      $fin = join ' ', map {0} (1..$self->num_phases);
   }
   
   my @fins = split ' ', $fin;
   for my $f (@fins){
      if ($f == FIN_INTENT_SCORED()){
         $f = FIN_INTENT_FIN();
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
   return grep {$fins[$_] == FIN_INTENT_OKAY()} @phases
}
#return all phases with FIN_INTENT_OKAY
sub fin_phases{
   my ($self) = @_;
   my @fins = split ' ', $self->fin; #'0 0',etc
   my @phases = (0..$self->num_phases-1);
   return grep {$fins[$_] == FIN_INTENT_FIN()} @phases
}
#return all phases without FIN_INTENT_DROP
sub active_phases{
   my ($self) = @_;
   my @fins = split ' ', $self->fin; #'0 0',etc
   my @phases = (0..$self->num_phases-1);
   return grep {$fins[$_] != FIN_INTENT_DROP()} @phases
}

#TODO: take basis into account?
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
sub no_phases_are_okay{
   #this means some phase(s) has shown no intention of stopping
   my ($self) = @_;
   my $fin = $self->fin;
   return 0 if $fin =~ /0/; #okay --false
   return 1
}

#if so, there's a winner. game's over
sub done_thinking{
   my ($self) = @_;
   my $fin = $self->fin;
   return 0 if $fin =~ /0/; #_OKAY ~~ incomplete
   return 0 if $fin =~ /1/; #_FIN ~~ incomplete
   return 1; #everyone's either _DROP or _SCORED
}
1;
