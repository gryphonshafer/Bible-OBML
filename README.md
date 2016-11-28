# NAME

Bible::OBML - Open Bible Markup Language parser and renderer

# VERSION

version 1.07

[![Build Status](https://travis-ci.org/gryphonshafer/Bible-OBML.svg)](https://travis-ci.org/gryphonshafer/Bible-OBML)
[![Coverage Status](https://coveralls.io/repos/gryphonshafer/Bible-OBML/badge.png)](https://coveralls.io/r/gryphonshafer/Bible-OBML)

# SYNOPSIS

    use Bible::OBML;
    my $self = Bible::OBML->new;

    my $data_structure    = $self->parse($obml_text_content);
    my $obml_text_content = $self->render( $data_structure, $skip_wrapping );

    my $content_with_smart_quotes    = $self->smartify($content);
    my $content_without_smart_quotes = $self->desmartify($smart_content);

    $self->canonicalize( $input_file, $output_file, $skip_wrapping );

    # ...and because re-inventing the wheel is fun...
    my $file_content = $self->read_file($filename);
    $self->write_file( $filename, $content );

# DESCRIPTION

This module provides methods that support parsing and rendering Open Bible
Markup Language (OBML). OBML is a text markup way to represent Bible content,
one whole text file per chapter. The goal or purpose of OBML is similar to
Markdown in that it provides a human-readable text file allowing for simple and
direct editing of content while maintaining context, footnotes,
cross-references, "red text", and quotes.

## Open Bible Markup Language (OBML)

OBML makes the assumption that content will exist in one text file per chapter
and content mark-up will conform to the following specification:

    ~...~    --> material reference
    =...=    --> header
    {...}    --> crossreferences
    [...]    --> footnotes
    *...*    --> red text
    ^...^    --> italic
    4 spaces --> blockquote (line by line)
    6 spaces --> blockquote + indent (line by line)
    |*|      --> notes the beginning of a verse (the "*" must be a number)
    #        --> line comments

HTML/XML-like markup can be used throughout the content for additional markup
not defined by the above specification. When OBML is parsed, such markup
is ignored and passed through, treated like any other content of the verse.

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

# METHODS

## parse

This method accepts a single text string consisting of OBML. It parses the
string and returns a data structure as described above.

    my $data_structure = $self->parse($obml_text_content);

## render

This method accepts a data structure that conforms to the example description
above and returns a rendered OBML text output. It can optionally accept
a second input, which is a boolean, which if true will cause the method to
skip the line-wrapping step.

    my $obml_text_content = $self->render( $data_structure, $skip_wrapping );

Normally, this method will take the text output and wrap long lines. By passing
a second value which is true, you can cause the method to skip that step.

## smartify, desmartify

The intent of OBML is to store simple text files that you can use a basic text
editor on. Some people prefer viewing content with so-called "smart" quotes in
appropriate places. It is entirely possible to parse and render OBML as UTF8
that includes these so-called "smart" quotes. However, in the typical case of
pure ASCII, you may want to add or remove so-called "smart" quotes. Here's how:

    my $content_with_smart_quotes    = $self->smartify($content);
    my $content_without_smart_quotes = $self->desmartify($smart_content);

## canonicalize

This method requires an input filename and an output filename. It will read
the input file, assume it's OBML, parse it, clean-up references, and render
it back to OBML, and save it to the output filename.

    $self->canonicalize( $input_file, $output_file, $skip_wrapping );

You can optionally add a third input which is a boolean indicating if you want
the method to skip line-wrapping. (See the `render()` method for more
information.)

The point of this method is if you happen to be writing in OBML manually and
want to ensure your content is canonical OBML.

## read\_file, write\_file

Just in case you want to read or write a file directly, here are two methods
that reinvent the wheel.

    my $file_content = $self->read_file($filename);
    $self->write_file( $filename, $content );

# ATTRIBUTES

## reference

This module has an attribute of "reference" which contains a reference to an
instance of [Bible::OBML::Reference](https://metacpan.org/pod/Bible::OBML::Reference).

## html

This module has an attribute of "html" which contains a reference to an
instance of [Bible::OBML::HTML](https://metacpan.org/pod/Bible::OBML::HTML).

# SEE ALSO

[Bible::OBML::Reference](https://metacpan.org/pod/Bible::OBML::Reference), [Bible::OBML::HTML](https://metacpan.org/pod/Bible::OBML::HTML).

You can also look for additional information at:

- [GitHub](https://github.com/gryphonshafer/Bible-OBML)
- [CPAN](http://search.cpan.org/dist/Bible-OBML)
- [MetaCPAN](https://metacpan.org/pod/Bible::OBML)
- [AnnoCPAN](http://annocpan.org/dist/Bible-OBML)
- [Travis CI](https://travis-ci.org/gryphonshafer/Bible-OBML)
- [Coveralls](https://coveralls.io/r/gryphonshafer/Bible-OBML)
- [CPANTS](http://cpants.cpanauthors.org/dist/Bible-OBML)
- [CPAN Testers](http://www.cpantesters.org/distro/B/Bible-OBML.html)

# AUTHOR

Gryphon Shafer &lt;gryphon@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Gryphon Shafer.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
