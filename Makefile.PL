use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'             => 'Bible::OBML',
    'AUTHOR'           => 'Gryphon Shafer <gryphon@cpan.org>',
    'VERSION_FROM'     => 'lib/Bible/OBML.pm',
    'ABSTRACT_FROM'    => 'lib/Bible/OBML.pm',
    'PL_FILES'         => {},
    'MIN_PERL_VERSION' => '5.010',
    'PREREQ_PM'        => {
        'List::MoreUtils' => 0,
        'Moose'           => 0,
        'Template'        => 0,
        'Test::Moose'     => 0,
        'Test::Most'      => 0,
        'Text::Balanced'  => 0,
        'Text::Wrap'      => 0,
        'Throwable'       => 0,
    },
    'dist'  => { 'COMPRESS' => 'gzip -9f', 'SUFFIX' => 'gz' },
    'clean' => { 'FILES'    => 'Bible-OBML-*' },
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ( 'LICENSE' => 'perl' ) : () ),
    ( eval { ExtUtils::MakeMaker->VERSION(6.46) } ? ( 'META_MERGE' => {
        'meta-spec' => { version => 2 },
        'resources' => {
            'repository' => {
                'type' => 'git',
                'url'  => 'https://github.com/gryphonshafer/Bible-OBML.git',
                'web'  => 'https://github.com/gryphonshafer/Bible-OBML',
            },
        } } ) : ()
    ),
);
