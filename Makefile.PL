use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Text::SpellChecker',
    VERSION_FROM      => 'lib/Text/SpellChecker.pm', 
    PREREQ_PM         => {
        'Text::Aspell' => '0.04',
        'Storable' => '1',
        'MIME::Base64' => '1'
                         }, 
    ($] >= 5.005 ?   
      ( AUTHOR         => 'Brian Duggan <bduggan@matatu.org>') : ()),
);
