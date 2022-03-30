# NAME

Bible::OBML - Open Bible Markup Language parser and renderer

# VERSION

version 2.04

[![test](https://github.com/gryphonshafer/Bible-OBML/workflows/test/badge.svg)](https://github.com/gryphonshafer/Bible-OBML/actions?query=workflow%3Atest)
[![codecov](https://codecov.io/gh/gryphonshafer/Bible-OBML/graph/badge.svg)](https://codecov.io/gh/gryphonshafer/Bible-OBML)

# SYNOPSIS

    use Bible::OBML;
    my $bo = Bible::OBML->new;

    use Bible::OBML::Gateway;
    my $gw   = Bible::OBML::Gateway->new;
    my $html = $gw->parse( $gw->fetch( 'Romans 12', 'NIV' ) );

    my $obml  = $bo->html($html)->obml;
    my $data  = $bo->obml($obml)->data;
    my $obml2 = $bo->data($data)->obml;

# DESCRIPTION

This module provides methods that support parsing and rendering Open Bible
Markup Language (OBML). OBML is a text markup way to represent Bible content,
one whole text file per chapter. The goal or purpose of OBML is similar to
Markdown in that it provides a human-readable text file allowing for simple and
direct editing of content while maintaining context, footnotes,
cross-references, "red text", and other basic formatting.

## Open Bible Markup Language (OBML)

OBML makes the assumption that content will exist in one text file per chapter
and content mark-up will conform to the following specification (where "..."
represents textual content):

    ~ ... ~   --> material reference
    = ... =   --> header
    == ... == --> sub-header
    |...|     --> verse number
    {...}     --> cross-references
    [...]     --> footnotes
    *...*     --> red text
    ^...^     --> italic
    \...\     --> small-caps
    spaces    --> indenting
    # ...     --> line comments
                  (if "#" is the first non-whitespace character on the line)

HTML-like markup can be used throughout the content for additional markup not
defined by the above specification. When OBML is parsed, such markup is ignored
and passed through, treated like any other content of the verse.

An example of OBML follows, with several verses missing so as to save space:

    ~ Mark 1 ~

    = John the Baptist Prepares the Way{Mt 3:1, 11; Lk 3:2, 16} =

    |1| The beginning of the good news about Jesus the Messiah,[Or ^Jesus Christ.^
    ^Messiah^ (He) and ^Christ^ (Greek) both mean ^Anointed One.^] the Son of
    God,[Some manuscripts do not have ^the SS of God.^]{Mt 4:3} |2| as it is
    written in Isaiah the prophet:

        “I will send my messenger ahead of you,
            who will prepare your way”[Ml 3:1]{Ml 3:1; Mt 11:10; Lk 7:27}—
        |3| “a voice of one calling in the wilderness,
        ‘Prepare the way for the \Lord\,
            make straight paths for him.’”[Is 40:3]{Is 40:3; Joh 1:23}

    |4| And so John the Baptist{Mt 3:1} appeared in the wilderness, preaching a
    baptism of repentance{Mk 1:8; Joh 1:26, 33; Ac 1:5, 22; 11:16; 13:24; 18:25;
    19:3-4} for the forgiveness of sins.{Lk 1:77}

    # cut verses 5-13 to save space

    = Jesus Announces the Good News{Mt 4:18, 22; Lk 5:2, 11; Joh 1:35, 42} =

    |14| After John{Mt 3:1} was put in prison, Jesus went into Galilee,{Mt 4:12}
    proclaiming the good news of God.{Mt 4:23} *|15| “The time has come,”{Ro 5:6;
    Ga 4:4; Ep 1:10}* he said. *“The kingdom of God has come near. Repent and
    believe{Joh 3:15} the good news!”{Ac 20:21}*

Typically, one might load OBML and render it into HTML-like output or a data
structure.

    my $html = Bible::OBML->new->obml($obml)->html;
    my $data = Bible::OBML->new->obml($obml)->data;

# METHODS

## obml

This method accepts OBML as input or if no input is provided outputs OBML
converted from previous input.

    my $object = Bible::OBML->new->obml($obml);
    say $object->obml;

## html

This method accepts a specific form of HTML-like input or if no input is
provided outputs this HTML-like content converted from previous input.

    my $object = Bible::OBML->new->html($html);
    say $object->html;

HTML-like content might look something like this:

    <obml>
        <reference>Mark 1</reference>
        <header>
            John the Baptist Prepares the Way
            <crossref>Mt 3:1, 11; Lk 3:2, 16</crossref>
        </header>
        <p>
            <verse_number>1</verse_number>
            The beginning of the good news about Jesus the Messiah,
            <footnote>
                Or <i>Jesus Christ.</i> <i>Messiah</i> (He) and <i>Christ</i>
                (Greek) both mean <i>Anointed One.</i>
            </footnote> the Son of God...
        </p>
    </obml>

## data

This method accepts OBML as input or if no input is provided outputs OBML
converted from previous input.

    my $object = Bible::OBML->new->data($data);
    use DDP;
    p $object->data;

This data might look something like this:

    {
        tag      => 'obml',
        children => [
            {
                tag      => 'reference',
                children => [ { text => 'John 1' } ],
            },
            {
                tag      => 'p',
                children => [
                    {
                        tag      => 'verse_number',
                        children => [ { text => '1' } ],
                    },
                    { text => 'In the beginning' },
                    {
                        tag      => 'crossref',
                        children => [ { text => 'Ge 1:1' } ],
                    },
                    { text => ' was...' },
                ],
            },
        ],
    };

# ATTRIBUTES

Attributes can be set in a call to `new` or explicitly as a get/set method.

    my $bo = Bible::OBML->new( indent_width => 4, reference_acronym => 0 );
    $bo->indent_width(4);
    say $bo->reference_acronym;

## indent\_width

This attribute is an integer representing the number of spaces that will be
considered a single level of indentation. It's set to a default of 4 spaces.

## reference\_acronym

By default, references in "reference" sections will be canonicalized to non-
acronym form; however, you can change that by setting the value of this accessor
to a true value.

## fnxref\_acronym

By default, references in all non-"reference" sections (i.e. cross-references
and some footnotes) will be canonicalized to acronym form; however, you can
change that by setting the value of this accessor to a false value.

## wrap\_at

By default, lines of OBML that are not indented will be wrapped at 80
characters. You can adjust this point with this attribute. If set to a false
value, no wrapping will take place.

# SEE ALSO

[Bible::OBML::Gateway](https://metacpan.org/pod/Bible%3A%3AOBML%3A%3AGateway), [Bible::Reference](https://metacpan.org/pod/Bible%3A%3AReference).

You can also look for additional information at:

- [GitHub](https://github.com/gryphonshafer/Bible-OBML)
- [MetaCPAN](https://metacpan.org/pod/Bible::OBML)
- [GitHub Actions](https://github.com/gryphonshafer/Bible-OBML/actions)
- [Codecov](https://codecov.io/gh/gryphonshafer/Bible-OBML)
- [CPANTS](http://cpants.cpanauthors.org/dist/Bible-OBML)
- [CPAN Testers](http://www.cpantesters.org/distro/B/Bible-OBML.html)

# AUTHOR

Gryphon Shafer <gryphon@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2014-2050 by Gryphon Shafer.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
