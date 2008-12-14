=head1 NAME

Text::SpellChecker - OO interface for spell-checking a block of text

=head1 SYNOPSIS

    use Text::SpellChecker;
    ($Text::SpellChecker::pre_hl_word,
     $Text::SpellChecker::post_hl_word) = (qw([ ]));

    my $checker = Text::SpellChecker->new(text => "Foor score and seven yeers ago");

    while (my $word = $checker->next_word) {
        print $checker->highlighted_text, 
            "\n", 
            "$word : ",
            (join "\t", @{$checker->suggestions}),
            "\nChoose a new word : ";
        chomp (my $new_word = <STDIN>);
        $checker->replace(new_word => $new_word) if $new_word;
    }

    print "New text : ".$checker->text."\n";

--or-- 

    use CGI;
    use Text::SpellChecker;
    my $q = new CGI;
    print $q->header,
          $q->start_html,
          $q->start_form(-method=>'POST',-action=>$ENV{SCRIPT_NAME});

    my $checker = Text::SpellChecker->new(
        text => "Foor score and seven yeers ago",
        from_frozen => $q->param('frozen') # will be false the first time.
    ); 

    $checker->replace(new_word => $q->param('replacement')) 
        if $q->param('replace');

    if (my $word = $checker->next_word) {
        print $q->p($checker->highlighted_text),
            $q->br, 
            qq|Next word : "$word"|, 
            $q->br,
            $q->submit(-name=>'replace',-value=>'replace with:'),
            $q->popup_menu(-name=>'replacement',-values=>$checker->suggestions),
            $q->submit(-name=>'skip');
    } else {
        print "Done.  New text : ".$checker->text;
    }

    print $q->hidden(-name => 'frozen',
                     -value => $checker->serialize,
                     -override => 1), 
          $q->end_form, 
          $q->end_html;


=head1 DESCRIPTION

This module is built on Text::Aspell, but adds some of the functionality 
provided by the internal gnu aspell API.  This allows one to deal with blocks 
of text, rather than just words.  For instance, we provide methods for
iterating through the text, serializing the object (thus remembering where
we left off), and highlighting the current misspelled word within the
text.

=head1 METHODS

=over 4

=item $checker = Text::SpellChecker->new(text => $text, from_frozen => $serialized_data, lang => $lang)

Send either the text or a serialized object to the constructor.  
Optionally, the language of the text can also be passed.

=item $checker = new_from_frozen($serialized_data)

This is provided separately, so that it may be
overridden for alternative serialization techniques.

=item $str=$checker->serialize

Represent the object in its current state.

=item $checker->reset

Reset the checker to the beginning of the text, and clear the list of ignored words.

=item $word = $checker->next_word

Returns the next misspelled word.

=item $checker->current_word

Returns the most recently returned word.

=item $checker->replace(new_word => $word)

Replace the current word with $word.

=item $checker->ignore_all

Ignore all subsequent occurences of the current word.

=item $checker->replace_all(new_word => $new_word)

Replace all subsequent occurences of the current word with a new word.

=item $checker->suggestions

Returns a reference to a list of alternatives to the
current word in a scalar context, or the list directly
in a list context.

=item $checker->text

Returns the current text (with corrections that have been
applied).

=item $checker->highlighted_text

Returns the text, but with the current word surrounded by $Text::SpellChecker::pre_hl_word and
$Text::SpellChecker::post_hl_word.

=back

=head1 TODO

Add word to custom dictionary

=head1 SEE ALSO

Text::Aspell

=head1 AUTHOR

Brian Duggan <bduggan@matatu.org>

=cut

package Text::SpellChecker;
use Carp;
use Text::Aspell;
use Storable qw(freeze thaw);
use MIME::Base64;
use warnings;
use strict;

our $VERSION = 0.04;

our $pre_hl_word = qq|<span style="background-color:red;color:white;font-weight:bold;">|;
our $post_hl_word = "</span>";

#
# new
#
# parameters :
#   text : the text we're checking
#   from_frozen : serialized class data to use instead of using text
#
sub new {
    my ($class,%args) = @_;
    return $class->new_from_frozen($args{from_frozen}) if $args{from_frozen};
    bless {
            text => $args{text},
            ignore_list => {},    # keys of this hash are words to be ignored
            ( lang => $args{lang} ) x !!$args{lang},
    }, $class;
}

sub reset {
    my $self = shift;
    $self->{position} = undef;
    $self->{ignore_list} = {};
}

# Ignore all remaining occurences of the current word.

sub ignore_all {
    my $self = shift;
    my $word = $self->current_word or croak "Can't ignore all : no current word";
    $self->{ignore_list}{$word} = 1;
}

# Replace all remaining occurences with the given word

sub replace_all {
    my ($self,%args) = @_;
    my $new_word = $args{new_word} or croak "no replacement given";
    my $current = $self->current_word;
    $self->replace(new_word => $new_word);
    my $saved_position = $self->{position};
    while (my $next = $self->next_word) {
         next unless $next eq $current;
         $self->replace(new_word => $new_word);
    }
    $self->{position} = $saved_position;
}

#
# new_from_frozen
#
# Alternative handy constructor using serialized object.
#
sub new_from_frozen {
    my $self = shift;
    my $frozen = shift;
    $self = thaw(decode_base64($frozen)) or croak "Couldn't unthaw $frozen";
    return $self;    
}

#
# next_word
# 
# Get the next misspelled word. 
# Returns false if there are no more.
#
sub next_word {
    my $self = shift;
    pos $self->{text} = $self->{position};
    my $word;
    my $sp = $self->_aspell;
    while ($self->{text} =~ m/([a-zA-Z]+(?:'[a-zA-Z]+)?)/g) {
        $word = $1;
        next if $self->{ignore_list}{$word};
        last if !$sp->check($word);
    }
    unless ($self->{position} = pos($self->{text})) {
        $self->{current_word} = undef;
        return undef;
    }
    $self->{suggestions} = [ $sp->suggest($word) ];
    $self->{current_word} = $word;
    return $word;
}

#
# Private method returning a Text::Aspell object
#
sub _aspell {
    my $self = shift;

    unless ( $self->{aspell} ) {
        $self->{aspell} = Text::Aspell->new;
        $self->{aspell}->set_option( lang => $self->{lang} ) 
                if $self->{lang};
    }

    return $self->{aspell};
}

#
# replace - replace the current word with a new one.
#
# parameters :
#   new_word - the replacement for the current word
#
sub replace {
    my ($self,%args) = @_;
    my $new_word = $args{new_word} or croak "no replacement given";
    my $word = $self->current_word or croak "can't replace with $new_word : no current word";
    $self->{position} -= length($word); # back up : we'll recheck this word, but that's okay.
    substr($self->{text},$self->{position},length($word)) = $new_word;
}

#
# highlighted_text
# 
# Get the text with the current misspelled word highlighted.
#
sub highlighted_text {
    my $self = shift;
    my $word = $self->current_word;
    return $self->{text} unless ($word and $self->{position});
    my $text = $self->{text};
    substr($text,$self->{position} - length($word),length($word)) = "$pre_hl_word$word$post_hl_word";
    return $text;
}

#
# Some accessors
#
sub text         { return $_[0]->{text}; }
sub suggestions  { 
    return unless $_[0]->{suggestions};
    return wantarray 
                ? @{$_[0]->{suggestions}} 
                :   $_[0]->{suggestions} 
                ;  
}
sub current_word { return $_[0]->{current_word};  }

#
# Handy serialization method.
#
sub serialize {
   my $self = shift;

   # remove mention of Aspell object, if any
   my %copy = %$self;
   delete $copy{aspell};

   return encode_base64 freeze \%copy;
}
 

1;

