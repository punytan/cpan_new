use strict;
use warnings;
use Data::Dumper;
use JSON;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;
use Config::PP;
use AnyEvent::Log;
use EV;
use Getopt::Long;
$AnyEvent::Log::FILTER->level("info");
our @Q;

GetOptions('config-dir=s' => \$Config::PP::DIR)
    or die "Invalid arguments";

my $OAuth  = config_get "cpan_new.twitter.com";
my $twitty = AnyEvent::Twitter->new(%$OAuth);

our $CLIENT;
my $w; $w = AE::timer 1, 10, sub {
    return if $CLIENT->{guard};

    AE::log info => 'start connecting';
    $CLIENT = AnyEvent::FriendFeed::Realtime->new(
        request  => "/feed/cpan",
        on_entry => sub {
            if (my $error = on_entry(@_)) {
                $twitty->post('statuses/update', { status => sprintf '@punytan error: %s (%s)', $error, time }, sub {
                    AE::log info => Dumper [ @_ ];
                });
            }
        },
        on_error => sub {
            AE::log info => Dumper [@_];
            undef $CLIENT;
        },
    );
};

my $qwatcher; $qwatcher = AE::timer 5, 300, sub {
    my $string = shift @Q;
    tweet($string) if $string;
};

AE::log info => 'recv';

AE::cv->recv;

sub on_entry {
    my $entry = shift;

    my %params = parse_body($entry)
        or return 'ParseError';

    my $string = construct_status(%params)->{string};

    tweet($string);

    return;
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

    return {
        %params,
        metacpan => $metacpan,
        string   => $string,
    };
}

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

__END__

