package MyApp::Form::Test;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

with 'HTML::FormHandler::Render::Table';

has_field title   => (type => 'Text',    required => 1);
has_field rating  => (type => 'Integer', required => 1);
has_field submit  => (type => 'Submit');

no HTML::FormHandler::Moose;

1;
