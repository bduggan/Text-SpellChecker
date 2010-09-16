use ExtUtils::MakeMaker;

my $speller = "Text::Aspell";

eval { require Text::Hunspell };
$speller = "Text::Hunspell" unless $@;

WriteMakefile(
    NAME              => 'Text::SpellChecker',
    VERSION_FROM      => 'lib/Text/SpellChecker.pm', 
    PREREQ_PM         => {
        $speller       => 0,
        'Storable'     => 0,
        'MIME::Base64' => 0
    },
    LICENSE            => 'perl',
    ($] >= 5.005 ?   
      ( AUTHOR         => 'Brian Duggan <bduggan@matatu.org>') : ()),
);
