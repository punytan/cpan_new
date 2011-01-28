use practical;
use Data::Dumper;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;

local $| = 1;
my $OAuth  = do 'oauth.pl' or die $!;
my $twitty = AnyEvent::Twitter->new(%$OAuth);

while (1) {
    my $done = AE::cv;

    warn Dumper [scalar localtime, 'start connecting'];
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request  => "/feed/cpan",
        on_entry => sub {
            my @args = @_;
            my $w; $w = AE::timer 5, 0, sub {
                on_entry(@args);
                undef $w;
            };
        },
        on_error => sub {
            warn Dumper [scalar localtime, \@_];
            $done->send;
        },
    );
    warn Dumper [scalar localtime, 'recv'];
    $done->recv;
}

sub on_entry {
    my $entry = shift;

    if ($entry->{body} =~ m{^(.+) by (.+) - <a rel="nofollow" href="([^"]+)}) {
        my ($package, $author, $url) = ($1, $2, $3);

        if ($url =~ m{authors/id/[A-Z]/[A-Z]{2}/([A-Z]+)/(.+)\.tar\.gz}) {
            my ($pauseid, $id, $file) = ($1, lc($1), $2);

            if ($file =~ m{.*/(.*)$}) {
                $file = $1;
            }

            my $string = "$package by $pauseid - http://frepan.org/~$id/$file/";

            $twitty->post('statuses/update', {status => $string}, sub {
                print Dumper [scalar localtime, $_[1] ? $_[1]->{text} : \@_];

                unless ($_[1]) { # retry
                    $twitty->post('statuses/update', {status => $string}, sub {
                    });
                }
            });

        } else {
            warn Dumper [scalar localtime, 'error: parse url', $entry, [$package, $author, $url]];
            $twitty->post('statuses/update', {status => '@punytan error: parse url ' . time}, sub {warn Dumper [time, $_[2]]});
        }

    } else {
        warn Dumper [scalar localtime, 'error: parse body', $entry];
        $twitty->post('statuses/update', {status => '@punytan error: parse body ' . time}, sub {warn Dumper [time, $_[2]]});
    }
};

__END__

