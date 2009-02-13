package basilisk::Controller::Registration;

use strict;
use warnings;
use parent 'Catalyst::Controller';


__PACKAGE__->config->{namespace} = '';

sub login :Global{
   my ( $self, $c ) = @_;
   if ($c->session->{logged_in}){
      $c->stash->{message} = "You are already logged in, ".$c->session->{name} .
        '.<br><a href="/logout">Log out.';
      $c->stash->{template} = 'message.tt';
      return;
   }
   $c->stash->{'template'} = 'login.tt';
   my $req = $c->request;
   if ($req->param('username')){
      #login attempt
      my $err;
      my $username = $req->param('username');
      my $passwd = $req->param('passwd');
      my $rs = $c->model('DB::Player');
      unless ($rs->count(name => $username)){
         $c->stash->{message} = 'no such username';
         $c->stash->{template} = 'message.tt';
         return;
      }
      unless ($rs->search(name => $username)->next->pass eq $passwd){
         $c->stash->{message} = 'wrong password';
         $c->stash->{template} = 'message.tt';
         return;
      }
      $c->stash->{message} = 'login successful';
      $c->stash->{template} = 'message.tt';
      $c->session->{name} = $username;
      $c->session->{logged_in} = 1;
      return;
   }
   
   else {
      #just display login form
      $c->stash->{'template'} = 'login.tt';
   }
   return;
}

sub logout :Global {
   my ( $self, $c ) = @_;
   $c->stash->{message} = "You have logged out. Bye, ".$c->session->{name}.".";
   $c->stash->{template} = 'message.tt';
   $c->delete_session('on logout');
}
sub register :Global {
   my ( $self, $c ) = @_;
   my $req = $c->request;
   my $username = $req->param('username');
   my $passwd = $req->param('passwd');
   my $passwd2 = $req->param('passwd2');
   unless ($username){ #just display form unless cgi args are here
      $c->stash->{template} = 'register.tt';
      return;
   }
   my $err = ''; #join ' ', keys %{$c->session};
   $err .= 'You\'re already logged in.  ' if $c->session->{logged_in};
   $err .= "Require username.  " unless ($username);
   $err .= "Require password.  " unless ($passwd);
   $err .= "Passwords must match.  " unless ($passwd eq $passwd2);
   
   #my $rs = $c->model('DB::Player');
   if ($username){
      $err .= "User $username exists already" if $c->model('DB::Player')->count (name=>$username);
   }
   if ($err){
      $c->stash->{err} = $err;
      $c->stash->{template} = 'register.tt';
   }
   else {
      $c->model('DB::Player')->create ({name=>$username, pass=>$passwd});
      $c->stash->{message} = "Registration successful! You have 15 $passwd points!";
      $c->stash->{template} = 'message.tt';
      $c->session->{name} = $username;
      $c->session->{logged_in} = 1;
   }
}
1;
