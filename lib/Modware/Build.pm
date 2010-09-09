package Modware::Build;
use base qw/Module::Build/;
use lib 'blib/lib';
use Test::Chado;
use File::Spec::Functions;
use Module::Load;
use File::Path qw/make_path remove_tree/;

__PACKAGE__->add_property('chado');
__PACKAGE__->add_property('handler');

my @feature_list = qw/setup_done is_db_created is_schema_loaded
    is_fixture_loaded/;

sub db_handler {
    my ($self) = @_;
    my $handler;
    my $chado = Test::Chado->new( file_config => $self->args('file_config') );

    if ( my $dsn = $self->args('dsn') )
    {    #means the db credentials are passed on the command line
        $handler = $chado->handler_from_build($self);
    }
    else {    # db crendentials should be loaded from database profile
        $chado->db_config( $self->args('db_config') );
        $chado->base_path( $self->base_dir );
        $chado->append_path( $self->args('append_path') );
        $handler = $chado->handler_from_profile( $self->args('profile') );
    }
    $self->config_data( dsn      => $handler->dsn );
    $self->config_data( user     => $handler->user );
    $self->config_data( password => $handler->password );
    $self->chado($chado);
    $self->handler($handler);
}

sub check_and_setup {
    my ($self) = @_;
    die "no profile name given\n" if !$self->args('name');
    my $name = $self->args('name');
    $self->action_profile($name) if $name;
}

sub common_setup {
    my ($self) = @_;
    my $path = catdir( $self->base_dir, 't', 'tmp' );
    make_path($path) if !-e $path;
}

sub ACTION_setup {
    my $self = shift;
    $self->depends_on('build');
    load 'Modware::ConfigData';
    if ( $self->handler ) {
        return;
    }
    print "running setup\n" if $self->args('test_debug');
    $self->common_setup;
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
    $self->depends_on('deploy');
    if ( !Modware::ConfigData->feature('is_fixture_loaded') ) {
        $self->handler->load_organism;
        $self->handler->load_rel;
        $self->handler->load_so;
        $self->handler->load_pub;
        $self->handler->load_journal_data;
        $self->feature( 'is_fixture_loaded' => 1 );
        print "loaded fixture\n" if $self->args('test_debug');
    }
}

sub ACTION_unload_rel {
    my ($self) = @_;
    $self->common_setup;
    $self->db_handler;
    $self->handler->unload_rel;
}

sub ACTION_unload_pub {
    my ($self) = @_;
    $self->common_setup;
    $self->db_handler;
    $self->handler->unload_pub;
}

sub ACTION_unload_so {
    my ($self) = @_;
    $self->common_setup;
    $self->db_handler;
    $self->handler->unload_so;
}

sub ACTION_unload_fixture {
    my ($self) = @_;
    $self->depends_on('setup');
    if ( Modware::ConfigData->feature('is_fixture_loaded') ) {
        $self->handler->unload_rel;
        $self->handler->unload_so;
        $self->handler->unload_pub;
        $self->handler->unload_organism;
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
    $self->depends_on('drop') if $self->args('drop');
    my $dir = catdir( 't', 'tmp' );
    remove_tree( $dir ) if -e $dir;
}

sub ACTION_unload_organism {
    my ($self) = @_;
    $self->common_setup;
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
        $self->feature( $name => 0 ) if $self->args($name);
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

#Setup with a profile 

 perl Build.PL --profile myprofile --dsn "dbi:Oracle:sid=mysid" --user user --password mypass --default;

 ./Build list_profiles;

 ./Build show_profile; 

 ./Build deploy_schema;

 ./Build load_fixture;

 ./Build drop_schema;

 ./Build add_profile --name mymod --dsn "dbi:Pg:database=mygmod" --user myuser --password mypassword;

 ./Build deploy_schema --name mygmod;


 #setup with custom config file and profiles
 
 perl Build.PL --config_file "~/.myconfig.yaml" --profile myprofile --default;


=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
Write a separate section listing the public components of the modules
interface. These normally consist of either subroutines that may be
exported, or methods that may be called on objects belonging to the
classes provided by the module.

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back


=head1 DIAGNOSTICS

=for author to fill in:
List every single error and warning message that the module can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
A full explanation of any configuration system(s) used by the
module, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be set. These descriptions must also include details of any
configuration language used.

<MODULE NAME> requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
A list of all the other modules that this module relies upon,
  including any restrictions on versions, and an indication whether
  the module is part of the standard Perl distribution, part of the
  module's distribution, or must be installed separately. ]

  None.


  =head1 INCOMPATIBILITIES

  =for author to fill in:
  A list of any modules that this module cannot be used in conjunction
  with. This may be due to name conflicts in the interface, or
  competition for system or program resources, or due to internal
  limitations of Perl (for example, many modules that use source code
		  filters are mutually incompatible).

  None reported.


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

  [Write stuff here]

  =item *

  [Write stuff here]

  =back


  =head1 AUTHOR

  I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>


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



