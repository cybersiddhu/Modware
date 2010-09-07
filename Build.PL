#!/usr/bin/perl -w
use strict;
use inc::latest 'Module::Build';
use File::Spec::Functions;
use FindBin qw/$Bin/;
use lib 'lib/';
use lib 't/lib/';
use Modware::Build;

my $db_config   = catfile( $Bin, 't', 'data', 'config', 'database.yaml' );
my $file_config = catfile( $Bin, 't', 'data', 'config', 'original.yaml' );
my $build = Modware::Build->new(
    module_name    => 'Modware',
    license        => 'perl',
    create_readme  => 1,
    create_license => 1,
    dist_abstract =>
        'A GMOD L<http://gmod.org> middleware toolkit for Chado L<http://gmod.org/wiki/Chado> relational database.',
    requires => {
        'Try::Tiny'                   => '0.03',
        'Bio::Chado::Schema'          => '0.05800',
        'Log::Log4perl'               => '1.21',
        'YAML'                        => '0.70',
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
    get_options    => {
        dsn           => { type    => ':s' },
        user          => { type    => ':s' },
        password      => { type    => ':s' },
        profile       => { type    => ':s' },
        superuser     => { type    => ':s' },
        superpassword => { type    => ':s' },
        loader        => { type    => ':s', default => 'bcs' },
        name          => { type    => ':s', default => 'custom' },
        profile       => { type    => ':s', default => 'fallback' },
        load_fixture  => { type    => '!', default => 1 },
        create        => { type    => '!', default => 1 },
        drop          => { type    => '!', default => 1 },
        test_debug    => { type    => '!', default => 0 },
        db_config     => { default => $db_config, type => ':s' },
        file_config   => { default => $file_config, type => ':s' },
        default => {},
    }
);

#$build->config_data( 'base_dir' => $build->base_dir );
$build->create_build_script;

1;

