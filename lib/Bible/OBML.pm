package Bible::OBML;
use Moose;
use Text::Balanced qw( extract_delimited extract_bracketed );
use Text::Wrap 'wrap';
use Bible::OBML::Reference;
use Bible::OBML::HTML;

with 'Throwable';

our $VERSION = '1.01';

has reference => (
    is      => 'ro',
    isa     => 'Bible::OBML::Reference',
    default => sub { Bible::OBML::Reference->new },
);

has html => (
    is      => 'ro',
    isa     => 'Bible::OBML::HTML',
    default => sub { Bible::OBML::HTML->new( obml => shift ) },
);

binmode( STDOUT, ':encoding(utf8)' );
binmode( STDERR, ':encoding(utf8)' );

sub read_file {
    my ( $self, $filename ) = @_;
    open( my $file, '<:encoding(utf8)', $filename ) or $self->throw($!);
    return join( '', <$file> );
}

sub write_file {
    my ( $self, $filename, $content ) = @_;
    open( my $file, '>:encoding(utf8)', $filename ) or $self->throw($!);
    print $file $content;
    return;
}

sub parse {
    my ( $self, $content ) = @_;

    # remove comments
    $content =~ s/^\s*#.*?(?>\r?\n)//msg;

    # "unwrap" wrapped lines
    my $last_space = 0;
    my @buffer;
    $content = join( "\n", reverse grep { defined } map {
        my $line = $_;
        my ( $rv, $space );

        if ( $line !~ /^\s*$/ ) {
            $space = ( $line =~ s/^([ ]+)// ) ? length $1 : 0;

            if ( defined $last_space and $space != $last_space ) {
                $rv = ( ' ' x $last_space ) . join( ' ', reverse @buffer ) . "\n";
                @buffer = ();
            }

            push( @buffer, $line );
        }
        else {
            $rv = ( ' ' x $last_space ) . join( ' ', reverse @buffer ) . "\n";
            @buffer = ();
            $rv .= $line;
        }

        $last_space = $space || 0;
        $rv;
    } reverse split( /\n/, "\n" . $content ) );
    $content = join( ' ', reverse @buffer ) . "\n" . $content;
    $content =~ s/\n//;

    # pull out the reference base
    ( my $reference_base = ( $content =~ s/~([^~]+)~//ms ) ? $1 : undef ) =~ s/^\s+|\s+$//g;

    # warn on any obvious errors
    $self->throw('Missing reference base marker') unless ($reference_base);
    $self->throw('Multiple reference base markers') if ( $content =~ /~[^~]+~/ms );

    my $book = $reference_base;
    my $chapter = 1;
    $chapter = $1 if ( $book =~ s/\s*(\d+)\s*$// );

    $self->throw(qq{Book "$book" unknown; must use canonical book name})
        unless ( grep { $_ eq $book } $self->reference->books );

    my $parse_block;
    $parse_block = sub {
        my ($block_content) = @_;
        my @parts;

        if ( @parts = split( /(?:\s*\r?\n){2,}/, $block_content, 2 ) and @parts > 1 ) {
            return grep { $_ }
                $parse_block->( $parts[0] ),
                ['paragraph'],
                $parse_block->( $parts[1] );
        }

        if ( @parts = split( /(?:\s*\r?\n)/, $block_content, 2 ) and @parts > 1 ) {
            my @parsed_parts = grep { $_ } map { $parse_block->($_) } @parts;

            for ( my $i = 0; $i < $#parsed_parts; $i++ ) {
                splice( @parsed_parts, $i + 1, 0, ['break'] ) if (
                    ref( $parsed_parts[$i] ) and
                    ref( $parsed_parts[ $i + 1 ] ) and
                    (
                        (
                            $parsed_parts[$i][0] eq 'blockquote' and
                            $parsed_parts[ $i + 1 ][0] eq 'blockquote_indent'
                        ) or (
                            $parsed_parts[$i][0] eq 'blockquote_indent' and
                            $parsed_parts[ $i + 1 ][0] eq 'blockquote'
                        )
                    )
                );
            }

            return @parsed_parts;
        }

        if ( $block_content =~ s/^(\s{2,})(?=\S)// ) {
            my $size = length($1);
            return [
                ( ( $size == 4 ) ? 'blockquote' : 'blockquote_indent' ),
                $parse_block->($block_content),
            ];
        }

        for (
            [ 'footnote', '[]' ],
            [ 'crossreference', '{}' ],
            [ 'red text', '<>' ],
            [ 'italic', '^' ],
        ) {
            my $method = ( length( $_->[1] ) == 1 ) ? \&extract_delimited : \&extract_bracketed;
            my ( $bit, $remainder, $entry ) = $method->(
                $block_content,
                $_->[1],
                '(?s).*?(?=\\' . substr( $_->[1], 0, 1 ) . ')',
            );

            if ($bit) {
                $bit = substr( $bit, 1, length($bit) - 2 );
                $bit = $self->reference->parse( $bit, 1 ) if ( $_->[0] eq 'crossreference' );

                return grep { $_ }
                    $parse_block->($entry),
                    [ $_->[0], $parse_block->($bit) ],
                    $parse_block->($remainder);
            }
        }

        $block_content =~ s/\s{2,}/ /msg;
        $block_content =~ s/^\s+|\s+$//msg;
        return $block_content;
    };

    my $parse_wrap = sub {
        my ($block_content) = @_;
        my @results = $parse_block->($block_content);

        my $i = 0;
        while ( $i <= @results ) {
            if (
                ref( $results[$i] ) and ref( $results[ $i + 1 ] ) and
                $results[$i][0] eq $results[ $i + 1 ][0]
            ) {
                my $node = splice( @results, $i + 1, 1 );

                if ( not ref( $results[$i][-1] ) and not ref( $node->[1] ) ) {
                    $results[$i][-1] .= ' ' . $node->[1];
                }
                else {
                    push( @{ $results[$i] }, $node->[1] );
                }
            }
            else {
                $i++;
            }
        }

        return [@results];
    };

    my ( @verses, $header_text );

    for my $block ( grep { /\w/ } map { split(/(?=\=[^=]+\=)/) } split( /(?=\|\d+\|)/, $content ) ) {
        if ( $block =~ /\=\s*([^=]+?)\s*\=/ ) {
            $self->throw('Multiple back-to-back headers found') if ($header_text);
            $header_text = $parse_wrap->($1);
            next;
        }

        my $verse_number = $1 if ( $block =~ s/\|\s*(\d+)\s*\|\s*// );
        $self->throw('Failed to find verse number') unless ($verse_number);

        my $verse = {
            reference => {
                book    => $book,
                chapter => $chapter,
                verse   => $verse_number,
            },
            content => $parse_wrap->($block),
        };

        if ($header_text) {
            $verse->{header} = $header_text;
            undef $header_text;
        }

        # if there's an unfinished blockquote from the previous verse,
        # ensure it's copied into this verse...
        if (
            @verses and $verses[-1] and ref( $verses[-1]{content} ) and ref( $verses[-1]{content}[-1] ) and
            (
                $verses[-1]{content}[-1][0] eq 'blockquote' or
                $verses[-1]{content}[-1][0] eq 'blockquote_indent'
            ) and not ref( $verse->{content}[0] )
        ) {
            $verse->{content}[0] = [ $verses[-1]{content}[-1][0], $verse->{content}[0] ];

            if ( ref( $verse->{content}[1] ) and $verse->{content}[0][0] eq $verse->{content}[1][0] ) {
                my $node = splice( @{ $verse->{content} }, 1, 1 );
                $verse->{content}[0][1] .= ' ' . $node->[1];
            }

            splice( @{ $verse->{content} }, 1, 0, ['break'] ) if (
                $verse->{content}[0] and $verse->{content}[1] and
                ref( $verse->{content}[0] ) and ref( $verse->{content}[1] ) and
                (
                    (
                        $verse->{content}[0][0] eq 'blockquote' and
                        $verse->{content}[1][0] eq 'blockquote_indent'
                    ) or
                    (
                        $verse->{content}[0][0] eq 'blockquote_indent' and
                        $verse->{content}[1][0] eq 'blockquote'
                    )
                )
            );
        }

        push( @verses, $verse );
    }

    return \@verses;
}

sub render {
    my ( $self, $data, $skip_wrapping ) = @_;
    my $content = '';

    my $render_block;
    $render_block = sub {
        my ($node) = @_;
        return $node unless ( ref $node );

        if ( $node->[0] eq 'crossreference' ) {
            return '{' . join( '; ', map { $render_block->($_) } @{ $node->[1] } ) . '}';
        }
        elsif ( $node->[0] eq 'footnote' ) {
            shift @$node;
            return '[' . join( ' ', map { $render_block->($_) } @$node ) . ']';
        }
        elsif ( $node->[0] eq 'italic' ) {
            shift @$node;
            return '^' . join( ' ', map { $render_block->($_) } @$node ) . '^';
        }
        elsif ( $node->[0] eq 'red text' ) {
            shift @$node;
            return '<' . join( ' ', map { $render_block->($_) } @$node ) . '>';
        }
        elsif ( $node->[0] eq 'paragraph' ) {
            return "\n\n";
        }
        elsif ( $node->[0] eq 'break' ) {
            return "\n";
        }
        elsif ( $node->[0] eq 'blockquote' ) {
            shift @$node;
            return ( ' ' x 4 ) . join( ' ', map { $render_block->($_) } @$node );
        }
        elsif ( $node->[0] eq 'blockquote_indent' ) {
            shift @$node;
            return ( ' ' x 6 ) . join( ' ', map { $render_block->($_) } @$node );
        }
        else {
            my $rendered_block = join( ' ', map { $render_block->($_) } @$node );
            $rendered_block =~ s/[ \t]*(\n+)[ \t]?/$1/g;
            return $rendered_block;
        }
    };

    my %chapters;
    my $verses_seen = 0;
    for my $verse (@$data) {
        unless ($content) {
            my $chapter = $verse->{reference}{book} . ' ' . $verse->{reference}{chapter};
            $self->throw('Appears to be multiple chapters in data; must be single chapter only')
                if ( $chapters{$chapter}++ );
            $content .= "~ $chapter ~\n\n";
        }

        $content .= '= ' . $render_block->( $verse->{header} ) . " =\n\n" if ( $verse->{header} );
        $content .= ' ' if ( substr( $content, length($content) - 1, 1 ) ne "\n" );

        my $verse_content = $render_block->( $verse->{content} );
        my $leader = ( $verse_content =~ s/^(\s*)// and not $verses_seen ) ? $1 : '';

        $content .= $leader . '|' . $verse->{reference}{verse} . '| ' . $verse_content;
        $verses_seen++;
    }

    $content =~ s/\{\s+/\{/g;
    $content =~ s/\s+\}/\}/g;
    $content =~ s/\[\s+/\[/g;
    $content =~ s/\s+\]/\]/g;
    $content =~ s/(?<=\^)\s+(?=[\,\;\.\-\!\?]+\s)//g;
    $content =~ s/\s+$/\n/msg;
    $content .= "\n";

    return $content if ($skip_wrapping);

    return join( "\n", map {
        s/^(\s+)//;
        $Text::Wrap::columns = 80 - length( $1 || '' );
        wrap( $1, $1, $_ );
    } split( /\n/, $content ) ) . "\n";
}

sub smartify {
    my ( $self, $text ) = @_;

    # extraction

    my ( $processed, $extract, @bits, @sub_bits );

    $extract = sub {
        my ($type) = @_;

        my $method = ( length( $type->[1] ) == 1 ) ? \&extract_delimited : \&extract_bracketed;
        my ( $bit, $entry );
        ( $bit, $text, $entry ) = $method->(
            $text,
            $type->[1],
            '(?s).*?(?=\\' . substr( $type->[1], 0, 1 ) . ')',
        );

        if ($bit) {
            $bit = substr( $bit, 1, length($bit) - 2 );

            $processed .= $entry . ( ( length $type->[1] == 1 ) ? $type->[1] x 2 : $type->[1] );
            push( @sub_bits, $bit );

            $extract->($type);
        }
    };

    for (
        [ 'crossreference', '{}' ],
        [ 'footnote', '[]' ],
        [ 'header', '=' ],
        [ 'material', '~' ],
    ) {
        $processed = '';
        $extract->($_);
        $text = $processed . $text;
        push( @bits, reverse @sub_bits );
        @sub_bits = ();
    }

    # conversion

    my $convert = sub {
        my ($content) = @_;

        while (1) {
            my ( $bit, $entry );
            ( $bit, $content, $entry ) = extract_delimited(
                $content,
                '"',
                '(?s).*?(?=\\")',
            );

            if ($bit) {
                $bit = substr( $bit, 1, length($bit) - 2 );
                $content = $entry . chr(8220) . $bit . chr(8221) . $content;
            }
            else {
                last;
            }
        }

        $content =~ s/(?<=\w)\'(?=\w)/ chr(8217) /ge;
        $content =~ s/\'(\S[^\']*\S)\'/ chr(8216) . $1 . chr(8217) /ge;
        $content =~ s/\'/ chr(8217) /ge;

        return $content;
    };

    $text = $convert->($text);
    @bits = map { $convert->($_) } @bits;

    # recombining

    my $result;
    my $recombine;
    $recombine = sub {
        my ($type) = @_;

        my $method = ( length( $type->[1] ) == 1 ) ? \&extract_delimited : \&extract_bracketed;
        my ( $bit, $entry );
        ( $bit, $text, $entry ) = $method->(
            $text,
            $type->[1],
            '(?s).*?(?=\\' . substr( $type->[1], 0, 1 ) . ')',
        );

        if ($bit) {
            my ( $start, $stop ) = ( length( $type->[1] ) == 1 )
                ? ( ( $type->[1] ) x 2 )
                : split( '', $type->[1] );

            $result .= $entry . $start . pop(@bits) . $stop;

            $recombine->($type);
        }
    };

    for (
        [ 'material', '~' ],
        [ 'header', '=' ],
        [ 'footnote', '[]' ],
        [ 'crossreference', '{}' ],
    ) {
        $result = '';
        $recombine->($_);
        $text = $result . $text;
    }

    return $text;
}

sub desmartify {
    my ( $self, $text ) = @_;
    ( my $new_text = $text ) =~ tr/\x{201c}\x{201d}\x{2018}\x{2019}/""''/;
    return $new_text;
}

sub canonicalize {
    my ( $self, $input_file, $output_file, $skip_wrapping ) = @_;
    $output_file ||= $input_file;

    $self->write_file(
        $output_file,
        $self->render(
            $self->parse(
                $self->read_file($input_file)
            ),
            $skip_wrapping,
        )
    );

    return;
}

__PACKAGE__->meta->make_immutable;
1;
__END__
=pod
=head1 NAME

Bible::OBML - Open Bible Markup Language parser and renderer

=head1 SYNOPSIS

    my $data_structure    = $self->parse($obml_text_content);
    my $obml_text_content = $self->render( $data_structure, $skip_wrapping );

    my $content_with_smart_quotes    = $self->smartify($content);
    my $content_without_smart_quotes = $self->desmartify($smart_content);

    $self->canonicalize( $input_file, $output_file, $skip_wrapping );

    # ...and because re-inventing the wheel is fun...
    my $file_content = $self->read_file($filename);
    $self->write_file( $filename, $content );

=head1 DESCRIPTION

This module provides methods that support parsing and rendering Open Bible
Markup Language (OBML). OBML is a pure-ASCII-text markup way to represent Bible
content, one whole text file per chapter. The goal or purpose of OBML is similar
to Markdown in that it provides a human-readable text file allowing for simple
and direct editing of content while maintaining context, footnotes,
cross-references, "red text", and quotes.

=head2 Open Bible Markup Language (OBML)

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

=head1 METHODS

=head2 parse

This method accepts a single text string consisting of OBML. It parses the
string and returns a data structure as described above.

    my $data_structure = $self->parse($obml_text_content);

=head2 render

This method accepts a data structure that conforms to the example description
above and returns a rendered OBML text output. It can optionally accept
a second input, which is a boolean, which if true will cause the method to
skip the line-wrapping step.

    my $obml_text_content = $self->render( $data_structure, $skip_wrapping );

Normally, this method will take the text output and wrap long lines. By passing
a second value which is true, you can cause the method to skip that step.

=head2 smartify, desmartify

The intent of OBML is to store ASCII text files. Some people prefer viewing
content with so-called "smart" quotes in appropriate places. It is entirely
possible to parse and render OBML as UTF8 that includes these so-called "smart"
quotes. However, in the typical case of pure ASCII, you may want to add or
remove so-called "smart" quotes. Here's how:

    my $content_with_smart_quotes    = $self->smartify($content);
    my $content_without_smart_quotes = $self->desmartify($smart_content);

=head2 canonicalize

This method requires an input filename and an output filename. It will read
the input file, assume it's OBML, parse it, clean-up references, and render
it back to OBML, and save it to the output filename.

    $self->canonicalize( $input_file, $output_file, $skip_wrapping );

You can optionally add a third input which is a boolean indicating if you want
the method to skip line-wrapping. (See the C<render()> method for more
information.)

The point of this method is if you happen to be writing in OBML manually and
want to ensure your content is canonical OBML.

=head2 read_file, write_file

Just in case you want to read or write a file directly, here are two methods
that reinvent the wheel.

    my $file_content = $self->read_file($filename);
    $self->write_file( $filename, $content );

=head1 ATTRIBUTES

=head2 reference

This module has an attribute of "reference" which contains a reference to an
instance of L<Bible::OBML::Reference>.

=head2 html

This module has an attribute of "html" which contains a reference to an
instance of L<Bible::OBML::HTML>.

=head1 SEE ALSO

L<Bible::OBML::Reference>, L<Bible::OBML::HTML>.

=head1 AUTHOR

Gryphon Shafer E<lt>gryphon@cpan.orgE<gt>.

    code('Perl') || die;

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
