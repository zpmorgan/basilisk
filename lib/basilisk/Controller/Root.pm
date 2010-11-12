package basilisk::Controller::Root;
use strict;
use warnings;
use parent 'Catalyst::Controller';

use basilisk::Constants qw{IMG_BASE URL_BASE STATIC_BASE MESSAGE_NOT_SEEN};
use basilisk::Util qw{random_proverb};


__PACKAGE__->config->{namespace} = '';


sub index :Path Args(0) {
   my ( $self, $c ) = @_;
   $c->stash->{template} = 'index.tt';
}

sub indexBLAH :Global Args(0) FormConfig('login'){
   my ( $self, $c ) = @_;
   
   # Hello World
   if ($c->session->{logged_in}){
      $c->stash->{message} = 'Hello, ' . $c->session->{name};
      $c->stash->{template} = 'message.tt';
   }
   else{
      $c->forward('basilisk::Controller::Registration', 'login');
   }
}



# 404
sub default :Path {
   my ( $self, $c ) = @_;
   my $req = $c->request;
   my @info; # = '<div align="left">';
   push @info, "base: " . $req->base;
   push @info, "path: " . $req->path;
   push @info, "params: ";
   for my $key (keys %{$req->parameters}){
      push @info, " * $key: ". $req->param($key);
   }
   push @info, "referer: ".$req->referer if $req->referer;
   push @info, "secure: ".$req->secure;
   push @info, "session data: ";
   for my $key (keys %{$c->session}){
      push @info, " * $key: ". $c->session->{$key};
   }
   #push @info, "</div>";
   $c->stash->{body} = join "<br>",@info;
   $c->stash->{template} = '404.tt';
#   $c->response->body( join "<br>",@info);
   $c->response->status(404);
}

# end -- Attempt to render a view.
#this is a RenderView action, so this is called right before we're sent to the view
sub end : ActionClass('RenderView') {
   my ( $self, $c ) = @_;
   #set some tt vars for header
   my $url_base = $c->stash->{url_base} = URL_BASE;
   my $img_base = $c->stash->{img_base} = IMG_BASE;
   my $static_base = $c->stash->{static_base} = STATIC_BASE;
   
   if ($c->stash->{message}){ #TT can't do this at runtime?
      $c->stash->{message} =~ s/\[\%\s?url_base\s?\%\]/$url_base/;
      $c->stash->{message} =~ s/\[\%\s?img_base\s?\%\]/$img_base/;
   }
   if ($c->stash->{msg}){ #TT can't do this at runtime?
      $c->stash->{msg} =~ s/\[\%\s?url_base\s?\%\]/$url_base/;
      $c->stash->{msg} =~ s/\[\%\s?img_base\s?\%\]/$img_base/;
   }
   $c->stash->{logged_in} = $c->session->{logged_in} ? 1 : 0;
   $c->stash->{userid} = $c->session->{userid};
   #$c->stash->{name} seems to be basilisk, and unchangeable.
   $c->stash->{username} = $c->session->{logged_in} ? $c->session->{name} : 'you';
   $c->session->{num}++;
   $c->stash->{num} = $c->session->{num};
   $c->stash->{rand_proverb} = random_proverb();
   $c->stash->{unseen_count} = $c->model('DB::Message')->count ({
      heareth =>$c->session->{userid},
      status => MESSAGE_NOT_SEEN(),
   });
}

sub message :Global Args(1) { #not mail msg. err msg.
   my ( $self, $c, $msg ) = @_;
   $c->stash->{message} = $msg;
   $c->stash->{template} = 'message.tt';
}

sub about :Global{
   my ( $self, $c ) = @_;
   #basically display a static page
}

1;
