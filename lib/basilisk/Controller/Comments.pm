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
      $c->detach('fail_comment_nicely', ['invalid_request: no game with that id']);
   }
   $c->stash->{game} = $game;
   
   if ($new_comment){
      unless ($c->forward('allowed_to_comment')){  #fail nicely
         $c->detach('fail_comment_nicely', [$c->stash->{whynot}]);
      }
      if (length($new_comment) > 300){   #fail nicely
         $c->detach('fail_comment_nicely', ['comment too long']);
      }
      
      #see if user hit submit twice accidentally
      my $previous_comment = $game->find_related('comments', {}, {order_by => 'id DESC'});
      if ($previous_comment and $previous_comment->comment eq $new_comment){
         if ($previous_comment->sayeth == $c->session->{userid}){
            $c->detach('fail_comment_nicely', ['same as prev. comment']);
         }
      }
      
      $game->create_related ('comments', {
            comment => $new_comment,
            sayeth  => $c->session->{userid},
            time    => time,
      });
   }
   my $comments = $c->forward('all_comments');
   
   $c->response->content_type ('text/json');
   $c->response->body (to_json(['success', $comments]));
}

#call this from /game as well
sub all_comments :  Private{
   my ($self, $c) = @_;
   my $game = $c->stash->{game};
   my @comments;
   my $comments_rs = $game->search_related ('comments', {},
         {join => ['speaker'],
          select => ['comment', 'time', 'speaker.name'],
          as     => ['comment', 'time', 'pname'],
          order_by=>'time ASC',
   });
   my @moves = $game->search_related ('moves', {},
      { select => ['movenum', 'time'],
        order_by => 'time ASC',
      });
   
   #sanitize and prepare comments with movenums
   my $scrubber = HTML::Scrubber->new( allow => [ qw[ p b i u hr br ] ] );
   my $movenum = 0;
   for my $row ($comments_rs->all){
      my $scrubbed_comment = $scrubber->scrub ($row->comment);
      $scrubbed_comment =~ s/(\w{13})(\w{2})/$1 $2/g; #break up long words
      
      #moves[i-1] has movenum i
      while ($moves[$movenum]  and  $row->time > $moves[$movenum]->time){
         $movenum++
      }
      push @comments, {
         commentator => $row->get_column('pname'),
         comment => $scrubbed_comment,
         movenum => $movenum,
      };
   }
   return \@comments;
}

#TODO: something more elaborate, with kibitzing and privacy options
sub allowed_to_comment : Private{
   my ($self, $c) = @_;
   $c->stash->{whynot} = '';
   unless ($c->session->{logged_in}) {
      $c->stash->{whynot} = 'not logged in' ;
      return 0; }
   return 1;
}

sub fail_comment_nicely : Private{
   my ($self, $c, $err) = @_;
   $c->response->content_type ('text/json');
   $c->response->body (to_json([$err]));
   return;
   
}

1
