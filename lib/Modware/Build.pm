package Modware::Build;
use base qw/Module::Build/;
use lib 'blib/lib';
use Test::Chado;
use File::Spec::Functions;
use Module::Load;
use Data::Dumper::Concise;
use Archive::Tar;
use File::Path qw/make_path remove_tree/;
use File::Basename;

__PACKAGE__->add_property('chado');
__PACKAGE__->add_property('handler');
__PACKAGE__->add_property( 'tar' => Archive::Tar->new );

my @feature_list = qw/setup_done is_db_created is_schema_loaded
    is_fixture_loaded/;

sub connect_hash {
    my $self = shift;
    my %hash;
    for my $param (qw/dsn user password/) {
        $hash{$param} = $self->config_data($param)
            if $self->config_data($param);
    }
    $hash{attr} = $self->config_data('db_attr')
        if $self->config_data('db_attr');
    return %hash;
}

sub check_oracle {
    my ($self) = @_;
    ## -- this whole thing is for working with Oracle
    ## -- loading preset fixture does not work because of LOB field
    return if !$self->args('dsn');
    load DBI;
    my ( $scheme, $driver ) = DBI->parse_dsn( $self->args('dsn') );
    if ( $driver eq 'Oracle' ) {
        $self->args( 'preset',   0 );
        $self->args( 'post_ddl', 1 );
        return 1;
    }
}

sub db_handler {
    my ($self) = @_;
    my $handler;
    my $chado = Test::Chado->new;
    $chado->module_builder($self);

    if ( $self->args('preset') ) {    #load from preset fixture - the default
        $chado->file_config( $self->args('fixture_config') );
        $chado->append_path( $self->args('append_path') );
        $self->feature( preset => 1 );
    }
    else {                            #load from data file
        $chado->file_config( $self->args('file_config') );
        $chado->append_path( catdir( 't', 'data', 'raw' ) );
        $self->args( 'loader', 'bcs' );
    }

    if ( my $dsn = $self->args('dsn') )
    {    #means the db credentials are passed on the command line
        if ( $self->check_oracle ) {
            $chado->file_config( $self->args('file_config') );
            $chado->append_path( catdir( 't', 'data', 'raw' ) );
            $self->args( 'loader', 'bcs' );
        }
        $handler = $chado->handler_from_options;
    }
    else {    # db crendentials should be loaded from database profile
        $chado->db_config( $self->args('db_config') );
        $chado->base_path( $self->base_dir );
        $handler = $chado->handler_from_profile( $self->args('profile') );
    }

    $self->config_data( dsn      => $handler->dsn );
    $self->config_data( user     => $handler->user );
    $self->config_data( password => $handler->password );
    $self->config_data( db_attr  => $handler->attr_hash );
    $self->chado($chado);
    $self->handler($handler);
    if ( $self->args('superuser') ) {
        $handler->superuser( $self->args('superuser') );
        $handler->superpassword( $self->args('superpassword') );
    }

}

sub check_and_setup {
    my ($self) = @_;
    die "no profile name given\n" if !$self->args('name');
    my $name = $self->args('name');
    $self->action_profile($name) if $name;
}

sub ACTION_create_tmp {
    my ($self) = @_;
    my $path = $self->args('tmp_dir');
    make_path($path) if !-e $path;
}

sub ACTION_cleanup_tmp {
    my $self = shift;
    my $path = $self->args('tmp_dir');
    remove_tree($path) if -e $path;
}

sub ACTION_setup {
    my $self = shift;
    $self->depends_on('build');
    load 'Modware::ConfigData';
    if ( $self->handler ) {
        return;
    }
    print "running setup\n" if $self->args('test_debug');
    $self->depends_on('create_tmp');
    $self->db_handler;
    $self->feature( 'setup_done' => 1 );
    print "done with setup\n" if $self->args('test_debug');
}

sub ACTION_create {
    my ($self) = @_;
    $self->depends_on('setup');
    if ( !Modware::ConfigData->feature('is_db_created') ) {
        $self->handler->create_db;
        $self->feature( 'is_db_created' => 1 );
        print "created database\n" if $self->args('test_debug');
    }
}

sub ACTION_deploy {
    my ($self) = @_;
    $self->depends_on('create');
    if ( !Modware::ConfigData->feature('is_schema_loaded') ) {
        $self->handler->deploy_schema;
        $self->feature( 'is_schema_loaded' => 1 );
        print "loaded schema\n" if $self->args('test_debug');
    }
}

sub ACTION_deploy_schema {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->feature( 'is_db_created' => 1 );
    if ( !Modware::ConfigData->feature('is_schema_loaded') ) {
        $self->handler->deploy_schema;
        $self->feature( 'is_schema_loaded' => 1 );
        print "loaded schema\n" if $self->args('test_debug');
    }
}

sub ACTION_load_organism {
    my ($self) = @_;
    $self->depends_on('deploy');
    $self->handler->load_organism;
}

sub ACTION_load_rel {
    my ($self) = @_;
    $self->depends_on('deploy');
    $self->handler->load_rel;
}

sub ACTION_load_so {
    my ($self) = @_;
    $self->depends_on('rel');
    $self->handler->load_so;
}

sub ACTION_load_pub {
    my ($self) = @_;
    $self->depends_on('load_rel');
    $self->handler->load_pub;
}

sub ACTION_load_publication {
    my ($self) = @_;
    $self->depends_on('load_pub');
    $self->handler->load_journal_data;
}

sub ACTION_load_fixture {
    my ($self) = @_;
    $self->check_oracle;
    if ( $self->args('preset') ) {
        $self->depends_on('setup');
        $self->tar->read( $self->args('preset_file') );
        chdir $self->args('tmp_dir');
        $self->tar->extract;
        chdir $self->base_dir;
        $self->handler->load_fixture;
        $self->feature( 'is_fixture_loaded' => 1 );
        print "loaded preset fixture\n" if $self->args('test_debug');
    }
    else {
        $self->depends_on('deploy');
        if ( !Modware::ConfigData->feature('is_fixture_loaded') ) {
            $self->handler->load_organism;
            $self->handler->load_rel;
            $self->handler->load_so;
            $self->handler->load_pub;
            $self->handler->load_journal_data;
            $self->handler->load_dicty_keywords;
            $self->feature( 'is_fixture_loaded' => 1 );
            print "loaded fixture\n" if $self->args('test_debug');
        }
    }
    if ( $self->args('post_ddl') ) {
        $self->handler->deploy_post_schema;
        print "loaded post ddl\n" if $self->args('test_debug');
    }

}

sub ACTION_unload_rel {
    my ($self) = @_;
    $self->db_handler;
    $self->handler->unload_rel;
}

sub ACTION_unload_pub {
    my ($self) = @_;
    $self->db_handler;
    $self->handler->unload_pub;
}

sub ACTION_unload_so {
    my ($self) = @_;
    $self->db_handler;
    $self->handler->unload_so;
}

sub ACTION_unload_fixture {
    my ($self) = @_;
    if ( $self->args('preset') ) {
        warn "Action not supported in preset mode\n";
        die "Try prune_fixture\n";
    }
    $self->depends_on('setup');
    if ( Modware::ConfigData->feature('is_fixture_loaded') ) {
        $self->handler->unload_rel;
        $self->handler->unload_so;
        $self->handler->unload_pub;
        $self->handler->unload_organism;
        $self->handler->unload_dicty_keywords;
        $self->feature( 'is_fixture_loaded'   => 0 );
        $self->feature( 'is_fixture_unloaded' => 1 );
    }
}

sub ACTION_prune_fixture {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->handler->prune_fixture;
    $self->feature( 'is_fixture_loaded'   => 0 );
    $self->feature( 'is_fixture_unloaded' => 1 );

}

sub ACTION_test {
    my ($self) = @_;

    #cleanup all the setup values if any
    for my $name (@feature_list) {
        print "cleaning $name\n" if $self->args('test_debug');
        $self->feature( $name => 0 );
    }
    $self->depends_on('drop');
    $self->depends_on('load_fixture');
    $self->recursive_test_files(1);

    $self->SUPER::ACTION_test(@_);
    $self->depends_on('drop');
    $self->depends_on('cleanup_tmp');
}

sub ACTION_unload_organism {
    my ($self) = @_;
    $self->db_handler;
    $self->handler->unload_organism;
}

sub ACTION_drop {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->handler->drop_db;

    #cleanup all the setup values if any
    for my $name (@feature_list) {
        print "cleaning $name\n" if $self->args('test_debug');
        $self->feature( $name => 0 );
    }
    print "dropped the database\n" if $self->args('test_debug');
}

sub ACTION_drop_schema {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->handler->drop_schema;
    $self->feature( 'is_schema_loaded' => 0 );
}

sub ACTION_list_fixtures {
    my ($self) = @_;
    $self->depends_on('setup');
    my $fixture = $self->handler->fixture;
    print ref $fixture->organism, "\n";
    print $fixture->organism->taxon_file, "\n";
    print $fixture->pub->journal_file,    "\n";
}

sub ACTION_list_args {
    my $self = shift;
    my $args = $self->args;
    print Dumper $args;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Build> - [Module::Build actions for loading test fixtures in chado database]


=head1 VERSION

This document describes <MODULE NAME> version 0.1


=head1 SYNOPSIS

#In your Build.PL

use Modware::Build;

my $build = Modware::Build->new(....);

$build->create_build_script;

#Default behaviour
 perl Build.PL;
  ./Build deploy;
  ./Build load_fixture;
  ./Build unload_fixture;
   ./Build drop;

#Other setup
 perl Build.PL  --dsn "dbi:Pg:database=mydb" --user user --password pass

./Build deploy_schema;

./Build load_fixture;

./Build unload_fixture;

./Build drop_schema;


=head1 DESCRIPTION

It is a L<Module::Build> subclass which provides and overrides some default action to load
predefined text fixtures to a test chado instances. At this point it is designed to work
with testing setup of L<Modware> distribution.

=head2 How it works

By default,  just an B<./Build test> is sufficient. It deploys a sqlite instance of
chado database,  load the text fixture,  run the tests and drop it afterwards.

=head3 Test data

There are two forms of identical test dataset that could be loaded. One is the preset
fixtures created by B<DBIx::Class::Fixtures> and the other is the original data files. The
fixtures are actually created by loading those data files in the database and then dumping
them in the prescribed format by B<DBIx::Class::Fixtures>. Default is to load from the
preset fixtures.

=head3 Test dataset location


=head3 Test database target

The default is sqlite,  however other RDBMS Oracle,  MySQL and PostgreSQL are also tested
and could be used for testing. They can be specified in the command line in any of the
B<Build> target. In that case three options are mandatory ....

=over

=item * dsn

=item * user

=item * password

=back

Do make sure the credentials should have enough privileges to create and drop the
test database from the specified target.


=head1 INTERFACE 

=head2 ACTION_test

=over

=item B<Use:> ./Build test

=item B<Functions:> Runs the tests. Overall,  it deploys a test database,  loads the test
fixture,  runs the test on it and then wipe out the database.

It implies the following sequential Build action before the tests are run....

=over

=item create

=item deploy

=item load_fixture

=back

After the tests were run,  it executes the B<drop> action.

=item B<Args:> 

Look at L<Test database target> section. 

B<--test_debug>: Prints completion of various Build action. 

=back


=head1 DIAGNOSTICS

=for author to fill in:
List every single error and warning message that the module can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies.

=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
A full explanation of any configuration system(s) used by the
module, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be set. These descriptions must also include details of any
configuration language used.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
  A list of known problems with the module, together with some
  indication Whether they are likely to be fixed in an upcoming
  release. Also a list of restrictions on the features the module
  does provide: data types that cannot be handled, performance issues
  and the circumstances in which they may arise, practical
  limitations on the size of data sets, special cases that are not
  (yet) handled, etc.

No bugs have been reported.Please report any bugs or feature requests to
dictybase@northwestern.edu


=head1 TODO

=over

=item *

Allow to setup a profile for multiple test databases.



=head1 LICENCE AND COPYRIGHT

 Copyright (c) B<2003>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

  BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
  FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
  OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
  PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
  EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
  ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
  YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
  NECESSARY SERVICING, REPAIR, OR CORRECTION.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
  WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
  REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
  LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
  OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
  THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
		  RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
		  FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
  SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGES.



