use strict;
use warnings;
use Test::More tests => 8;
use lib qw|t/lib lib|;
use basilisk::Rulemap::Streets;
use basilisk::Streets;
use b_schema;

#use basilisk::Util qw/board_from_text/;

my $rulemap = new basilisk::Rulemap::Streets;
isa_ok ($rulemap, 'basilisk::Rulemap::Streets');


my $schema;
$schema = b_schema->init_schema('populate');

my $streets = basilisk::Streets->new(
         osc_file => 't/1.osm',
         #collapse_singletons => 1
);
$streets->fetch;
is (ref $streets->{data}{way}, 'ARRAY', 'ways read in an array');
is (ref $streets->{data}{node}, 'HASH', 'nodes read in a hash');
ok (exists $streets->{data}{node}{296968914}{id}, 'node ids are included in the hashes in {data}{node}');
ok (exists $streets->{data}{node}{296968914}, 'specific node included');
is ($streets->{data}{way}->[0]{nd}[0], 265766585, 'ValueAttr behaves correctly for one node...');
is (values %{$streets->{data}{node}}, 70, 'correct number of initial nodes = 70');


$streets->process;

is (values %{$streets->{data}{node}}, 10, 'correct number of processed nodes = 10');

