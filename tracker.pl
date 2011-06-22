use practical;
use Data::Dumper;
use JSON;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;
our @Q;

local $| = 1;
my $OAuth  = do 'oauth.pl' or die $!;
my $twitty = AnyEvent::Twitter->new(%$OAuth);

our ($CONN, $CLIENT);
my $w; $w = AE::timer 1, 10, sub {
    return if $CLIENT->{guard};

    warn Dumper [AE::now, 'start connecting'];
    $CLIENT = AnyEvent::FriendFeed::Realtime->new(
        request  => "/feed/cpan",
        on_entry => sub {
            on_entry(@_);
        },
        on_error => sub {
            warn Dumper [AE::now, \@_];
        },
    );
};

my $qwatcher; $qwatcher = AE::timer 5, 300, sub {
    my $string = shift @Q;
    tweet($string) if $string;
};

warn Dumper [AE::now, 'recv'];

AE::cv->recv;

sub on_entry {
    my $entry = shift;

    if ($entry->{body} =~ m{^(.+) by (.+) - <a rel="nofollow" href="([^"]+)}) {
        my ($package, $author, $url) = ($1, $2, $3);

        if ($url =~ m{authors/id/[A-Z]/[A-Z]{2}/([A-Z]+)/(.+)\.tar\.gz}) {
            my ($pauseid, $id, $file) = ($1, lc($1), $2);

            if ($file =~ m{.*/(.*)$}) {
                $file = $1;
            }

            my $metacpan = sprintf 'http://metacpan.org/release/%s/%s/', uc($id), $file;
            my $string   = sprintf "%s by %s - %s", $package, $pauseid, $metacpan;

            if (length $string > 140) {
                my %params = (
                    login   => 'cpannew',
                    apiKey  => 'R_b593e932246cfbe5625ec2ebb16647fc',
                    format  => 'json',
                    longUrl => $metacpan,
                );

                AnyEvent::HTTP::http_get "http://api.bitly.com/v3/shorten", %params, sub {
                    my $json   = JSON::decode_json(shift);
                    my $string = sprintf "%s by %s - %s", $package, $pauseid, $json->{data}{url};
                    tweet($string);
                };

            } else {
                tweet($string);
            }

        } else {
            $twitty->post('statuses/update', {
                status => '@punytan error: parse url ' . time
            }, sub {
                warn Dumper [AE::now, 'error: parse url', $entry, [$package, $author, $url], [ time, $_[2] ]];
            });
        }

    } else {
        $twitty->post('statuses/update', {
            status => '@punytan error: parse body ' . time
        }, sub {
            warn Dumper [AE::now, 'error: parse body', $entry, [ time, $_[2] ]];
        });
    }
};

sub tweet {
    my $string = shift;
    $twitty->post('statuses/update', {
        status => $string
    }, sub {
        if ($_[1]) {
            print Dumper [AE::now, "Send: $string", "Receive: $_[1]->{text}"];
        } else {
            warn Dumper [AE::now, "Send: $string", \@_];
            push @Q, $string; # on error, push it to queue
        }
    });
}

__END__

