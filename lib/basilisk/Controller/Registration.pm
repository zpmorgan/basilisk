package basilisk::Controller::Registration;

use strict;
use warnings;
use parent 'Catalyst::Controller::HTML::FormFu';

__PACKAGE__->config->{namespace} = '';

sub login :Global FormConfig{
   my ( $self, $c ) = @_;
   if ($c->session->{logged_in}){
      $c->stash->{message} = "You are already logged in, <b>".$c->session->{name} .
        '</b>.<br><a href="[%url_base%]/logout">Log out.</a>';
      $c->stash->{template} = 'message.tt';
      return;
   }
   my $form = $c->stash->{form};
   #die $form->render;
   unless ($form->submitted_and_valid){
      if ($form->submitted and $form->has_errors){
         #die $form->get_errors;
         #$c->stash->{msg} = "errors:<br>". join '<br>', map {%$_} @{$form->get_errors};
      }
      $c->detach;
   }
   #form valid..
   my $username = $c->req->param('username');
   my $passwd = $c->req->param('passwd');
   $passwd = Util::pass_hash $passwd;
   my $player = $c->model('DB::Player')->find ({name => $username});
   unless ($player){
      $c->stash->{msg} = "no such username $username";
      $c->detach; }
   unless ($player->pass eq $passwd){
      $c->stash->{msg} = 'wrong password';
      $c->detach; }
      
   $c->stash->{msg} = 'login successful';
   $c->session->{name} = $username;
   $c->session->{userid} = $player->id;
   $c->session->{logged_in} = 1;
   $c->detach ('status');
}

sub logout :Global {
   my ( $self, $c ) = @_;
   if ($c->session->{logged_in}){
      $c->stash->{message} = "You have logged out. Bye, ".$c->session->{name}.".";
   } else {
      $c->stash->{message} = "You needn't've done that. You weren't logged in."
   }
   $c->stash->{template} = 'message.tt';
   $c->delete_session('on logout');
}
sub register :Global FormConfig {
   my ( $self, $c ) = @_;
   if ($c->session->{logged_in}){
      $c->stash->{message} = "You are already logged in, <b>".$c->session->{name} .
        '</b>.<br><a href="[%url_base%]/logout">Log out.</a>';
      $c->stash->{template} = 'message.tt';
      $c->detach;
   }
   my $form = $c->stash->{form};
   unless ($form->submitted_and_valid){
      if ($form->submitted and $form->has_errors){
         #die $form->get_errors;
         #$c->stash->{msg} = "errors:<br>". join '<br>', map {%$_} @{$form->get_errors};
      }
      $c->detach;
   }
   my $req = $c->request;
   my $username = $req->param('username');
   my $passwd = $req->param('passwd');
   my $passwd2 = $req->param('passwd2');
   $passwd = Util::pass_hash $passwd;
   $passwd2= Util::pass_hash $passwd2;
   
   my $err = '';
   $err .= "Require letter in name.  " unless ($username =~ /[a-zA-Z]/);
   #my $rs = $c->model('DB::Player');
   $err .= "User $username exists already" if $c->model('DB::Player')->count (name=>$username);
   if ($err){
      $c->stash->{err} = $err;
      $c->detach;
   }
   my $player = $c->model('DB::Player')->create ({name=>$username, pass=>$passwd});
   die $@ unless $player;
   $c->session->{name} = $player->name;
   $c->session->{userid} = $player->id;
   $c->session->{logged_in} = 1;
   $c->stash->{msg} = "Registration successful!";
   $c->detach('status');
   #$c->stash->{template} = 'message.tt';
}
1;
