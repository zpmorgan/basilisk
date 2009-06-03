#!/usr/bin/perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../lib";
use basilisk::Schema;
use basilisk::Util;
use JSON;
my $dbfile = 'basilisk.db';
my ($dsn, $user, $pass) = ("dbi:SQLite:$dbfile");

my $schema = basilisk::Schema->connect($dsn, $user, $pass) or
  die "Failed to connect to database";

#before running this, in SQL:
#alter table Ruleset add column  other_rules TEXT;

my $rulesets = $schema->resultset('Ruleset');

#dangerous--will erase other_rules unless extra_rules still exist for them
for my $ruleset ($rulesets->search({id => {'<=' => 101}})->all){
   #print $ruleset->id, "\n";
   my $rules = from_json($ruleset->other_rules);
   next unless $rules->{heisengo} or $rules->{planckgo};
   #print $ruleset->id . '   ' . $rules->{heisengo} . '   ' . $rules->{planckgo} . "\n";
   
   my $planckChance = $rules->{heisengo};
   my $heisenChance = $rules->{planckgo};
   $rules->{heisengo} = $heisenChance;
   $rules->{heisengo} = $planckChance;
   $ruleset->set_column (other_rules => to_json('rules'));
}


