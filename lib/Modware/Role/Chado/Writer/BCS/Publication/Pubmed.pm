package Modware::Role::Chado::Writer::BCS::Publication::Pubmed;

# Other modules:
use Moose::Role;
use Carp;
use namespace::autoclean;

# Module implementation
#

has 'pub_dbxref_map' => (
    is      => 'ro',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    handles => {
        all_pub_dbxrefs => 'keys',
        get_pub_dbxref  => 'get'
    },
    default => sub {
        { 'Medline' => 'medline_id', 'DOI' => 'doi' };
    }
);

sub _build_pubmed_id {
    my ($self) = @_;
    $self->_build_id if $self->has_dbrow;
}

sub _build_medline_id {
    my ($self) = @_;
    return if !$self->has_dbrow;
    $self->db2accession('Medline');

}

sub _build_doi {
    my ($self) = @_;
    return if !$self->has_dbrow;
    $self->db2accession('DOI');
}

sub _build_full_text_url {
    my ($self) = @_;
    return if !$self->has_dbrow;
    my $rs = $self->dbrow->search_related( 'pubprops',
        { 'type_id' => $self->cvterm_id_by_name('website') } );
    $rs->first->value if $rs->count > 0;

}

sub db2accession {
    my ( $self, $db_name ) = @_;
    my $rs
        = $self->dbrow->search_related( 'pub_dbxrefs', {} )->search_related(
        'dbxref',
        { 'db.name' => $db_name },
        { join      => 'db' }
        );
    $rs->first->accession if $rs->count > 0;
}

before 'create' => sub {
    my ($self) = @_;
    ## -- data validation
    croak "pubmed id is not given\n" if !$self->has_pubmed_id;

    my $pub = $self->pub;
    $pub->uniquename( $self->pubmed_id );

    if ( $self->has_full_text_url ) {
        $pub->add_to_pubprops(
            {   type_id => $self->cvterm_id_by_name('website'),
                value   => $self->full_text_url
            }
        );
    }

    for my $key ( $self->all_pub_dbxrefs ) {
        my $val    = $self->get_pub_dbxref($key);
        my $method = 'has_' . $val;
        $pub->add_to_pub_dbxrefs(
            {   dbxref => {
                    accession => $self->$val,
                    db_id     => $self->db_id_by_name($key)
                }
            }
        ) if $self->$method;
    }
};

before 'update' => sub {
    my $self = shift;

    #initialize chado handler first
    my $chado = $self->chado if !$self->has_chado;

    my $pub = $self->pub;
    $pub->reset;
    if ( $self->has_pubmed_id
        and ( $self->pubmed_id ne $self->dbrow->uniquename ) )
    {
        $pub->uniquename( $self->pubmed_id );
    }

    for my $key ( $self->all_pub_dbxrefs ) {
        my $val    = $self->get_pub_dbxref($key);
        my $method = 'has_' . $val;
        if ( $self->$method ) {
            my $row = $chado->resultset('General::Dbxref')->search(
                {   accession => $self->$val,
                    db_id     => $self->db_id_by_name($key)
                },
                { rows => 1 }
            )->single;
            if ($row) {
                $pub->add_to_pub_dbxref(
                    {   accession => $self->$val,
                        dbxref_id => $row->dbxref_id,
                        db_id     => $self->db_id_by_name($key)
                    }
                );
            }
            else {
                $pub->add_to_pub_dbxref(
                    {   accession => $self->$val,
                        db_id     => $self->db_id_by_name($key)
                    }

                );
            }
        }
    }

    if ( $self->has_full_text_url ) {
        $pub->add_to_pubprops(
            {   type_id => $self->cvterm_id_by_name('website'),
                value   => $self->full_text_url,
                rank    => 0
            }
        );
    }

};

1;    # Magic true value required at end of module

__END__

=head1 NAME

<MODULE NAME> - [One line description of module's purpose here]


=head1 VERSION

This document describes <MODULE NAME> version 0.0.1


=head1 SYNOPSIS

use <MODULE NAME>;

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



