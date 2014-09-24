# Bible::OBML - Open Bible Markup Language parser and renderer

This module provides methods that support parsing and rendering Open Bible
Markup Language (OBML). OBML is a pure-ASCII-text markup way to represent Bible
content, one whole text file per chapter. The goal or purpose of OBML is similar
to Markdown in that it provides a human-readable text file allowing for simple
and direct editing of content while maintaining context, footnotes,
cross-references, "red text", and quotes.

[![Build Status](https://travis-ci.org/gryphonshafer/Bible-OBML.svg)](https://travis-ci.org/gryphonshafer/Bible-OBML)
[![Coverage Status](https://coveralls.io/repos/gryphonshafer/Bible-OBML/badge.png)](https://coveralls.io/r/gryphonshafer/Bible-OBML)

## Description

### Open Bible Markup Language (OBML)

OBML makes the assumption that content will exist in one text file per chapter,
the text file will be ASCII, and content mark-up will conform to the
following specification:

    ~...~    --> material reference
    =...=    --> header
    {...}    --> crossreferences
    [...]    --> footnotes
    <...>    --> red text
    ^...^    --> italic
    4 spaces --> blockquote (line by line)
    6 spaces --> blockquote + indent (line by line)
    |*|      --> notes the beginning of a verse (numbers ignored)
    #        --> line comments

An example of OBML follows, with several verses missing so as to save space:

    ~ Jude 1 ~

    |1| Jude, [or ^Judas^] {Mt 13:55; Mk 6:3; Jhn 14:22; Ac 1:13} a
    slave [or ^servant^] {Ti 1:1} of Jesus Christ, and
    brother of James, [or ^Jacob^] to those having been set apart [or
    ^loved^ or ^sanctified^] in God ^the^ Father.

    = The Sin and Punishment of the Ungodly =

    |14| Enoch, {Ge 5:18; Ge 5:21-24} ^the^ seventh from Adam, also
    prophesied to these saying:

        Behold, ^the^ Lord came with myriads of His saints [or ^holy
        ones^] {De 33:2; Da 7:10; Mt 16:27; He 12:22}
        |15| to do judgment against all {2Pt 2:6-9}.

    |16| These are murmurers, complainers, {Nu 16:11; Nu 16:41; 1Co
    10:10} following ^after^ [or ^according to^] their
    lusts, {Jdg 1:18; 2Pt 2:10} and their mouths speak of proud things
    {2Pt 2:18} ^showing admiration^ [literally ^admiring faces^] to gain
    ^an advantage^. [literally ^for the sake of you^] {2Pt 2:3}

When the OBML is parsed, it's turned into a uniform data structure. The data
structure is an arrayref containing a hashref per verse. The hashrefs will have
a "reference" key and a "content" key and an optional "header" key. Given OBML
for Jude 1:14 as defined above, this is the data structure of the hashref for
the verse:

    'reference' => { 'verse' => '14', 'chapter' => '1', 'book' => 'Jude' },
    'header'    => [ 'The Sin and Punishment of the Ungodly' ],
    'content'   => [
        'Enoch,',
        [ 'crossreference', [ 'Ge 5:18', 'Ge 5:21-24' ] ],
        [ 'italic', 'the' ],
        'seventh from Adam, also prophesied to these saying:',
        [ 'paragraph' ],
        [
            'blockquote',
            'Behold,',
            [ 'italic', 'the' ],
            'Lord came with myriads of His saints',
            [ 'footnote', 'or', [ 'italic', 'holy ones' ] ],
            [
                'crossreference',
                [ 'De 33:2', 'Da 7:10', 'Mt 16:27', 'He 12:22' ],
            ],
        ],
    ],

Note that even in the simplest of cases, both "header" and "content" will be
arrayrefs around some number of strings. The "reference" key will always be
a hashref with 3 keys. The structure of the values inside the arrayrefs of
"header" and "content" can be (and usually are) nested.

## Installation

To install this module, run the following commands:

    perl Makefile.PL
    make
    make test
    make install

## Support and Documentation

After installing, you can find documentation for this module with the
perldoc command.

    perldoc Bible::OBML

You can also look for information at:

- [GitHub](https://github.com/gryphonshafer/Bible-OBML "GitHub")
- [AnnoCPAN](http://annocpan.org/dist/Bible-OBML "AnnoCPAN")
- [CPAN Ratings](http://cpanratings.perl.org/m/Bible-OBML "CPAN Ratings")
- [Search CPAN](http://search.cpan.org/dist/Bible-OBML "Search CPAN")

## Author and License

Gryphon Shafer, [gryphon@cpan.org](mailto:gryphon@cpan.org "Email Gryphon Shafer")

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
