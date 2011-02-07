use practical;
use Data::Dumper;
use AnyEvent;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;

our @Q;

local $| = 1;
my $OAuth  = do 'oauth.pl' or die $!;
my $twitty = AnyEvent::Twitter->new(%$OAuth);

while (1) {
    my $done = AE::cv;

    warn Dumper [&now, 'start connecting'];
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request  => "/feed/cpan",
        on_entry => \&on_entry,
        on_error => sub {
            warn Dumper [&now, \@_];
            $done->send;
        },
    );

    my $qwatcher; $qwatcher = AE::timer 5, 300, sub {
        my @q = @Q;
        while (my $string = shift @Q) {
            print Dumper [$string];
            $twitty->post('statuses/update', {status => $string}, sub {
                if ($_[1]) {
                    print Dumper [&now, $_[1]->{text}];
                } else {
                    warn Dumper [&now, \@_];
                    push @q, $string; # on error, push it to queue
                }
            });
        }
        push @Q, @q;
    };

    warn Dumper [&now, 'recv'];
    $done->recv;
}

sub now { scalar localtime; }

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
                if ($_[1]) {
                    print Dumper [&now, $_[1]->{text}];
                } else {
                    warn Dumper [&now, \@_];
                    push @Q, $string; # on error, push it to queue
                }
            });

        } else {
            $twitty->post('statuses/update', {status => '@punytan error: parse url ' . time}, sub {
                warn Dumper [&now, 'error: parse url', $entry, [$package, $author, $url], [ time, $_[2] ]];
            });
        }

    } else {
        $twitty->post('statuses/update', {status => '@punytan error: parse body ' . time}, sub {
            warn Dumper [&now, 'error: parse body', $entry, [ time, $_[2] ]];
        });
    }
};

__END__

