#!/usr/bin/perl

use strict;
use warnings;

use rlib;
use MyApp;


my $app = MyApp->new->psgi;
