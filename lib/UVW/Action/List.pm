package UVW::Action::List;

use Moose::Role;

requires 'manager';

sub get {
    my ($self, $app) = @_;

    my $initial = $self->get_initial_data($app);
    my $filter  = $self->get_filter_criteria($app);
    my $rose    = $self->filter2rose($app, $filter);
    my $max     = $self->get_count($app, $rose);
    my $page    = $self->get_paging_criteria($app, $max);
    my $data    = $self->get_objects($app, $rose, $page);

    return {DATA => $data, %$initial, %$filter, %$page};
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

sub filter2rose {
    my ($self, $app, $filter) = @_;

    return {};
}

sub get_count {
    my ($self, $app, $rose) = @_;

    return $self->manager->get_objects_count(%$rose);
}

sub get_paging_criteria {
    my ($self, $app, $max) = @_;

    my $offset = $app->req->param('offset') || 0;
    my $limit  = $app->req->param('limit')  || 15;

    $limit =  10 if $limit <  10;
    $limit = 100 if $limit > 100;

    if ($offset >= $max) {
        $offset = $max - $limit - 1;
    }
    $offset = 0 if $offset < 0;

    my %page = (max    => $max,
                limit  => $limit,
                offset => $offset,

                prev   => $offset - $limit,
                next   => $offset + $limit,
                start  => $offset + 1,
                end    => $offset + $limit,
               );
    $page{prev} = 0       if $page{prev} <  0;
    $page{next} = $offset if $page{next} >= $max;
    $page{end}  = $max    if $page{end}  >  $max;

    return \%page;
}

sub get_objects {
    my ($self, $app, $rose, $page) = @_;

    $rose->{limit}  = $page->{limit};
    $rose->{offset} = $page->{offset};

    return $self->manager->get_objects(%$rose);
}

1;
