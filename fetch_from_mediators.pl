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
  my $favorites = $nt->favorites({screen_name => $mediator, count => 200});
  push(@$all_favorites, @$favorites);
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
    if (is_file_exists_recursive('.', $filename)) {
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
      if (is_file_exists_recursive('.', $filename)) {
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

sub is_file_exists_recursive {
  my ($dir, $targetfile) = @_;
  my @files = glob("$dir/*");
  my $ret = 0;

  for my $file (@files) {
    if (-d $file) {
      $ret += is_file_exists_recursive($file, $targetfile);
    } else {
      return 1 if $file =~ $targetfile;
    }
  }
  return $ret;
}