#########################

use Test::More tests => 6;
BEGIN { use_ok('Text::SpellChecker') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $checker = Text::SpellChecker->new(text => "Foor score and seevn yeers ago");
ok($checker, 'object creation' );

ok($checker->next_word eq 'Foor', 'Catching English word');

ok($checker->next_word eq 'seevn', 'Iterator');

$checker->replace(new_word => 'seven');

ok($checker->text =~ /score and seven/, 'replacement');

my $original = Text::SpellChecker->new(from_frozen => $checker->serialize);

ok(eq_hash($original,$checker),'freezing, thawing');

