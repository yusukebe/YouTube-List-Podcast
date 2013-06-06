#!/usr/bin/env perl
use Mojolicious::Lite;
use URI;
use URI::QueryParam;
use LWP::UserAgent;
use JSON qw/decode_json/;
use WWW::YouTube::Download;

my $ua = LWP::UserAgent->new;
my $yd = WWW::YouTube::Download->new;

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

post '/list' => sub {
    my $self = shift;
    my $uri = URI->new($self->req->param('url'));
    my $list_id = $uri->query_param('list');
    return $self->redirect_to("/list/$list_id") if $list_id;
    return $self->redirect_to("/");
};

get "/list/:list_id" => sub {
    my $self = shift;
    my $uri = URI->new("http://gdata.youtube.com/feeds/api/playlists/" . $self->stash->{list_id});
    $uri->query_form( alt => 'json', v => '2' );
    my $res = $ua->get($uri);
    die $res->status_line if $res->is_error;
    my $data = decode_json($res->decoded_content);
    $self->stash->{title} = $data->{feed}{title}{'$t'};
    my $results = [];
    for my $entry (@{$data->{feed}{entry}}) {
        push @$results, {
            id => $entry->{'media$group'}{'yt$videoid'}{'$t'},
            title => $entry->{title}{'$t'},
            image_url => $entry->{'media$group'}{'media$thumbnail'}[1]{'url'},
            description => $entry->{'media$group'}{'media$description'}{'$t'},
        };
    }
    $self->stash->{entries} = $results;
    $self->res->headers->content_type('application/xml');
    $self->render('list', format => 'rss');
};

get "/video/:video_id\.mp4" => sub {
    my $self = shift;
    my $video_url = $yd->get_video_url($self->stash->{video_id}, fmt => 18);
    $self->redirect_to($video_url);
};

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
  <head><title>Podie</title></head>
  <style>
  <!--
  body { text-align:center; }
  input, button { font-size:x-large; margin-bottom: 1em; }
  form { margin: 40px 0; }
  -->
  </style>
  <body>
    <form action="/list" method="post">
      <input type="text" name="url" placeholder="YouTube Playlist URL" size="60"/><br/>
      <button type="submit">GET PodCast!</button>
    </form>
  </body>
</html>

@@ list.rss.ep
<rss version="2.0">
<channel>
<title><%= $title %></title>
<link><%= $self->req->url->base %>list/<%= $list_id %></link>
% for my $entry (@$entries) {
<item>
<title><%= $entry->{title} %></title>
<description><![CDATA[<%= $entry->{description} %>]]></description>
<link>http://www.youtube.com/watch?v=<%= $entry->{id} %></link>
<enclosure url="<%= $self->req->url->base %>/video/<%= $entry->{id} %>.mp4" type="video/mp4"/>
</item>
% }
</channel>
</rss>
