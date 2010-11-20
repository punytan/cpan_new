use common::sense;
use Data::Dumper;
use AnyEvent::Twitter;
use AnyEvent::FriendFeed::Realtime;

$| = 1;

my $OAuth = do 'oauth.pl' or die $!;

my $twitty = AnyEvent::Twitter->new(%$OAuth);

my $on_entry = sub {
    my $entry = shift;

    if ($entry->{body} =~ m{^(.+) by (.+) - <a rel="nofollow" href="([^"]+)}) {
        my ($package, $author, $url) = ($1, $2, $3);

        if ($url =~ m{authors/id/[A-Z]/[A-Z]{2}/([A-Z]+)/(.+)\.tar\.gz}) {
            my ($id, $file) = ($1, $2);

            my $string = sprintf "%s by %s - http://frepan.64p.org/~%s/%s/", $package, $author, lc $id, $file;
            say $string;
            $twitty->request(method => 'POST', api => 'statuses/update',
                params => {status => $string}, sub {print Dumper \@_});

        } else {
            print Dumper ['error: parse url', $entry, [$package, $author, $url]];
            $twitty->request(method => 'POST', api => 'statuses/update',
                params => {status => '@punytan error: parse url'}, sub {print Dumper \@_});
        }

    } else {
        print Dumper ['error: parse body', $entry];
        $twitty->request(method => 'POST', api => 'statuses/update',
            params => {status => '@punytan error: parse body'}, sub {print Dumper \@_});
    }
};

=testign stuff
my @list = (
    {body => 'Test-Magpie 0.05 by Oliver Charles - <a rel="nofollow" href="http://cpan.cpantesters.org/authors/id/C/CY/CYCLES/Test-Magpie-0.05.tar.gz" title="http://cpan.cpantesters.org/authors/id/C/CY/CYCLES/Test-Magpie-0.05.tar.gz">http://cpan.cpantesters.org/authors...</a>'},
    {body => 'Encode-Locale 0.03 by Gisle Aas - <a rel="nofollow" href="http://cpan.cpantesters.org/authors/id/G/GA/GAAS/Encode-Locale-0.03.tar.gz" title="http://cpan.cpantesters.org/authors/id/G/GA/GAAS/Encode-Locale-0.03.tar.gz">http://cpan.cpantesters.org/authors...</a>'},
    {body => 'Encode-Locale <a rel="nofollow" href="htt</a>'},
    {body => 'Encode-Locale 0.03 by Gisle Aas - <a rel="nofollow" href="http://cpan.cpantesters.org/authors/id/G/GA/GAAS/Encode-Locale-0.03.tar"'},
);

for (@list) {
    $on_entry->($_);
}
=cut

while (1) {
    my $done = AnyEvent->condvar; 

    say 'start connecting';
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request    => "/feed/cpan",
        on_entry   => $on_entry,
        on_error   => sub { print Dumper \@_; $done->send; },
    );

    say 'recv';
    $done->recv;
}



