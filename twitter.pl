use strict;
use warnings;
use utf8;
use Net::Twitter::Lite::WithAPIv1_1;
use YAML::Tiny;

my $key = YAML::Tiny->read('./secrets.yml')->[0];

my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
  consumer_key        => $key->{'consumer_key'},
  consumer_secret     => $key->{'consumer_secret'},
  access_token        => $key->{'access_token'},
  access_token_secret => $key->{'access_token_secret'}
);

$nt->user_timeline({screen_name => 'jadiunr'});