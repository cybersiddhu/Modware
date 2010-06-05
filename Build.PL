#!/usr/bin/perl -w
use strict;
use inc::latest 'Module::Build';
use lib ( 'lib', 't/lib' );
use ModwareX::Build;

my $build = ModwareX::Build->new(
    module_name   => 'ModwareX',
    license       => 'perl',
    dist_author   => 'Siddhartha Basu <siddhartha-basu@northwestern.edu>',
    dist_version  => '0.01',
    dist_abstract => 'API for chado database',
    requires      => {
        'Try::Tiny'                 => '',
        'Bio::Chado::Schema'        => '0.05',
        'Log::Log4perl'             => '',
        'YAML'                      => '',
        'local::lib'                => '1.004008',
        'Bio::Root::Version'        => '1.0050021',
        'Module::Load::Conditional' => '',
        'Moose'                     => '0.96',
        'MooseX::Singleton'         => '0.22',
        'MooseX::Params::Validate'  => '0.14',
        'MooseX::Aliases'           => '0.08',
        'MooseX::Types'             => '0.22',
        'Path::Class'               => '0.18'
    },
    add_to_cleanup => ['ModwareX-*'],
    create_readme  => 1,
    get_options => {
    	dsn => { type => ':s' }, 
    	user => { type => ':s' }, 
    	password => { type => ':s' }
    }
);

$build->create_build_script;

1;

