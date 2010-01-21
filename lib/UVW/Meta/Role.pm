package UVW::Meta::Role;

use Moose::Role;

has [qw/route_list
        field_list
        filter_list/] => (is      => 'rw',
                          isa     => 'ArrayRef',
                          default => sub { [] },
                         );

sub add_to_route_list {
    my ($meta, $name, %arg) = @_;

    push @{$meta->route_list}, $name, \%arg;
}

sub add_to_field_list {
    my ($meta, $name, %arg) = @_;

    my $class = 'UVW::Field';
    my %param = ();
    # capital name -> custom (named) field
    if ($name =~ /^[A-Z]/) {
        if ($meta->name =~ /^(.+)?::(Runmode|CRUD)::/) {
            $class = join('::', $1, 'Field', $name);
        } else {
            die "Unknown field '$name'";
        }
    } else {
        $param{name} = $name;
    }

    push @{$meta->field_list}, $class->new({%param, %arg});
}

sub add_to_filter_list {
    my ($meta, $name, %arg) = @_;

    $arg{name} ||= $name;

    push @{$meta->filter_list}, \%arg;
}

use namespace::autoclean;

1;
