use strict;
use warnings;
use utf8;
use feature 'say';

use Time::Piece;
use File::Basename 'basename';
use File::Path 'mkpath';
use Net::Twitter::Lite::WithAPIv1_1;
use YAML::Tiny;
use Furl;

use Pry;

my $settings = YAML::Tiny->read('./settings.yml')->[0];
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

# cd
if (!-d $settings->{outdir}) { mkdir $settings->{outdir} or die; }
chdir $settings->{outdir} or die;

say 'Initialize now.';
# Initialize
my $tweets = $nt->user_timeline({screen_name => $settings->{target}, count => 60});
my $since_id = $tweets->[0]{id};

say 'Crawling begin.';
# Crawling routine
while (1) {
  $tweets = eval { $nt->user_timeline({screen_name => $settings->{target}, count => 120, since_id => $since_id}) };
  if ($@) {
    warn "[@{[ localtime->datetime ]}]Warning           : $@";
    sleep(30);
    next;
  }
  if (@$tweets) {
    for my $tweet (reverse @$tweets) {
      my $media_array = $tweet->{extended_entities}{media};
      download($media_array) if $media_array;
    }
    $since_id = $tweets->[0]{id};
  }
  sleep 15;
}

sub download {
  my $media_array = shift;
  my $binary;

  if($media_array->[0]{video_info}) {
    my $video = $media_array->[0]{video_info}{variants};
    for (@$video) { $_->{bitrate} = 0 unless $_->{bitrate} }
    my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$video)[0]{url};
    $url =~ s/\?.+//;
    $binary = $http->get($url);
    die "[@{[ localtime->datetime ]}]Cannot fetch video: $url"
      if grep {$_ eq $binary->code} (404, 500);
    save($url, $binary);
  } else {
    for my $image (@$media_array) {
      my $url = $image->{media_url};
      $binary = $http->get($url.':large');
      die "[@{[ localtime->datetime ]}]Cannot fetch image: $url"
        if grep {$_ eq $binary->code} (404, 500);
      save($url, $binary);
    }
  }
}

sub save {
  my ($url, $binary) = @_;
  my $filename = basename($url);
  my $year = localtime->strftime('%Y');
  my $month = localtime->strftime('%m');
  my $destpath = "./${year}/${month}";

  if (!-d $destpath) { mkpath $destpath or die; }

  open my $fh, ">", $destpath.'/'.$filename
    or die "[@{[ localtime->datetime ]}]Cannot create file: ".$url;
  say $fh $binary->content;
  close $fh;
  say "[@{[ localtime->datetime ]}]Saved image       : $url";
}
