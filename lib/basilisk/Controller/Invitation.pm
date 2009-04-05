package basilisk::Controller::Invitation;

use strict;
use warnings;
use parent 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub invite : Global{
   my ($self, $c) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   
   $c->stash->{template} = 'invite.tt';
}

1
