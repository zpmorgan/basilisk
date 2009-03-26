package basilisk::Controller::Comments;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use JSON;
use HTML::Scrubber;

#__PACKAGE__->config->{namespace} = '';

sub comments : Global{
   my ( $self, $c, $gameid) = @_;
   #set content: some json list of comments?
   my $req = $c->request;
   my $new_comment = $req->param('new_comment_text');
   #assert that comment is okay.
   
   my $game = $c->model('DB::Game')->find ({'id' => $gameid}, {cache => 1});
   unless ($game){
      die 'invalid_request: no game with that id' }
   if ($new_comment){
      if (length($new_comment) > 300){   #fail nicely
         $c->response->content_type ('text/json');
         $c->response->body (to_json(['comment too long']));
         return;
      }
      $game->create_related ('comments', 
           {comment => $new_comment,
            sayeth  => $c->session->{userid},
            time    => time,
      });
   }
   my @comments;
   my $comments_rs = $game->search_related ('comments', {},
         {join => ['speaker'],
          select => ['comment', 'time', 'speaker.name'],
          as     => ['comment', 'time', 'pname'],
   });
   #sanitize and prepare comments movenumbers
   my $scrubber = HTML::Scrubber->new( allow => [ qw[ p b i u hr br ] ] );
   for my $row ($comments_rs->all){
      my $scrubbed_comment = $scrubber->scrub ($row->comment);
      $scrubbed_comment =~ s/([^\s]{13})/\1- /g; #break up long words
      push @comments, {
         commentator => $row->get_column('pname'),
         comment => $scrubbed_comment,
         movenum => int rand(8),
      };
   }
   #push @comments, {commentator => 'Dr. 8',     comment => 'b sucks',    movenum => 3};
   #push @comments, {commentator => 'Lixin Foo', comment => 'No u sucks', movenum => 4};
   $c->response->content_type ('text/json');
   $c->response->body (to_json(['success', \@comments]));
}

#TODO: something more elaborate, with kibitzing and privacy options
sub allowed_to_comment : Private{
   my ($self, $c) = @_;
   $c->stash->{whynot} = '';
   unless ($c->session->{logged_in}) {
      $c->stash->{whynot} = 'not logged in' ;
      return 0; }
   if ($c->session->{userid} == 1) {
      $c->stash->{whynot} = 'not registered';
      return 0; }
   return 1;
}

1
