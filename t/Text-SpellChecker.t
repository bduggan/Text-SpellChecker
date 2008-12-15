#########################

use Test::More tests => 7;
BEGIN { use_ok('Text::SpellChecker') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $checker = Text::SpellChecker->new(text => "Foor score and seevn yeers ago");
ok($checker, 'object creation' );

SKIP: {
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
};

my $original = Text::SpellChecker->new(from_frozen => $checker->serialize);

delete $checker->{aspell};  # 'cause the freezing don't carry over
                            # the Text::Aspell object
ok(eq_hash($original,$checker),'freezing, thawing');

