#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use basilisk;

basilisk->setup_engine('PSGI');
my $app = sub { basilisk->run(@_) };

