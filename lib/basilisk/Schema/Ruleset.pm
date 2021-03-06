package basilisk::Schema::Ruleset;
use List::Util;
use base qw/DBIx::Class/;
use basilisk::Util qw/cycle_desc to_percent/;
use JSON;

# Each game could has a 'phase' to determine who's turn it is 
# Each ruleset has a 'phase description' to describe the recurring sequence of turns
#  default description is  '0b 1w'
#  maybe handicap would be '1w 0b'
#  zen's is '0b 1w 2b 0w 1b 2w'
#  rengo is '0b 1w 2b 3w'
#  3-color could be '0b 1w 2r'
# Within a phase description:
#  b and w are the 'sides'
#  0 and 1 are the 'entities', mapped to 'entity' col in p2g table
# Idea: entities could be something other than players, such as 'random' or 'consensus'

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Ruleset');
__PACKAGE__->add_columns(
    'id'            => { data_type => 'INTEGER', is_auto_increment => 1 },
    'h'          => { data_type => 'INTEGER', default_value => '19'},
    'w'          => { data_type => 'INTEGER', default_value => '19'},
    'handicap'       => { data_type => 'INTEGER', default_value => '0'},
    'initial_time'   => { data_type => 'INTEGER', default_value => '0'},
    'byo'            => { data_type => 'INTEGER', default_value => '0'},
    'byo_periods'    => { data_type => 'INTEGER', default_value => '0'},
    'rules_description' => { data_type => 'TEXT', is_nullable => 1 }, #just for humans to read
    #for machines to read & shift phase: #like '0b 1w 2r'
    'phase_description' => { data_type => 'TEXT', default_value => '0b 1w'},
    #replacing extra_rules table:
    'other_rules' => { data_type => 'TEXT', is_nullable => 1}, #json, {topo:torus},etc.
    'komi' => { data_type => 'INTEGER', default_value => 0},
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many (positions => 'basilisk::Schema::Position', 'ruleset');
__PACKAGE__->has_many (games => 'basilisk::Schema::Game', 'ruleset');
__PACKAGE__->has_many (proposed_games => 'basilisk::Schema::Game_proposal', 'ruleset');
__PACKAGE__->has_many (extra_rules => 'basilisk::Schema::Extra_rule', 'ruleset');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    $table->add_index(name => idx_size => fields => [qw/h w/]);
    $table->add_index(name => idx_itime => fields => [qw/initial_time/]);
    $table->add_index(name => idx_hcp => fields => [qw/handicap/]);
}

sub num_entities{
   my $self = shift;
   my $pd = $self->phase_description;
   #return max digit in desc
   my @digits = $pd =~ /(\d)/g;
   return max(@digits) + 1
}
sub num_phases{
   my $self = shift;
   my $pd = $self->phase_description;
   #return num of words in description. '0b 1w' -> 2
   my @phases = split ' ', $pd;
   return scalar @phases;
}

sub sides { #returns ('b','w','r'), etc (in order from pd)
   my $self = shift;
   my $pd = $self->phase_description;
   my @sides;
   my %seen;
   for my $p (split ' ', $pd){
      $p =~ /([bwr])/;
      next if $seen{$1}++;
      push @sides, $1;
   }
   return @sides;
}
sub default_captures_string { #returns '0 0', or '0 0 0 0 0 0' for zen, etc
   my $self = shift;
   my $s = join ' ', map {0} (1..$self->num_phases);
   return $s;
}
sub size{
   my $self = shift;
   return ($self->h, $self->w);
}

#dont update, just return it
#unused
sub generate_rules_description_from_extra_rules{
   my $self = shift;
   my $h = $self->h;
   my $w = $self->w;
   my $topo;
   my ($heisenChance, $planckChance);
   my $schroedingo;
   my $pd = $self->phase_description;
   my $cycle = cycle_desc($pd);
   
   my @extra_rules = $self->extra_rules;
   
   for my $rulerow (@extra_rules){
      my $rule = $rulerow->rule;
      if (grep {$rule eq $_} @basilisk::Util::acceptable_topo){
         $topo = $rule;
      }
      elsif ($rule =~ /^heisengo ([\.\d]+)/){
         $heisenChance = $1;
      }
      elsif ($rule =~ /^planckgo ([\.\d]+)/){
         $planckChance = $1;
      }
      elsif ($rule eq 'schroedingo'){
         $planckChance = $1;
      }
   }
   my $desc = $h . 'x' . $w;
   $desc .= ", $topo" if $topo;
   if ($heisenChance){
      $desc .= ', HeisenGo';
      $desc .= '(' . to_percent($heisenChance) . ')' if $heisenChance != 1;
   }
   if ($planckChance){
      $desc .= ', PlanckGo';
      $desc .= '(' . to_percent($planckChance) . ')' if $planckChance != 1;
   }
   if ($schroedingo){
      $desc .= ', SchroedinGo';
   }
   return $desc;
}


#from other_rules column
#dont update, just return it
sub generate_rules_description{
   my $self = shift;
   my $rules = from_json ($self->other_rules // '{}');
   my $h = $self->h;
   my $w = $self->w;
   my $topo = $rules->{topo};
   my $heisenChance = $rules->{heisengo};
   my $planckChance = $rules->{planckgo};
   my $schroedingo = $rules->{schroedingo};
   my $pd = $self->phase_description;
   my $cycle = cycle_desc($pd);
   
   my @extra_rules = $self->extra_rules;
   
   my $desc = $h . 'x' . $w;
   $desc .= ", $topo" if $topo ne 'plane';
   if ($cycle ne '2-FFA'){
      $desc .= ", $cycle";
   }
   if ($heisenChance){
      $desc .= ', HeisenGo';
      $desc .= '(' . to_percent($heisenChance) . ')' if $heisenChance != 1;
   }
   if ($planckChance){
      $desc .= ', PlanckGo';
      $desc .= '(' . to_percent($planckChance) . ')' if $planckChance != 1;
   }
   if ($schroedingo){
      $desc .= ', SchroedinGo';
   }
   if ($rules->{ko_rule}){
      $desc .= '. Ko rule: ' . $rules->{ko_rule}
   }
   return $desc;
}


#either update or just return
sub generate_other_rules{
   my ($self,$command) = @_;
   die "'update' or just 'return'" unless $command;
   my @extra_rules = $self->extra_rules;
   my $rules = {topo => 'plane'};
   
   for my $rulerow (@extra_rules){
      my $rule = $rulerow->rule;
      if (grep {$rule eq $_} @basilisk::Util::acceptable_topo){
         $rules->{topo} = $rule;
      }
      elsif ($rule =~ /^heisengo (\S+),(\S+)$/){
         $rules->{heisengo} = $2;
         $rules->{planckgo} = $1;
      }
      elsif ($rule =~ /^planckgo (\S+)$/){ #this wont occur..
         $rules->{planckgo} = $2;
      }
      elsif ($rule eq 'schroedingo'){ #this wont occur..
         $rules->{schroedingo} = 1;
      }
   }
   return $rules if ($command ne 'update');
   $self->set_column('other_rules', to_json($rules));
   $self->update;
   return $rules;
}
1
