package UVW::Controller;

use UVW::Moose;

use Data::Section -setup => {default_name => '_'};

sub default_action { 'index' }

sub name {
    my ($class_or_self) = @_;

    my $class = ref($class_or_self) || $class_or_self;
    if ($class =~ m/::Controller::([^:]+)/) {
        my $name = $1;
        $name =~ s/::/-/g;
        $name = lc $name;

        return $name;
    }

    die "Could not obtain name from class '$class'";
}

sub template_path { return (shift)->name }

sub prefix {
    my ($class_or_self) = @_;

    my $class = ref($class_or_self) || $class_or_self;
    if ($class =~ m/::Controller::([^:]+)/) {
        my $name = $1;
        $name =~ s|::|/|g;
        $name = lc $name;

        return $name;
    }

    die "Could not obtain name from class '$class'";
}

1;
