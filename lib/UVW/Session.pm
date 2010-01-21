package UVW::Session;

use strict;
use warnings;


sub new {
    my ($class) = @_;
    my $self = bless {}, $class;

    return $self;
}

sub get {}
sub set {}
sub delete {}

1;
