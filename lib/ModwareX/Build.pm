package ModwareX::Build;
use base qw/Module::Build/;
use Test::Chado;
use FindBin qw/$Bin/;
use File::Spec::Fuctions;

__PACKAGE__->add_property('handler');
__PACKAGE__->add_property('chado');
__PACKAGE__->add_property( 'default_profile' => 'fallback' );
__PACKAGE__->add_property('running_profile');
__PACKAGE__->add_property(
    'config',
    sub {
        catfile( $Bin, 't', 'config', 'database.yaml' );
    }
);

sub db_handler {
    my ($self) = @_;
    my $handler;
    my $chado = Test::Chado->new;
    if ( $self->action_profile ) {
        $handler = $chado->handler_from_profile( $self->action_profile );
    }
    elsif ( my $dsn = $self->args('dsn') ) {
        $handler = $chado->handler;
        $handler->dsn($dsn);
        $handler->user( $self->args('user') );
        $handler->password( $self->args('password') );
        my $loader = $self->args('loader') ? $self->args('loader') : 'bcs';
        $handler->loader($loader);
        $handler->name('custom');
    }
    else {
        $chado = Test::Chado->new( config => $self->args('config') );
        if ( my $profile = $self->args('profile') ) {
            if ( $self->args('default') ) {
                $self->default_profile( $self->args('profile') );
                $handler
                    = $chado->handler_from_profile( $self->args('profile') );
            }
            else {
                $handler
                    = $chado->handler_from_profile( $self->default_profile );
            }
        }
    }
    $self->handler($handler);
    $self->chado($chado);
}

sub ACTION_list_profile {
    my ($self) = @_;
    $self->db_handler;
    my $chado = $self->chado;
    for my $section ( keys %{ $chado->sections } ) {
        print $section, "\n--------\n";
        print "\tdsn: ",    $section->{dsn},    "\n";
        print "\tloader: ", $section->{loader}, "\n";
        print "\tuser: ", $section->{user}, "\n" if defined $section->{user};
        print "\tpassword ", $section->{password}, "\n"
            if defined $section->{password};
    }
    print "\n";
}

sub ACTION_add_profile {
    my ($self) = @_;
    die "no profile name given\n" if !$self->args('name');
    my $config
        = $self->args('config') ? $self->args('config') : $self->config;
    my $chado = Test::Chado->new( config => $config );
    $chado->add_to_config(
        $self->args('name'),
        {   dsn           => $self->args('dsn'),
            user          => $self->args('user'),
            password      => $self->args('password'),
            superuser     => $self->args('superuser'),
            superpassword => $self->args('superpassword'),
        }
    );
    $chado->save_config;
}

sub ACTION_remove_profile {
    my ( $self, $profile ) = @_;
    die "no profile name given\n" if !$profile;
    my $config
        = $self->args('config') ? $self->args('config') : $self->config;
    my $chado = Test::Chado->new( config => $config );
    $chado->delete_config($profile);
    $chado->save_config;
}

sub ACTION_show_profile {
    my ( $self, $name ) = @_;
    die "no profile name given\n" if !$name;
    my $config
        = $self->args('config') ? $self->args('config') : $self->config;
    my $chado = Test::Chado->new( config => $config );
    my $profile = $chado->get_value($name);
    if ( !$profile ) {
        print "no profile with $name\n";
        return;
    }
    print "\tdsn: ",    $profile->{dsn},    "\n";
    print "\tloader: ", $profile->{loader}, "\n";
    print "\tuser: ",   $profile->{user},   "\n" if defined $profile->{user};
    print "\tpassword ", $profile->{password}, "\n"
        if defined $profile->{password};
}

sub ACTION_create {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $handler->create_db;
}

sub ACTION_deploy {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    $self->depends_on('create');
    $self->handler->deploy_schema;
}

sub ACTION_deploy_schema {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $handler->deploy_schema;
}

sub ACTION_load_organism {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->load_organism;
}

sub ACTION_load_rel {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->load_rel;
}

sub ACTION_load_so {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->load_so;
}

sub ACTION_load_pub {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->load_pub;
}

sub ACTION_load_fixture {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->load_organism;
    $handler->load_rel;
    $handler->load_so;
    $handler->load_pub;
}

sub ACTION_unload_rel {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->unload_rel;
}

sub ACTION_unload_pub {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->unload_pub;
}

sub ACTION_unload_so {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->unload_so;
}

sub ACTION_unload_fixture {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->unload_rel;
    $handler->unload_so;
    $handler->unload_pub;
    $handler->unload_organism;
}

sub ACTION_unload_organism {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $self->handler($handler);
    $handler->unload_organism;
}

sub ACTION_drop {
    my ( $self, $profile ) = @_;
    $self->action_profile($profile) if $profile;
    my $handler = $self->db_handler;
    $handler->drop_db;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<ModwareX::Build> - [Module::Build actions for loading test fixtures in chado database]


=head1 VERSION

This document describes <MODULE NAME> version 0.1


=head1 SYNOPSIS

#In your Build.PL

use ModwareX::Build;

my $build = ModwareX::Build->new(....);

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

 perl Build.PL --profile myprofile --dsn "dbi:Oracle:sid=mysid" --user user --password
 mypass --default;

 ./Build list_profiles;

 ./Build show_profile; 

 ./Build deploy_schema;

 ./Build load_fixture;

 ./Build drop_schema;

 ./Build add_profile --name mymod --dsn "dbi:Pg:database=mygmod" --user myuser --password
 mypassword 

 ./Build deploy_schema mygmod


 #setup with custom config file and profiles


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



