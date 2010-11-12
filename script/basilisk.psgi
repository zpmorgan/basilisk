#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use basilisk;
use Plack::App::URLMap;

basilisk->setup_engine('PSGI');
my $app1 = sub { basilisk->run(@_) };

use FCGI::Engine;

my $engine = FCGI::Engine->new_with_options(
   handler_class  => 'arteebas',
   handler_method => 'process_input',
   pre_fork_init  => sub {
      eval('use arteebas;')
   },
);
my $app2 = sub { $engine->run(); };

my $urlmap = Plack::App::URLMap->new;
$urlmap->mount ("/" => $app1);
$urlmap->mount ("/rt" => $app2);

my $app = $urlmap->to_app();

