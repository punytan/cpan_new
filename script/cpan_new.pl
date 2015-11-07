use strict;
use warnings;
use constant MARKER_FILE => "$ENV{HOME}/.cpan_new_timestamp";
use XML::Simple;
use Time::Piece;
use Data::Dumper;
use JSON;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use Config::PP;
use AnyEvent::Log;
use EV;
use Getopt::Long;
$AnyEvent::Log::FILTER->level("info");
our @Q;

GetOptions('config-dir=s' => \$Config::PP::DIR)
    or die "Invalid arguments";

my $twitty = do {
    my $OAuth  = config_get "cpan_new.twitter.com";
    AnyEvent::Twitter->new(%$OAuth);
};

my $w; $w = AE::timer 1, 30, sub {
    AE::log info => 'start crawling';
    http_get "https://metacpan.org/feed/recent", sub {
        my ($data, $headers) = @_;
        unless ($data) {
            AE::log info => Dumper $headers;
            return;
        }

        my $xml = XMLin($data);
        for my $item (@{$xml->{item}}) {
            my $item_timestamp = Time::Piece->strptime($item->{'dc:date'}, '%Y-%m-%dT%H:%M:%SZ')->epoch;
            next if LATEST_TIMESTAMP() >= $item_timestamp;
            LATEST_TIMESTAMP($item_timestamp);
            my $title = sprintf "%-.80s...", $item->{title};
            tweet("$title by $item->{'dc:creator'} $item->{link}");
        }

    }
};

my $qwatcher; $qwatcher = AE::timer 5, 300, sub {
    my $string = shift @Q;
    tweet($string) if $string;
};

AE::log info => 'recv';
AE::cv->recv;

sub tweet {
    my $string = shift;
    $twitty->post('statuses/update', { status => $string }, sub {
        if ($_[1]) {
            AE::log info => "Send: $string; Receive: $_[1]->{text}";
        } else {
            AE::log warn => "Send: $string " . Dumper [@_];
            push @Q, $string; # on error, push it to queue
        }
    });
}

sub LATEST_TIMESTAMP {
    my $epoch = shift;
    if ($epoch) {
        return -e MARKER_FILE ? utime $epoch, $epoch, MARKER_FILE : do {
            open my $fh, ">", MARKER_FILE or die $!;
            utime $epoch, $epoch, MARKER_FILE
        }
    } else {
        return -e MARKER_FILE ? (stat MARKER_FILE)[9] : do {
            open my $fh, ">", MARKER_FILE or die $!;
            (stat MARKER_FILE)[9]
        }
    }
}

__END__

