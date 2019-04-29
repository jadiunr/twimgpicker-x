use strict;
use warnings;
use utf8;
use feature 'say';

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
    warn "WARNING: $@";
    next;
  };
  for my $i (reverse 0..30) {
    unless (grep {$_ eq $tweets->[$i]{id}} @$old_tweet_ids) {
      my $media_array = $tweets->[$i]{extended_entities}{media};
      if ($media_array) {
        for (@$media_array) {
          $pm->start and next;
          download($pm, $http, $settings, $_);
          $pm->finish;
        }
      }
    }
  }
  my $latest_tweet_ids = [];
  push(@$latest_tweet_ids, $_->{id}) for @$tweets;
  $old_tweet_ids = $latest_tweet_ids;

  sleep(15);
}

sub download {
  my ($pm, $http, $settings, $media) = @_;

  my $image = $http->get($media->{media_url}.':large');
  die 'Cannot fetch image: '.$media->{media_url}
    if grep {$_ eq $image->code} (404, 500);
  open my $fh, ">", $settings->{outdir}.'/'.basename($media->{media_url})
    or die 'Cannot create file: '.basename($media->{media_url});
  say $fh $image->content;
  close $fh;
  say 'Saved image: '.$media->{media_url};
}