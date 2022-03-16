package Bible::OBML;
# ABSTRACT: Open Bible Markup Language parser and renderer

use 5.020;

use exact;
use exact::class;
use Mojo::DOM;
use Mojo::Util 'html_unescape';
use Text::Wrap 'wrap';
use Bible::Reference;

# VERSION

has _load        => {};
has indent_width => 4;
has reference    => Bible::Reference->new(
    bible   => 'Protestant',
    sorting => 1,
);

sub __ocd_tree ($node) {
    my $new_node;

    if ( 'tag' eq shift @$node ) {
        $new_node->{tag} = shift @$node;

        my $attr = shift @$node;
        $new_node->{attr} = $attr if (%$attr);

        shift @$node;

        my $children = [ grep { defined } map { __ocd_tree($_) } @$node ];
        $new_node->{children} = $children if (@$children);
    }
    else {
        $new_node->{text} = $node->[0] if ( $node->[0] ne "\n\n" );
    }

    return $new_node;
}

sub __html_tree ($node) {
    if ( $node->{tag} ) {
        if ( $node->{children} ) {
            my $attr = ( $node->{attr} )
                ? ' ' . join( ' ', map { $_ . '="' . $node->{attr}{$_} . '"' } keys %{ $node->{attr} } )
                : '';

            return join( '',
                '<', $node->{tag}, $attr, '>',
                (
                    ( $node->{children} )
                        ? ( map { __html_tree($_) } @{ $node->{children} } )
                        : ()
                ),
                '</', $node->{tag}, '>',
            );
        }
        else {
            return '<' . $node->{tag} . '>';
        }
    }
    else {
        return $node->{text};
    }
}

sub __cleanup_html ($html) {
    # spacing cleanup
    $html =~ s/\s+/ /g;
    $html =~ s/(?:^\s+|\s+$)//mg;
    $html =~ s/^[ ]+//mg;

    # protect against inadvertent OBML
    $html =~ s/~/-/g;
    $html =~ s/`/'/g;
    $html =~ s/\|//g;
    $html =~ s/\\/ /g;
    $html =~ s/\*//g;
    $html =~ s/\{/(/g;
    $html =~ s/\}/)/g;
    $html =~ s/\[/(/g;
    $html =~ s/\]/)/g;

    $html =~ s|<p>|\n\n<p>|g;
    $html =~ s|<sub_header>|\n\n<sub_header>|g;
    $html =~ s|<header>|\n\n<header>|g;
    $html =~ s|<br>\s*|<br>\n|g;
    $html =~ s|[ ]+</p>|</p>|g;
    $html =~ s|[ ]+</obml>|</obml>|;

    # trim spaces at line ends
    $html =~ s/[ ]+$//mg;

    return $html;
}

sub __clean_html_to_data ($clean_html) {
    return __ocd_tree( Mojo::DOM->new($clean_html)->at('obml')->tree );
}

sub __data_to_clean_html ($data) {
    return __cleanup_html( __html_tree($data) );
}

sub _clean_html_to_obml ( $self, $html ) {
    my $dom = Mojo::DOM->new($html);

    # append a trailing <br> inside any <p> with a <br> for later wrapping reasons
    $dom->find('p')->grep( sub { $_->find('br')->size } )->each( sub { $_->append_content('<br>') } );

    my $obml = html_unescape( $dom->to_string );

    # de-XML
    $obml =~ s|</?obml>||g;
    $obml =~ s|</?p>||g;
    $obml =~ s|</?woj>|\*|g;
    $obml =~ s|</?i>|\^|g;
    $obml =~ s|</?small_caps>|\\|g;
    $obml =~ s|<reference>\s*|~ |g;
    $obml =~ s|\s*</reference>| ~|g;
    $obml =~ s!<verse_number>\s*!|!g;
    $obml =~ s!\s*</verse_number>!| !g;
    $obml =~ s|<sub_header>\s*|== |g;
    $obml =~ s|\s*</sub_header>| ==|g;
    $obml =~ s|<header>\s*|= |g;
    $obml =~ s|\s*</header>| =|g;
    $obml =~ s|<crossref>\s*|\{|g;
    $obml =~ s|\s*</crossref>|\}|g;
    $obml =~ s|<footnote>\s*|\[|g;
    $obml =~ s|\s*</footnote>|\]|g;
    $obml =~ s|^<indent level="(\d+)">| ' ' x ( $self->indent_width * $1 ) |mge;
    $obml =~ s|<indent level="\d+">||g;
    $obml =~ s|</indent>||g;

    # wrap lines that don't end in <br>
    $obml = join( "\n", map {
        unless ( s|<br>|| ) {
            s/^(\s+)//;
            $Text::Wrap::columns = 80 - length( $1 || '' );
            wrap( $1, $1, $_ );
        }
        else {
            $_;
        }
    } split( /\n/, $obml ) ) . "\n";

    chomp $obml;
    return $obml;
}

sub _obml_to_clean_html ( $self, $obml ) {
    # spacing cleanup
    $obml =~ s/\t/    /g;
    $obml =~ s/\n[ \t]+\n/\n\n/mg;

    # remove comments
    $obml =~ s/^\s*#.*?(?>\r?\n)//msg;

    # "unwrap" wrapped lines
    my @obml;
    for my $line ( split( /\n/, $obml ) ) {
        if ( not @obml or not length $line or not length $obml[-1] ) {
            push( @obml, $line );
        }
        else {
            my ($last_line_indent) = $obml[-1] =~ /^([ ]*)/;
            my ($this_line_indent) = $line     =~ /^([ ]*)/;

            if ( length $last_line_indent == length $this_line_indent ) {
                $line =~ s/^[ ]+//;
                $obml[-1] .= ' ' . $line;
            }
            else {
                push( @obml, $line );
            }
        }
    }
    $obml = join( "\n", @obml );

    $obml =~ s|~+[ ]*([^~]+?)[ ]*~+|<reference>$1</reference>|g;
    $obml =~ s|={2,}[ ]*([^=]+?)[ ]*={2,}|<sub_header>$1</sub_header>|g;
    $obml =~ s|=[ ]*([^=]+?)[ ]*=|<header>$1</header>|g;

    $obml =~ s|^([ ]+)(\S.*)$|
        '<indent level="'
        . int( ( length($1) + $self->indent_width * 0.5 ) / $self->indent_width )
        . '">'
        . $2
        . '</indent>'
    |mge;

    $obml =~ s|(\S)(?=\n\S)|$1<br>|g;

    $obml =~ s`(?:^|(?<=\n\n))(?!<(?:reference|sub_header|header)\b)`<p>`g;
    $obml =~ s`(?<!</(?:reference|sub_header|header)>)(?:$|(?=\n\n))`</p>`g;

    $obml =~ s!\|(\d+)\|\s*!<verse_number>$1</verse_number>!g;

    $obml =~ s|\*([^\*]+)\*|<woj>$1</woj>|g;
    $obml =~ s|\^([^\^]+)\^|<i>$1</i>|g;
    $obml =~ s|\\([^\\]+)\\|<small_caps>$1</small_caps>|g;

    $obml =~ s|\{|<crossref>|g;
    $obml =~ s|\}|</crossref>|g;

    $obml =~ s|\[|<footnote>|g;
    $obml =~ s|\]|</footnote>|g;

    return "<obml>$obml</obml>";
}

sub _accessor ( $self, $input = undef ) {
    my $want = ( split( '::', ( caller(1) )[3] ) )[-1];

    if ($input) {
        if ( ref $input ) {
            my $data_refs_ocd;
            $data_refs_ocd = sub ($node) {
                if (
                    $node->{tag} and $node->{children} and
                    ( $node->{tag} eq 'crossref' or $node->{tag} eq 'footnote' )
                ) {
                    for ( grep { $_->{text} } @{ $node->{children} } ) {
                        $_->{text} = $self->reference->acronyms(1)->clear->in( $_->{text} )->as_text;
                    }
                }
                if ( $node->{children} ) {
                    $data_refs_ocd->($_) for ( @{ $node->{children} } );
                }
                return;
            };
            $data_refs_ocd->($input);

            my $reference = ( grep { $_->{tag} eq 'reference' } @{ $input->{children} } )[0]{children}[0];
            my $runs = $self->reference->acronyms(0)->clear->in( $reference->{text} )->as_runs;
            $reference->{text} = $runs->[0];
        }
        else {
            my $ref_ocd = sub ( $text, $acronyms ) {
                return $self->reference->acronyms($acronyms)->clear->in($text)->as_text;
            };

            $input =~ s!
                ((?:<(?:footnote|crossref)>|\{|\[)\s*.+?\s*(?:</(?:footnote|crossref)>|\}|\]))
            !
                $ref_ocd->( $1, 1 )
            !gex;

            $input =~ s!((?:<reference>|~)\s*.+?\s*(?:</reference>|~))! $ref_ocd->( $1, 0 ) !gex;
        }

        return $self->_load({ $want => $input });
    }

    return $self->_load->{data} if ( $want eq 'data' and $self->_load->{data} );

    unless ( $self->_load->{canonical}{$want} ) {
        if ( $self->_load->{html} ) {
            $self->_load->{clean_html} //= __cleanup_html( $self->_load->{html} );

            if ( $want eq 'obml' ) {
                $self->_load->{canonical}{obml} = $self->_clean_html_to_obml( $self->_load->{clean_html} );
            }
            elsif ( $want eq 'data' or $want eq 'html' ) {
                $self->_load->{data} = __clean_html_to_data( $self->_load->{clean_html} );

                $self->_load->{canonical}{html} = __data_to_clean_html( $self->_load->{data} )
                    if ( $want eq 'html' );
            }
        }
        elsif ( $self->_load->{data} ) {
            $self->_load->{canonical}{html} = __data_to_clean_html( $self->_load->{data} );

            $self->_load->{canonical}{obml} = $self->_clean_html_to_obml( $self->_load->{canonical}{html} )
                if ( $want eq 'obml' );
        }
        elsif ( $self->_load->{obml} ) {
            $self->_load->{canonical}{html} = $self->_obml_to_clean_html( $self->_load->{obml} );

            if ( $want eq 'obml' ) {
                $self->_load->{canonical}{obml} = $self->_clean_html_to_obml(
                    $self->_load->{canonical}{html}
                );
            }
            elsif ( $want eq 'data' ) {
                $self->_load->{data} = __clean_html_to_data( $self->_load->{canonical}{html} );
            }
        }
    }

    return ( $want eq 'data' ) ? $self->_load->{$want} : $self->_load->{canonical}{$want};
}

sub data { shift->_accessor(@_) }
sub html { shift->_accessor(@_) }
sub obml { shift->_accessor(@_) }

1;
__END__

=pod

=begin :badges

=for markdown
[![test](https://github.com/gryphonshafer/Bible-OBML/workflows/test/badge.svg)](https://github.com/gryphonshafer/Bible-OBML/actions?query=workflow%3Atest)
[![codecov](https://codecov.io/gh/gryphonshafer/Bible-OBML/graph/badge.svg)](https://codecov.io/gh/gryphonshafer/Bible-OBML)

=end :badges

=begin :prelude

=for test_synopsis
my(
    $obml_text_content, $data_structure, $skip_wrapping, $skip_smartify,
    $content, $smart_content, $input_file, $output_file, $filename,
);

=end :prelude

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This module provides methods that support parsing and rendering Open Bible
Markup Language (OBML). OBML is a text markup way to represent Bible content,
one whole text file per chapter. The goal or purpose of OBML is similar to
Markdown in that it provides a human-readable text file allowing for simple and
direct editing of content while maintaining context, footnotes,
cross-references, "red text", and quotes.

=head2 Open Bible Markup Language (OBML)

OBML makes the assumption that content will exist in one text file per chapter
and content mark-up will conform to the following specification:

    ~...~   --> material reference
    =...=   --> header
    ==...== --> sub-header
    |...|   --> verse number
    {...}   --> cross-references
    [...]   --> footnotes
    *...*   --> red text
    ^...^   --> italic
    \...\   --> small-caps, divine-name
    spaces  --> indenting
    #       --> line comments

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

The intent of OBML is to store simple text files that you can use a basic text
editor on. Some people prefer viewing content with so-called "smart" quotes in
appropriate places. It is entirely possible to parse and render OBML as UTF8
that includes these so-called "smart" quotes. However, in the typical case of
pure ASCII, you may want to add or remove so-called "smart" quotes. Here's how:

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

=head2 html

This module has an attribute of "html" which contains a reference to an
instance of L<Bible::OBML::HTML>.

=head2 acronyms

By default, references will be canonicalized in acronym form; however, you can
change that by setting the value of this accessor.

    $self->acronyms(1); # use acronyms; default
    $self->acronyms(0); # use full book names

=head2 refs

This is an accessor to a string that informs the OBML parser and renderer how
to group canonicalized references. The string must be one of the following:

=for :list
* refs
* as_books (default)
* as_chapters
* as_runs
* as_verses

These directly correspond to methods from L<Bible::Reference>. See that
module's documentation for details.

=head2 bible

This is an accessor to a string value representing one of the Bible types
supported by L<Bible::Reference>. By default, this is "Protestant" as per the
default in L<Bible::Reference>. See that module's documentation for details.

=head1 SEE ALSO

L<Bible::OBML::HTML>, L<Bible::Reference>.

You can also look for additional information at:

=for :list
* L<GitHub|https://github.com/gryphonshafer/Bible-OBML>
* L<MetaCPAN|https://metacpan.org/pod/Bible::OBML>
* L<GitHub Actions|https://github.com/gryphonshafer/Bible-OBML/actions>
* L<Codecov|https://codecov.io/gh/gryphonshafer/Bible-OBML>
* L<CPANTS|http://cpants.cpanauthors.org/dist/Bible-OBML>
* L<CPAN Testers|http://www.cpantesters.org/distro/B/Bible-OBML.html>

=for Pod::Coverage BUILD

=cut
