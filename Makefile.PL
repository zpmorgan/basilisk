# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'basilisk';
all_from 'lib/basilisk.pm';

requires 'Catalyst::Runtime' => '5.71000';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'parent';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
# these are guesses:
requires 'Digest::SHA';
requires 'DBIx::Class';
requires 'Template';
requires 'DBD::SQLite';
requires 'Test::More';
requires 'Moose';
requires 'Test::WWW::Mechanize::Catalyst';
requires 'XML::Atom::SimpleFeed';
requires 'Number::Tolerant';
requires 'Template::Plugin::DateTime';
#requires 'Math::Random::MT::Auto';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Model::DBIC::Schema';
requires 'SQL::Translator';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
