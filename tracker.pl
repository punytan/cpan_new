use common::sense;
use Data::Dumper;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;

local $| = 1;
my $OAuth  = do 'oauth.pl' or die $!;
my $twitty = AnyEvent::Twitter->new(%$OAuth);

while (1) {
    my $done = AE::cv;

    print Dumper [scalar localtime, 'start connecting'];
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request    => "/feed/cpan",
        on_entry   => sub {
            my @args = @_;
            my $w; $w = AE::timer 5, 0, sub { on_entry(@args); undef $w; }
        },
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

            if ($file =~ m{.*/(.*)$}) {
                $file = $1;
            }

            my $string = "$package by $author - http://frepan.org/~$id/$file/";

            $twitty->post('statuses/update', {status => $string}, sub {
                print Dumper [scalar localtime, $_[1] ? $_[1]->{text} : \@_];

                unless ($_[1]) { # retry
                    $twitty->post('statuses/update', {status => $string}, sub {
=pod
                        unless ($_[1]) { # on error
                            my $error_msg = sprintf '@punytan error: "%s" post %s', $_[2], time;
                            $twitty->post('statuses/update', {status => $error_msg}, sub {
                                print Dumper [time, $_[2]];
                            })
                        }
=cut
                    });
                }
            });

        } else {
            print Dumper [scalar localtime, 'error: parse url', $entry, [$package, $author, $url]];
            $twitty->post('statuses/update', {status => '@punytan error: parse url ' . time}, sub {print Dumper [time, $_[2]]});
        }

    } else {
        print Dumper [scalar localtime, 'error: parse body', $entry];
        $twitty->post('statuses/update', {status => '@punytan error: parse body ' . time}, sub {print Dumper [time, $_[2]]});
    }
};

__END__

