package UVW::Moose;

use Moose;
use Moose::Exporter;
use Moose::Util::MetaRole;
use UVW::Meta::Role;

Moose::Exporter->setup_import_methods
    (
     with_meta => [qw/has_route has_field has_filter/],
     also      => 'Moose',
    );

sub init_meta {
    my ($class, %arg) = @_;

    Moose->init_meta(%arg);
    my $meta = Moose::Util::MetaRole::apply_metaclass_roles
        (
         for_class       => $arg{for_class},
         metaclass_roles => ['UVW::Meta::Role'],
        );

    return $meta;
}

sub has_route  { (shift)->add_to_route_list(@_) }
sub has_field  { (shift)->add_to_field_list(@_) }
sub has_filter { (shift)->add_to_filter_list(@_) }

use namespace::autoclean;

1;
