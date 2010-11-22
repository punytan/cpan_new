use common::sense;
use Data::Dumper;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;

$| = 1;
my $OAuth  = do 'oauth.pl' or die $!;
my $twitty = AnyEvent::Twitter->new(%$OAuth);

while (1) {
    my $done = AE::cv;

    print Dumper [scalar localtime, 'start connecting'];
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request    => "/feed/cpan",
        on_entry   => \&on_entry,
        on_error   => sub { print Dumper [scalar localtime, \@_]; $done->send; },
    );
    print Dumper [scalar localtime, 'recv'];
    $done->recv;
}

sub on_entry {
    my $entry = shift;

    if ($entry->{body} =~ m{^(.+) by (.+) - <a rel="nofollow" href="([^"]+)}) {
        my ($package, $author, $url) = ($1, $2, $3);

        if ($url =~ m{authors/id/[A-Z]/[A-Z]{2}/([A-Z]+)/(.+)\.tar\.gz}) {
            my $id   = lc $1;
            my $file = $2;

            my $string = "$package by $author - http://frepan.64p.org/~$id/$file/";
            my $w; $w = AE::timer 5, 0, sub {
                $twitty->post('statuses/update', {status => $string}, sub {
                    print Dumper [scalar localtime, $_[1] ? $_[1]->{text} : \@_];
                    $_[1] ? undef : $twitty->post('statuses/update', {
                        status => '@punytan error: post ' . time}, sub { print Dumper [time, $_[2]]});
                });
            };

        } else {
            print Dumper [scalar localtime, 'error: parse url', $entry, [$package, $author, $url]];
            $twitty->post('statuses/update', {status => '@punytan error: parse url ' . time}, sub {print Dumper \@_});
        }

    } else {
        print Dumper [scalar localtime, 'error: parse body', $entry];
        $twitty->post('statuses/update', {status => '@punytan error: parse body ' . time}, sub {print Dumper \@_});
    }
};

__END__

