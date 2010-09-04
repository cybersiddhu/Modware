#!/usr/bin/perl -w
use strict;
use inc::latest 'Module::Build';
use File::Spec::Functions;
use FindBin qw/$Bin/;
use lib ( 'lib', 't/lib' );
use Modware::Build;

my $db_config      = catfile( $Bin, 't', 'config', 'database.yaml' );
my $fixture_config = catfile( $Bin, 't', 'config', 'fixture.yaml' );
my $build          = Modware::Build->new(
    module_name   => 'Modware',
    license       => 'perl',
    dist_author   => 'Siddhartha Basu <siddhartha-basu@northwestern.edu>',
    dist_version  => '0.01',
    dist_abstract => 'API for chado database',
    requires      => {
        'Try::Tiny'                   => '',
        'Bio::Chado::Schema'          => '0.05',
        'Log::Log4perl'               => '',
        'YAML'                        => '',
        'local::lib'                  => '1.004008',
        'Bio::Root::Version'          => '1.0050021',
        'Module::Load::Conditional'   => '',
        'MooseX::Singleton'           => '0.22',
        'MooseX::Params::Validate'    => '0.14',
        'MooseX::Aliases'             => '0.08',
        'MooseX::Types'               => '0.22',
        'Path::Class'                 => '0.18',
        'aliased'                     => '0.30',
        'File::Path'                  => '2.08',
        'Test::Most'                  => '0.22',
        'MooseX::Role::Parameterized' => '0.19'
    },
    add_to_cleanup => ['Modware-*'],
    create_readme  => 1,
    get_options    => {
        dsn            => { type    => ':s' },
        user           => { type    => ':s' },
        password       => { type    => ':s' },
        config_file    => { default => $db_config, type => ':s' },
        fixture_config => { default => $fixture_config, type => ':s' },
        profile        => { type    => ':s' },
        superuser      => { type    => ':s' },
        superpassword  => { type    => ':s' },
        'load-fixture' => { type    => '!', default => 1 },
        create         => { type    => '!', default => 1 },
        drop           => { type    => '!', default => 1 },
        test_debug     => { type    => '!', default => 0 },
        default => {},
    }
);

$build->config_data( 'base_dir' => $build->base_dir );
$build->create_build_script;

1;

