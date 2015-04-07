use inc::Module::Install;
name 'App-Twitter-CPAN';
all_from 'lib/App/Twitter/CPAN.pm';

requires 'EV';
requires 'AnyEvent';
requires 'AnyEvent::HTTP';
requires 'AnyEvent::Twitter';
requires 'Config::PP';
requires 'JSON';
requires 'XML::Simple';
requires 'Time::Piece';


tests 't/*.t';
author_tests 'xt';

install_script 'script/cpan_new.pl';

test_requires 'Test::More' => 0.98;
auto_set_repository;
auto_include;
WriteAll;
