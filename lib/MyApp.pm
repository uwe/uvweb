package MyApp;

use Moose;
extends 'UVW';

has '+default_index' => (default => '/test/index');

1;
