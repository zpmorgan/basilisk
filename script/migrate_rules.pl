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
for my $ruleset ($rulesets->all){
   my $rd = $ruleset->generate_rules_description;
   my $or = $ruleset->generate_other_rules('return'); #'update' to change
   print $ruleset->id . '::' . $rd . '|||' . to_json($or) . "\n";
}


