package basilisk::Controller::Root;

use strict;
use warnings;
use basilisk::Util;
use parent 'Catalyst::Controller';



# this is so the path doesn't need prefix /root/
# but I'm only using global actions anyways..
__PACKAGE__->config->{namespace} = '';


sub index :Path :Args(0) {
   my ( $self, $c ) = @_;
   
   # Hello World
   if ($c->session->{name}){
      $c->stash->{message} = 'Hello, ' . $c->session->{name};
      $c->stash->{template} = 'message.tt';
   }
   else{
      $c->stash->{title} = 'log in';
      $c->stash->{name} = $c->session->{name};
      $c->stash->{template} = 'login.tt';
   }
}



# 404
sub default :Path {
   my ( $self, $c ) = @_;
   my $req = $c->request;
   my @info; # = ("Page'sn't found!");
   push @info, "path: " . join ', ', @{$req->path};
   push @info, "args: " . join ', ', @{$req->args};
   push @info, "referer: ".$req->referer;
   push @info, "secure: ".$req->secure;
   push @info, "params: ",%{$req->parameters};
   push @info, "session data: ";
   for my $key (keys %{$c->session}){
      push @info, " * $key: ". $c->session->{$key};
   }
   $c->stash->{body} = join "<br>",@info;
   $c->stash->{template} = '404.tt';
#   $c->response->body( join "<br>",@info);
   $c->response->status(404);
}

# end -- Attempt to render a view.
#this is a RenderView action, so this is called right before we're sent to the view
sub end : ActionClass('RenderView') {
   my ( $self, $c ) = @_;
   #set some tt var for header
   $c->stash->{logged_in} = $c->session->{logged_in} ? 1 : 0;
   #$c->stash->{name} seems to be basilisk, and unchangeable.
   $c->stash->{username} = $c->session->{logged_in} ? $c->session->{name} : 'you';
   $c->session->{num}++;
   $c->stash->{num} = $c->session->{num};
   $c->stash->{rand_proverb} = \&Util::random_proverb;
}

1;
