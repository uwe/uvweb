package MyApp::Controller::Test;

use UVW::Moose;
extends 'UVW::Controller';

has_route 'index' => (target => sub { return {MSG => 'index ok'} },
                     );

1;

__DATA__
__[index]__
Message: [% MSG %]
