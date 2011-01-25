#!/usr/bin/perl -w
use strict;
use inc::latest 'Module::Build';
use File::Spec::Functions;
use FindBin qw/$Bin/;
use File::Spec::Functions;
use lib 'lib';
use Modware::Build;

my $db_config      = catfile( $Bin, 't', 'data', 'config', 'database.yaml' );
my $file_config    = catfile( $Bin, 't', 'data', 'config', 'raw.yaml' );
my $fixture_config = catfile( $Bin, 't', 'data', 'config', 'preset.yaml' );

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
        'Bio::Root::Version'          => '1.0050021',
        'MooseX::Singleton'           => '0.22',
        'MooseX::Params::Validate'    => '0.14',
        'MooseX::Aliases'             => '0.08',
        'MooseX::Types'               => '0.22',
        'Path::Class'                 => '0.18',
        'aliased'                     => '0.30',
        'File::Path'                  => '2.08',
        'MooseX::Role::Parameterized' => '0.19',
        'Regexp::Common'              => '2.122',
        'MooseX::ClassAttribute'      => '0.13',
        'DBIx::Class::Helpers'        => '2.005000'
    },
    build_requires => {
        'ExtUtils::Depends'     => '0.302',
        'Test::More'            => '0.94',
        'DBIx::Class::Fixtures' => '1.001010',
        'YAML'                  => '0.70',
        'Archive::Tar'          => '1.66',
    },
    recommends => {
        'MooseX::App::Cmd'        => '0.06',
        'MooseX::ConfigFromFile'  => '0.02',
        'Email::Simple'           => '2.10',
        'Email::Sender::Simple'   => '0.102370',
        'Email::Valid'            => '0.184',
        'Log::Log4perl'           => '1.30',
        'XML::LibXML'             => '1.70',
        'GOBO'                    => '0.03',
        'Spreadsheet::WriteExcel' => '2.37',
        'Math::Base36'            => '0.07',
        'Math::BigInt'            => '1.89', 
        'File::Find::Rule' => '0.32'
    },
    configure_requires =>
        { 'Module::Load' => '0.16', 'File::Path' => '2.08' },
    add_to_cleanup => ['Modware-*'],
    get_options    => {
        dsn            => { type    => ':s' },
        user           => { type    => ':s' },
        password       => { type    => ':s' },
        profile        => { type    => ':s' },
        superuser      => { type    => ':s' },
        superpassword  => { type    => ':s' },
        loader         => { type    => ':s', default => 'preset' },
        name           => { type    => ':s', default => 'custom' },
        profile        => { type    => ':s', default => 'fallback' },
        load_fixture   => { type    => '!', default => 1 },
        create         => { type    => '!', default => 1 },
        drop           => { type    => '!', default => 1 },
        test_debug     => { type    => '!', default => 0 },
        post_ddl       => { type    => '!', default => 0 },
        db_config      => { default => $db_config, type => ':s' },
        file_config    => { default => $file_config, type => ':s' },
        fixture_config => { default => $fixture_config, type => ':s' },
        preset         => { default => 1, type => '!' },
        append_path => {
            default => catfile( 't', 'data', 'preset' ),
            type    => ':s'
        },
        default => {},
    },
    script_files => [
        'bin/ontology/load_ontology.pl', 'bin/ontology/drop_ontology.pl',
        'bin/ontology/gaf2chado.pl'
    ]
);

$build->args( 'ddl_dir', catdir( $build->base_dir, 't', 'data', 'ddl' ) );
$build->args( 'preset_file',
    catdir( $build->base_dir, 't', 'data', 'preset.tar.gz' ) );
$build->args( 'tmp_dir', catdir( 't', 'tmp' ) );
$build->args( 'config' => 'custom' );
$build->create_build_script;

1;

