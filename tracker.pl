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
            $twitty->request(method => 'POST', api => 'statuses/update',
                params => {status => $string}, sub {
                    print Dumper [scalar localtime, $_[1] ? $_[1]->{text} : \@_];
                    unless ($_[0]) {
                        $twitty->request(method => 'POST', api => 'statuses/update',
                            params => {status => '@punytan error: post'}, sub {
                                print Dumper \@_})}});

        } else {
            print Dumper [scalar localtime, 'error: parse url', $entry, [$package, $author, $url]];
            $twitty->request(method => 'POST', api => 'statuses/update',
                params => {status => '@punytan error: parse url'}, sub {print Dumper \@_});
        }

    } else {
        print Dumper [scalar localtime, 'error: parse body', $entry];
        $twitty->request(method => 'POST', api => 'statuses/update',
            params => {status => '@punytan error: parse body'}, sub {print Dumper \@_});
    }
};

__END__

