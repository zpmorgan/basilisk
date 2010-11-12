#!/usr/bin/perl
use Modern::Perl;
use lib 'lib';

use Plack::App::URLMap;
use Plack::Runner;

use basilisk;

basilisk->setup_engine('PSGI');
my $app1 = sub { basilisk->run(@_) };


use FCGI::Engine;

my $engine = FCGI::Engine->new_with_options(
   handler_class  => 'arteebas',
   handler_method => 'process_input',
   pre_fork_init  => sub {
      require 'arteebas';
   },
);

my $app2 = sub { $engine->run(); };

my $urlmap = Plack::App::URLMap->new;
$urlmap->mount ("/" => $app1);
$urlmap->mount ("/rt" => $app2);

my $runner = Plack::Runner->new;
$runner->parse_options(@ARGV);
$runner->run($urlmap);
