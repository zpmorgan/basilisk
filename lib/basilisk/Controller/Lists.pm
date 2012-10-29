package basilisk::Controller::Lists;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use XML::Atom::SimpleFeed;
__PACKAGE__->config->{namespace} = '';

use basilisk::Constants qw{ GAME_RUNNING GAME_FINISHED GAME_PAUSED };

#list of all registered players
sub players :Global{
   my ( $self, $c ) = @_;
   my $page = 0;
   my $pagesize = 100;
   my $players_rs;
   $c->model('DB')->schema->txn_do( sub{
      $players_rs = $c->model('DB::Player')->search({}, {rows=>$pagesize})->page($page);
   });
   my @players_info;
   for my $p ($players_rs->all){
      push @players_info, {
          name => $p->name,
          id => $p->id,
       };
   }
   $c->stash->{playerinfo} = \@players_info;
   $c->stash->{logged_in} = $c->session->{logged_in};
   $c->stash->{username} = $c->session->{username};
   $c->stash->{template} = 'players.tt';
}

my %game_cats = ( #this contains game search constraints
   all => {},
   running => {status => GAME_RUNNING},
   finished => {status => GAME_FINISHED},
);

#todo: prefetch?
sub games : Global{
   my ($self, $c, $playername, $cat) = @_;
   
   #I'm assuming that nobody calls themself 'finished' or 'running'
   if ($playername and $game_cats{$playername}){
      $cat = $playername;
      $playername = undef;
   }
   else {
      $cat = 'all' unless $game_cats{$cat};
   }
   my $gamesearch_constraints = $game_cats{$cat};
   
   $c->stash->{cat} = $cat;
   $c->stash->{playername} = $playername;
   $c->stash->{title} = 'All games';
   $c->stash->{title} .= " of $playername" if $playername;
   
   my $page = 0;
   my $pagesize = 300;
   my ($num_games, $num_pages);
   my %gameplayers; #to show who plays which game
   my %rulestrings; #to summarize game rulesets
   my $games_rs;
   #transaction!
   $c->model('DB')->schema->txn_do( sub{
      my $gid_col; #used to resolve resultset col naming issue
      if ($playername){#only look at this player's games
         my $p = $c->model('DB::Player')->find ({name=>$playername});
         return 'nosuchplayer' unless $p;
         my $relevant_p2g = $p->search_related('player_to_game', {});
         $games_rs = $relevant_p2g->search_related('game',
              $gamesearch_constraints, 
              {
                 rows => $pagesize,
              }
         )->page($page);
         $gid_col = 'game.id'; 
      }
      else{
         $games_rs = $c->model('DB::Game')->search(
              $gamesearch_constraints, 
              {rows=>$pagesize,
               }
         )->page($page);
         $gid_col = 'me.id';
      }
      my $p2g_rs = $games_rs->search_related ('player_to_game', {}, #all related
         {
            join => ['player'],
            select => ['player.name', $gid_col, 
               'player_to_game.pid', 
               'player_to_game.entity', 'me.status'],
            as => ['pname', 'gid', 'pid', 'side', 'status'],
         });
      $num_games = $games_rs->count();
      for my $p2g ($p2g_rs->all()){ #who plays what game
         my %data = $p2g->get_columns;
         $gameplayers{$data{gid}}->[$data{side}] = \%data; #note: 'side' is 1 or 2
      }
      #now get ruleset summary
      my $rulesets_rs = $games_rs->search ( {}, 
         {
            join => 'ruleset',
            select => [$gid_col, 'ruleset.rules_description', 'ruleset.phase_description'],
            as => ['gid', 'rulestring', 'phase_d'],
         });
      for my $row($rulesets_rs->all()){
         $rulestrings{$row->get_column('gid')} = $row->get_column('rulestring');
      }
   });#end transaction
   
   $c->stash->{num_pages} = int ($num_games / $pagesize) + 1;
   $c->stash->{num_games} = $num_games;
   
   my @games_data; #this is what template uses
   my %seen; #unique games in @games_data
   for my $game($games_rs->all) {
      next if $seen{$game->id};
      $seen{$game->id} = 1;
      
      my $gid = $game->id;
      push @games_data, { #todo: make generic for 3+ players
         id => $gid,
         status => $game->status,
         bname => $gameplayers{$gid}->[0]->{pname},
         wname => $gameplayers{$gid}->[1]->{pname},
         bid => $gameplayers{$gid}->[0]->{pid},
         wid => $gameplayers{$gid}->[1]->{pid},
         rulestring => $rulestrings{$gid}, #$game->size,
      }
   }
   $c->stash->{games_data} = \@games_data;
   $c->stash->{template} = 'all_games.tt';
}

sub games_rss : Global{
   my ( $self, $c, $playername) = @_;
   my $player = $c->model('DB::Player')->find({name => $playername});
   my @games = $player->games_to_move;
   
   my $feed = XML::Atom::SimpleFeed->new( #TODO: make this a View?
      title   => $player->name . "'s Basilisk",
      link    => $c->uri_for(""),
    #  link    => { rel => 'self', href => 'http://example.org/atom', },
    #  updated => '2003-12-13T18:30:02Z',
      author  => 'basilisk',
      id      => 'urn:uuid:d090fc40-0f95-11de-b50f-0002a5d5c51b',
   );
   
   #my %seen_games;
   for my $game (@games){
      my $gid = $game->{id};
      my $moves = $game->{number_moves};
      my $title = "$gid: ";
      if ($game->{only_self}){
         $title .= $playername . '!'
      } else {
         $title .= join ', ', grep {$_ ne $playername} map {$_->{name}} values %{$game->{players}};
      }
      $feed->add_entry(
         title     => $title,
         link      => $c->uri_for("game/$gid"),
         id        => "basilisk game $gid move $moves",
      );
   }
   
   $c->response->content_type ('text/xml');
   $c->response->body ($feed->as_string);
}

#show list of games where it's the player's turn
sub status :Global{
   my ( $self, $c ) = @_;
   $c->detach('login') unless $c->session->{logged_in};
   my $player = $c->model('DB::Player')->find({name => $c->session->{name}});
   
   my @games = $player->games_to_move;
   $c->stash->{waiting_games} = \@games;
   $c->stash->{'template'} = 'status.tt';
}

sub userinfo :Global{
   my ( $self, $c ) = @_;
   #$user could be a player's id or name
   # names of only numbers are  forbidden
   my ($user) = $c->req->path =~ m|userinfo/(\w*)|;
   unless ($user){
      $user = $c->session->{logged_in} ? $c->session->{name} : 'guest';
   }
   
   my $row;
   my ($id, $name);
   if ($user =~ /^\d*$/){ #only digits from url path
      $row = $c->model('DB::Player')->find({id => $user});
      $id = $user;
      $name = $row->name;
   }
   else{
      $row = $c->model('DB::Player')->find({name => $user});
      $id = $row->id;
      $name = $user;
   }
   
   my %userinfo = (
      id => $id,
      name => $name,
   );
   
   $c->stash->{userinfo} = \%userinfo;
   $c->stash->{template} = 'userinfo.tt';
}

1;

