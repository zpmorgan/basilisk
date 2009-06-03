#!/usr/bin/perl

use strict;
use warnings;
use 5.10.0;
use FindBin '$Bin';
use lib "$Bin/../lib";
use basilisk::Schema;
use basilisk::Util;
use JSON;
my $dbfile = "$Bin/../basilisk.db";
my ($dsn, $user, $pass) = ("dbi:SQLite:$dbfile");

my $schema = basilisk::Schema->connect($dsn, $user, $pass) or
  die "Failed to connect to database";


my $rulesets = $schema->resultset('Ruleset');

#dangerous--will erase other_rules unless extra_rules still exist for them
for my $ruleset ($rulesets->all){
   #say $ruleset->id;
   #say $ruleset->rules_description;
   #say $ruleset->generate_rules_description. "\n";
   $ruleset->set_column (rules_description => $ruleset->generate_rules_description);
   $ruleset->update;
}


