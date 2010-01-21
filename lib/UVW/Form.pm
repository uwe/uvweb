package UVW::Form;

use Moose;

has 'name' => (is  => 'rw',
               isa => 'Str',
              );

has 'method' => (is      => 'rw',
                 isa     => 'Str',
                 default => 'post',
                );

has 'fields' => (is  => 'rw',
                 isa => 'ArrayRef[UVW::Field]',
                );

1;
