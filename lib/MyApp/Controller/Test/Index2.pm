package MyApp::Controller::Test::Index2;

use UVW::Moose;
extends 'UVW::Action';

use MyApp::Form::Test;


sub get {
    my ($self, $app) = @_;

    my $form = MyApp::Form::Test->new;

    unless ($form->process(params => $app->req->parameters)) {
        return {FORM => $form};
    }
    else {
        return {MSG => 'validated!'};
    }
}

*post = \&get;

1;

__DATA__
[% IF MSG %]Message: [% MSG %][% END %]
[% IF FORM %][% FORM.render %][% END %]
