package UVW;

use Moose;
use MooseX::HasDefaults::RO;

use Data::Section qw(-setup);
use File::Spec;
use Module::Find qw(useall usesub);
use Path::Router;
use Plack::Request;
use Template;
use URI;

use UVW::Session;


has router => (default => sub { Path::Router->new });

has [qw/controller action redirect_list/] => (default => sub { {} });

has default_index      => (default => '/index');
has template_path      => (default => 'template');
has template_extension => (default => '.tt2');

has tt2 => (lazy_build => 1);

has req     => (is      => 'rw',
                isa     => 'Plack::Request',
                handles => [qw/param/],
               );

has match   => (is      => 'rw',
                isa     => 'Path::Router::Route::Match',
                handles => [qw/mapping/],
               );

has session => (is      => 'rw',
                isa     => 'UVW::Session',
                lazy    => 1,
                default => sub { UVW::Session->new },
               );

sub _build_tt2 {
    my ($self) = @_;

    my %config = (INCLUDE_PATH => $self->template_path,
                  POST_CHOMP   => 1,
                 );

    #my $header = $self->section_data('header');
    #my $footer = $self->section_data('footer');
    #$config{PRE_PROCESS}  = $header if $header;
    #$config{POST_PROCESS} = $footer if $footer;

    $config{PRE_PROCESS}  = 'header' . $self->template_extension;
    $config{POST_PROCESS} = 'footer' . $self->template_extension;

    return Template->new(\%config) or die Template->error;
}

sub BUILD {
    my ($self) = @_;

    my $redirect = $self->redirect_list;
    $redirect->{''} = $self->default_index;

    # load controller
    foreach my $controller (usesub(ref($self) . '::Controller')) {
        # ignore _... classes
        next if $controller =~ /::_/;

        $self->controller->{$controller->name} = $controller;

        my $router = Path::Router->new;

        # load actions
        foreach my $action (useall($controller)) {
            # ignore _... classes
            next if $action =~ /::_/;

            my $name = $action;
            $name =~ s/^${controller}:://;
            $name =~ s|::|-|g;
            $name = lc $name;

            my $path = $controller->name .'/'. $name;

            $self->action->{$path} = $action;

            my $route_list = $action->meta->route_list;
            if (@$route_list) {
                while (@$route_list) {
                    my $route = shift @$route_list;
                    my $args  = shift @$route_list;

                    # add controller and action
                    $args->{defaults}->{controller} = $controller->name;
                    $args->{defaults}->{action}     = $name;

                    # add template
                    $args->{defaults}->{template} ||= $path;

                    $router->add_route($name.'/'.$route, %$args);
                }
            }
            else {
                # add default route (action name)
                $router->add_route($name,
                                   defaults => {controller => $controller->name,
                                                action     => $name,
                                                template   => $path,
                                               },
                                  );
            }
        }

        my $route_list = $controller->meta->route_list;
        while (@$route_list) {
            my $route = shift @$route_list;
            my $args  = shift @$route_list;

            # we need a target for intra-controller routes
            die "No target in $controller"
                unless $args->{target};

            # add controller
            $args->{defaults}->{controller} = $controller->name;

            # add template
            ###TODO### security hole?
            (my $name = $route) =~ s|/|-|g;
            $args->{defaults}->{template} ||= $name;

            $router->add_route($route, %$args);
        }

        my $prefix = $controller->prefix;
        if ($prefix) {
            $self->router->include_router("$prefix/" => $router);
            $redirect->{$prefix} = $prefix . '/' . $controller->default_action;
        } else {
            $self->router->include_router('', $router);
        }
    }
}

sub psgi {
    my ($self) = @_;

    return sub { $self->psgi_handler(@_) };
}

sub psgi_handler {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);

    # set request object
    $self->req($req);

    my $path = $req->path;

    # check for redirects
    my $r_path = $path;
    $r_path =~ s|^/||;
    $r_path =~ s|/$||;

    my $match = $self->router->match($path);

    unless ($match) {
        # check redirect table
        if (my $url = $self->redirect_list->{$r_path}) {
            return $self->redirect($url);
        }

        return $req->new_response(404)->finalize;
    }

    $self->match($match);

    my @result     = ();
    my $mapping    = $match->mapping;
    my $controller = $self->controller->{$mapping->{controller}};
    my $template;
    my $template_name = $mapping->{template};

    if ($match->route->has_target) {
        @result = $match->target->($self);

        my $section_data = $controller->merged_section_data;
        if ($section_data and $mapping->{template}) {
            $template = $section_data->{$mapping->{template}};
        }
    }
    else {
        my $name   = $mapping->{controller} . '/' . $mapping->{action};
        my $action = $self->action->{$name};

        my $method = lc $req->method;

        return $req->new_response(409)->finalize
            unless $action->can($method);

        @result = $action->$method($self);

        $template_name = $name;

        # embedded template?
        my $section_data = $action->merged_section_data;
        # single template in action?
        if ($section_data and $section_data->{_}) {
            $template = $section_data->{_};
        }
        # named template in controller?
        elsif ($section_data = $controller->merged_section_data) {
            $template = $section_data->{$mapping->{action}};
        }
    }

    # redirect?
    unless (ref $result[0]) {
        return $self->redirect(@result);
    }

    # file download?
    if (ref($result[0]) eq 'ARRAY') {
        my ($ctype, $body, $file) = @{shift @result};
        my $res = $req->new_response(200);
        $res->content_type($ctype);
        $res->header('Content-disposition', 'attachment; filename='.$file)
            if $file;
        $res->body($body);
        return $res->finalize;
    }

    # file system template overrides all
    if ($template_name) {
        my $file = File::Spec->catfile($controller->template_path,
                                       $template_name,
                                      );
        if (-f $file) {
            $template = $file;
        }
        elsif (-f $file . $self->template_extension) {
            $template = $file . $self->template_extension;
        }
    }

    # variables
    my $vars = $result[0] || {};
    $vars->{UVW} ||= $self;

    my $body = '';
    $self->tt2->process($template, $vars, \$body) or die $self->tt2->error;

    my $res = $req->new_response(200);
    $res->content_type('text/html');
    $res->body($body);
    return $res->finalize;
}

sub uri_for {
    my ($self, $data, $param) = @_;

    unless (ref $data) {
        if ($data !~ m|/|) {
            # local action
            $data = {controller => $self->mapping->{controller},
                     action     => $data,
                    };
        } else {
            my ($controller, $action) = split /\//, $data;

            $data = {controller => $controller,
                     action     => $action,
                    };
        }
    }

    # add controller and action
    if ($data->{controller}) {
        unless ($data->{action}) {
            # add default action
            my $controller = $self->controller->{$data->{controller}};
            $data->{action} = $controller->default_action;
        }
    } else {
        # controller missing
        $data->{controller} = $self->mapping->{controller};
        $data->{action}   ||= $self->mapping->{action};
    }

    my $path = $self->router->uri_for(%$data) or return;

    return "/$path" unless $param;

    my $uri = URI->new("/$path");
    $uri->query_form($param);

    return $uri->as_string;
}

sub redirect {
    my ($self, $path) = @_;
    my $req = $self->req;

    # avoid double slashes
    $path =~ s|^/|| if $req->base =~ m|/$|;

    my $res = $req->new_response;
    $res->redirect($req->base . $path);

    return $res->finalize;
}

1;
