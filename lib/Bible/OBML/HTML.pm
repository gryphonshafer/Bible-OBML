package Bible::OBML::HTML;
use Moose;
use Template;
use Bible::OBML;

with 'Throwable';

our $VERSION = '1.01';

has obml => ( is => 'ro', isa => 'Bible::OBML', default => sub { Bible::OBML->new } );

sub from_file {
    my ( $self, $file, $skip_smartify ) = @_;
    $self->throw('Data provided is not a filename') unless ( -f $file );

    my $obml = $self->obml->read_file($file);
    $obml = $self->obml->smartify($obml) unless ($skip_smartify);
    return $self->_html( $self->obml->parse($obml) );
}

sub from_data {
    my ( $self, $data, $skip_smartify ) = @_;
    $self->throw('Data provided is not an arrayref') unless ( ref($data) eq 'ARRAY' );

    $data = $self->obml->parse( $self->obml->smartify( $self->obml->render($data) ) )
        unless ($skip_smartify);

    return $self->_html($data);
}

sub from_obml {
    my ( $self, $obml, $skip_smartify ) = @_;
    $self->throw('Data provided is not a string') if ( ref($obml) );

    $obml = $self->obml->smartify($obml) unless ($skip_smartify);
    return $self->_html( $self->obml->parse($obml) );
}

sub _html {
    my ( $self, $content ) = @_;
    my $output = '';

    Template->new({
        FILTERS => {
            verse_collapse => sub {
                my ($text) = @_;

                $text =~ s/\s{2,}/ /msg;
                $text =~ s/^\s+|\s+$//msg;
                $text =~ s/\s+(?=<sup\b)|//msg;
                $text =~ s/(?<=i>)\s+(?=[^\sa-zA-Z0-9])//msg;

                return $text;
            },
            fn_tidy => sub {
                my ($text) = @_;
                $text =~ s/<[^>]*?>//g;
                return $text;
            }
        },
    })->process(
        \q{
            [%
                crossreferences = [];
                footnotes       = [];
                inside_element  = '';
            %]

            [% BLOCK render %]
                [% FOREACH bit IN bits %]
                    [% IF bit.length %]
                        [% bit %]
                    [% ELSE %]
                        [% type = bit.shift %]

                        [% IF type == 'italic' %]
                            <i>[% PROCESS render bits = bit | trim %]</i>
                        [% ELSIF type == 'red text' %]
                            <span class="obml_red_text">[% PROCESS render bits = bit | trim %]</span>
                        [% ELSIF type == 'crossreference' %]
                            [%
                                rv = bit.shift;
                                crossreferences.push(rv);
                            %]
                            <sup class="obml_crossreference"><a
                                href="#cr[% crossreferences.size %]"
                                title="[% crossreferences.size %]: [% rv.join('; ') %]"
                            >{[% crossreferences.size %]}</a></sup>
                        [% ELSIF type == 'footnote' %]
                            [%
                                rv = BLOCK;
                                    PROCESS render bits = bit;
                                END;
                                footnotes.push(rv);
                            %]
                            <sup class="obml_footnote"><a
                                href="#fn[% footnotes.size %]"
                                title="[% footnotes.size %]: [% rv | fn_tidy | trim %]"
                            >[[% footnotes.size %]]</a></sup>
                        [% ELSIF type == 'paragraph' %]
                            [% IF inside_element != '' %]
                                </span>
                                [% inside_element = '' %]
                            [% END %]
                            </p><p>
                        [% ELSIF type == 'break' %]
                            [% IF inside_element %]
                                </span>
                                [% inside_element = '' %]
                            [% END %]
                            <br />
                        [% ELSIF type == 'blockquote' %]
                            [% IF inside_element != 'blockquote' %]
                                <span class="obml_blockquote">
                                [% inside_element = 'blockquote' %]
                            [% END %]
                            [% PROCESS render bits = bit | trim %]
                        [% ELSIF type == 'blockquote_indent' %]
                            [% IF inside_element != 'blockquote_indent' %]
                                <span class="obml_blockquote_indent">
                                [% inside_element = 'blockquote_indent' %]
                            [% END %]
                            [% PROCESS render bits = bit | trim %]
                        [% ELSE %]
                            <sub><b>[ ERROR: [% type %] | [% bit.join(' | ') %] ]</b></sub>
                        [% END %]
                    [% END %]
                [% END %]
            [% END %]

            <div class="obml">
                <div class="obml_title">[% content.0.reference.book %] [% content.0.reference.chapter %]</div>
                <div class="obml_content">
                    [% IF content %]
                        <div class="obml_scripture">
                            [% USE wrap %]
                            [% FILTER wrap( 110, '', '' ) %]
                                [% FOREACH verse IN content %]
                                    [% FILTER collapse %]
                                        [% IF verse.header %]
                                            [% UNLESS loop.first %]</p>[% END %]
                                            <div class="obml_header">[%
                                                PROCESS render bits = verse.header | verse_collapse %]</div>
                                            [% UNLESS loop.first %]<p>[% END %]
                                        [% END %]
                                        [% IF loop.first %]<p>[% END %]
                                        <sup class="obml_reference"><b>[% verse.reference.verse %]</b></sup>
                                        [%- PROCESS render bits = verse.content | verse_collapse %]
                                        [% IF loop.last %]</p>[% END %]
                                    [% END %]
                                [% END %]
                            [% END %]
                        </div>
                    [% ELSE %]
                        <p>A content parsing error occured.</p>
                    [% END %]

                    [% IF footnotes.size OR crossreferences.size %]
                        </div>
                        <div class="obml_notes_title">Notes</div>
                        <div class="obml_notes">
                            <p>
                                There are
                                [% IF footnotes.size %]footnotes[% END %]
                                [% IF footnotes.size AND crossreferences.size %]and[% END %]
                                [% IF crossreferences.size %]crossreferences[% END %]
                                for this chapter.
                            </p>

                            [% IF footnotes.size %]
                                <div class="obml_footnote">
                                    <div class="obml_footnote_title">[Footnotes]</div>
                                    <ol>
                                        [% count = 0 %]
                                        [% FOREACH item IN footnotes %]
                                            [% count = count + 1 %]
                                            <li><a name="fn[% count %]">[% item %]</a></li>
                                        [% END %]
                                    </ol>
                                </div>
                            [% END %]

                            [% IF crossreferences.size %]
                                <div class="obml_crossreference">
                                    <div class="obml_crossreference_title">{Crossreferences}</div>
                                    <ol>
                                        [% count = 0 %]
                                        [% FOREACH item IN crossreferences %]
                                            [% count = count + 1 %]
                                            <li><a name="cr[% count %]">[% item.join('; ') %]</a></li>
                                        [% END %]
                                    </ol>
                                </div>
                            [% END %]
                    [% END %]
                </div>
            </div>
        },
        { content => $content },
        \$output,
    );

    $output =~ s/^\s+|\s+$//msg;

    return $output;
}

__PACKAGE__->meta->make_immutable;
1;
__END__
=pod
=head1 NAME

Bible::OBML::HTML - Render OBML as HTML

=head1 SYNOPSIS

    $self->from_obml($obml);
    $self->from_file($filename);
    $self->from_data($data);

    $self->from_obml( $obml,     $skip_smartify );
    $self->from_file( $filename, $skip_smartify );
    $self->from_data( $data,     $skip_smartify );

=head1 DESCRIPTION

This module renders a reasonably reusable HTML block from OBML in either text,
file, or data sources. "Reasonably reusable" means that it is a block of HTML
without header or "HTML" tag and contains HTML5-valid HTML, mostly in the form
of DIV tags and other symantically expected nested HTML.

The intent here is that if you have OBML and need to view it in some nicer form,
like on a web site, you can use this module's methods to generate a core block
of HTML, which you'd then wrap with whatever HTML wrapper and CSS you'd like.

=head1 METHODS

=head2 from_obml

This method accepts a string (assumed to contain valid OBML) and returns HTML.

    $self->from_obml($obml);

A second optional boolean can be provided, and if true, will cause the method
to skip running the "smartify" method on the content.

    $self->from_obml( $obml, 1 );

=head2 from_file

This method accepts a string containing a filename (the file is assumed to
contain valid OBML) and returns HTML.

    $self->from_file($filename);

A second optional boolean can be provided, and if true, will cause the method
to skip running the "smartify" method on the content.

    $self->from_file( $filename, 1 );

=head2 from_data

This method accepts a data structure that's a result of parsing OBML and
returns HTML.

    $self->from_data($data);

A second optional boolean can be provided, and if true, will cause the method
to skip running the "smartify" method on the content.

    $self->from_data( $data, 1 );

=head1 ATTRIBUTES

=head2 obml

This module has an attribute of "obml" which contains a reference to an
instance of L<Bible::OBML>.

=head1 SEE ALSO

L<Bible::OBML>, L<Bible::OBML::Reference>.

=head1 AUTHOR

Gryphon Shafer E<lt>gryphon@cpan.orgE<gt>.

    code('Perl') || die;

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
