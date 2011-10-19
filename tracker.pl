use practical;
use Data::Dumper;
use JSON;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;
use Config::PP;
our @Q;

local $| = 1;
my $OAuth  = config_get "cpan_new.twitter.com";
my $twitty = AnyEvent::Twitter->new(%$OAuth);

our ($CONN, $CLIENT);
my $w; $w = AE::timer 1, 10, sub {
    return if $CLIENT->{guard};

    warn Dumper [AE::now, 'start connecting'];
    $CLIENT = AnyEvent::FriendFeed::Realtime->new(
        request  => "/feed/cpan",
        on_entry => sub {
            if (my $error = on_entry(@_)) {
                $twitty->post('statuses/update', {
                    status => sprintf '@punytan error: %s (%s)', $error, time
                }, sub {
                    warn Dumper [ AE::now, [ @_ ] ];
                });
            }
        },
        on_error => sub {
            warn Dumper [AE::now, \@_];
            undef $CLIENT;
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

    my %params = parse_body($entry)
        or return 'ParseError';

    %params = construct_status(%params);

    if (length $params{string} < 140) {
        tweet($params{string});
        return;
    }

    my %query = (
        login   => 'cpannew',
        apiKey  => 'R_b593e932246cfbe5625ec2ebb16647fc',
        format  => 'json',
        longUrl => $params{metacpan},
    );

    AnyEvent::HTTP::http_get "http://api.bitly.com/v3/shorten", %query, sub {
        my $json   = JSON::decode_json(shift);
        my $string = sprintf "%s by %s - %s", $params{package}, $params{pauseid}, $json->{data}{url};
        tweet($string);
    };
}

sub parse_body {
    my $entry = shift;

    my ($package, $author, $url) = $entry->{body} =~ m{^(.+) by (.+) - <a rel="nofollow" href="([^"]+)}
        or return;

    my ($pauseid, $file) = $url =~ m{authors/id/[A-Z]/[A-Z]{2}/([A-Z]+)/(.+)\.tar\.gz}
        or return;

    my $id = lc $pauseid;

    if ($file =~ m{.*/(.*)$}) {
        $file = $1;
    }

    return (
        package => $package,
        author  => $author,
        url     => $url,
        pauseid => $pauseid,
        id      => $id,
        file    => $file,
    );
}

sub construct_status {
    my %params = @_;

    my $metacpan = sprintf 'http://metacpan.org/release/%s/%s/', $params{pauseid}, $params{file};
    my $string   = sprintf "%s by %s - %s", $params{package}, $params{pauseid}, $metacpan;

    return (
        %params,
        metacpan => $metacpan,
        string   => $string,
    );
}

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

