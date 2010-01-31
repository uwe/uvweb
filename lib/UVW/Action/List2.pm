package UVW::Action::List2;

use Moose::Role;

requires 'resultset';

sub get {
    my ($self, $app) = @_;

    my $initial = $self->get_initial_data($app);
    my $filter  = $self->get_filter_criteria($app);
    my $search  = $self->filter2search($app, $filter);
    my $page    = {page => $app->req->param('page') || 1,
                   rows => 15,
                  };
    my $rs      = $app->schema->resultset($self->resultset)->search($search, $page);

    my @data    = $rs->all;

    return {DATA   => \@data,
            PAGE   => $rs->pager,
            %$initial, %$filter,
           };
}

sub get_initial_data { {} }

sub get_filter_criteria {
    my ($self, $app) = @_;

    my $filters;
    foreach my $class ($self->meta->class_precedence_list) {
        $filters = eval { $class->meta->filter_list };
        last if $filters and @$filters;
    }
    return {} unless $filters;

    my %filter = ();
    foreach my $filter (@$filters) {
        my $name  = $filter->{name};
        my $value = $app->req->param($name) || $filter->{default} || '';
        $filter{$name} = $value;
    }

    return \%filter;
}

sub filter2search {
    my ($self, $app, $filter) = @_;

    return undef;
}

1;
