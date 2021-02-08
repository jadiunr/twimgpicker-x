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

my $mediators = $settings->{mediators};
my $all_favorites = [];

for my $mediator (@$mediators) {
  my $max_id = -1;
  for my $iter (1..3) {
    my $favorites = $nt->favorites({screen_name => $mediator, count => 200, max_id => $max_id});
    push(@$all_favorites, @$favorites);
    $max_id = $favorites->[-1];
  }
}

my $sorted_favorites = 
  [sort {
    Time::Piece->strptime($a->{created_at}, '%a %b %d %T %z %Y')
    <=>
    Time::Piece->strptime($b->{created_at}, '%a %b %d %T %z %Y')
  } @$all_favorites];

for my $favorite (@$sorted_favorites) {
  my $media_array = $favorite->{extended_entities}{media};
  download($media_array) if $media_array;
}

sub download {
  my $media_array = shift;
  my $binary;

  if($media_array->[0]{video_info}) {
    my $video = $media_array->[0]{video_info}{variants};
    for (@$video) { $_->{bitrate} = 0 unless $_->{bitrate} }
    my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$video)[0]{url};
    $url =~ s/\?.+//;

    my $filename = basename($url);
    if (-f "all/$filename") {
      say "[@{[ localtime->datetime ]}]Already saved     : $filename";
      return;
    }

    $binary = $http->get($url);
    die "[@{[ localtime->datetime ]}]Cannot fetch video: $url"
      if grep {$_ eq $binary->code} (404, 500);
    save($filename, $binary);
  } else {
    for my $image (@$media_array) {
      my $url = $image->{media_url};

      my $filename = basename($url);
      if (-f "all/$filename") {
        say "[@{[ localtime->datetime ]}]Already saved     : $filename";
        return;
      }

      $binary = $http->get($url.':large');
      die "[@{[ localtime->datetime ]}]Cannot fetch image: $url"
        if grep {$_ eq $binary->code} (404, 500);
      save($filename, $binary);
    }
  }
}

sub save {
  my ($filename, $binary) = @_;

  open my $fh, ">", $filename
    or die "[@{[ localtime->datetime ]}]Cannot create file: ".$filename;
  say $fh $binary->content;
  close $fh;
  say "[@{[ localtime->datetime ]}]Image saved       : $filename";
}
