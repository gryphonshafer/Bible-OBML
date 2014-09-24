#!/usr/bin/env perl
use Test::Most;

eval('use Test::CheckManifest 0.9');
plan( 'skip_all' => "Test::CheckManifest 0.9 required" ) if $@;
ok_manifest( { 'filter' => [
    qr/\.git/,
    qr/\.travis\.yml$/,
    qr/perl-travis-helper/,
    qr/cover_db/,
] } );
done_testing();
