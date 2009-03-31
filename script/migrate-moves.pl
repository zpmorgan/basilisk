#!/usr/bin/perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../lib";
use basilisk::Schema;
use basilisk::Util;
my $dbfile = 'basilisk.db';
my ($dsn, $user, $pass) = ("dbi:SQLite:$dbfile");

my $schema = basilisk::Schema->connect($dsn, $user, $pass) or
  die "Failed to connect to database";

#before running this, in SQL:
#alter table Move add column   move TEXT;
#alter table Move add column  phase INTEGER;

for my $move ($schema->resultset('Move')->all){
   my $ms = $move->movestring;
   my $phase = ($move->movenum+1)%2;
   $move->set_column('phase', $phase);
   $ms =~ s/^[bw] //;
   if ($ms =~ /^row(\d+), col(\d+)$/){
      $move->set_column('move', "{$1-$2}");
   }
   else {
      $move->set_column('move', $ms);
   }
   $move->update
}
__END__
then, SQL:


BEGIN TRANSACTION;
CREATE TEMPORARY TABLE t_mv (
  gid INTEGER NOT NULL,
  movenum INTEGER NOT NULL,
  position_id INTEGER NOT NULL,
  dead_groups TEXT,
  time INTEGER NOT NULL,
  captures TEXT NOT NULL, move TEXT, phase INTEGER,
  PRIMARY KEY (gid, movenum)
);
INSERT INTO t1_backup SELECT gid,movenum,position_id,dead_groups,time,captures FROM Move;
DROP TABLE Move;
CREATE TABLE Move(
  gid INTEGER NOT NULL,
  movenum INTEGER NOT NULL,
  position_id INTEGER NOT NULL,
  dead_groups TEXT,
  time INTEGER NOT NULL,
  captures TEXT NOT NULL, move TEXT, phase INTEGER,
  PRIMARY KEY (gid, movenum)
);
INSERT INTO Move SELECT * FROM t_mv;
DROP TABLE t_mv;
COMMIT;



