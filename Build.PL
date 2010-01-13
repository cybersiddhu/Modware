#!/usr/bin/perl -w
use strict;
use warnings;
use lib '.';
use Module::Build;

my $builder = Module::Build->new(
    module_name  => 'ModwareX',
    license      => 'perl',
    dist_author  => 'Siddhartha Basu <siddhartha-basu@northwestern.edu>',
    dist_version => '0.01',
    dist_abstract => 'API for chado database', 
    requires     => {
        'Try::Tiny' => '', 
        'Bio::Chado::Schema' => '0.05', 
        'Log::Log4perl' => '', 
        'YAML' => '' 
    },
    add_to_cleanup => ['ModwareX-*'],
    create_readme  => 1,
);

$builder->create_build_script();


1;
