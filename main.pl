use strict;
use warnings;
use utf8;
use feature 'say';

use Time::Piece;
use File::Basename 'basename';
use Net::Twitter::Lite::WithAPIv1_1;
use YAML::Tiny;
use Furl;
use Parallel::ForkManager;

my $settings = YAML::Tiny->read('./settings.yml')->[0];
my $pm = Parallel::ForkManager->new(8);
my $http = Furl->new();

# Autoflush
$|=1;

# Authentication
my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
  consumer_key        => $settings->{consumer_key},
  consumer_secret     => $settings->{consumer_secret},
  access_token        => $settings->{access_token},
  access_token_secret => $settings->{access_token_secret}
);

say 'Initialize now.';
# Initialize
my $old_tweet_ids = [];
my $tweets = $nt->user_timeline({screen_name => $settings->{target}, count => 60});
push(@$old_tweet_ids, $_->{id}) for @$tweets;

say 'Crawling begin.';
# Crawling routine
while (1) {
  $tweets = eval { $nt->user_timeline({screen_name => $settings->{target}, count => 60}) };
  if ($@) {
    warn "[@{[ localtime->datetime ]}]Warning           : $@";
    sleep(15);
    next;
  };
  for my $i (reverse 0..30) {
    unless (grep {$_ eq $tweets->[$i]{id}} @$old_tweet_ids) {
      my $media_array = $tweets->[$i]{extended_entities}{media};
      download($pm, $http, $settings, $media_array) if $media_array;
    }
  }
  my $latest_tweet_ids = [];
  push(@$latest_tweet_ids, $_->{id}) for @$tweets;
  $old_tweet_ids = $latest_tweet_ids;

  sleep(15);
}

sub download {
  my ($pm, $http, $settings, $media_array) = @_;
  my $binary;

  if($media_array->[0]{video_info}) {
    $pm->start and return;

    my $video = $media_array->[0]{video_info}{variants};
    for (@$video) { $_->{bitrate} = 0 unless $_->{bitrate} }
    my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$video)[0]{url};
    $url =~ s/\?.+//;
    $binary = $http->get($url);
    die "[@{[ localtime->datetime ]}]Cannot fetch video: $url"
      if grep {$_ eq $binary->code} (404, 500);
    open my $fh, ">", $settings->{outdir}.'/'.basename($url)
      or die "[@{[ localtime->datetime ]}]Cannot create file: ".basename($url);
    say $fh $binary->content;
    close $fh;
    say "[@{[ localtime->datetime ]}]Saved video       : $url";

    $pm->finish;
  } else {
    for my $image (@$media_array) {
      $pm->start and next;

      my $url = $image->{media_url};
      $binary = $http->get($url.':large');
      die "[@{[ localtime->datetime ]}]Cannot fetch image: $url"
        if grep {$_ eq $binary->code} (404, 500);
      open my $fh, ">", $settings->{outdir}.'/'.basename($url)
        or die "[@{[ localtime->datetime ]}]Cannot create file: ".basename($url);
      say $fh $binary->content;
      close $fh;
      say "[@{[ localtime->datetime ]}]Saved image       : $url";

      $pm->finish;
    }
  }
}