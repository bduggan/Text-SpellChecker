#########################

use utf8;
use Test::More tests => 9;
BEGIN { use_ok('Text::SpellChecker') };

my $checker = Text::SpellChecker->new(text => "Foor score and seevn yeers ago", lang => "en_US" );
ok($checker, 'object creation' );

SKIP: {
    skip 'Text::Aspell not installed', 4 unless $Text::SpellChecker::SpellersAvailable{Aspell};
    skip 'English dictionary not installed', 4 
        unless (grep /^en/, Text::Aspell->new()->list_dictionaries) &&
                Text::Aspell->new()->get_option('lang') =~ /^en/;

    ok($checker->next_word eq 'Foor', 'Catching English word');

    ok($checker->next_word eq 'seevn', 'Iterator');

    # we can call it two different ways
    my @suggestions = $checker->suggestions;
    my $suggestions = $checker->suggestions;
    ok( eq_array( \@suggestions, $suggestions), 'suggestions' );

    $checker->replace(new_word => 'seven');

    ok($checker->text =~ /score and seven/, 'replacement');

    my $text = "The coördinator will be leading the session";
    my $unichecker = Text::SpellChecker->new(text => $text );
    my @words = split / /, $text;
    my %words = map { $_ => 1 } @words;
    while (my $word = $unichecker->next_word) {
        ok $words{$word}, "$word is one of the words in $text" or diag explain [ $word, \%words];
    }
};

my $original = Text::SpellChecker->new(from_frozen => $checker->serialize);
my $nother = Text::SpellChecker->new_from_frozen($checker->serialize);

delete $checker->{aspell};
delete $checker->{hunspell};
ok(eq_hash($original,$checker),'freezing, thawing');
ok(eq_hash($nother,$checker),'freezing, thawing');

