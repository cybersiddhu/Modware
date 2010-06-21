package Modware::Chado::Writer::BCS::AlignedPair;

use version; our $VERSION = qv('1.0.0');

# Other modules:
use Moose::Role;
use MooseX::Aliases;
use Modware::DataSource::Chado;
use Modware::Chado::Reader::RelationShip;
use Carp qw/confess/;

# Module implementation
#
requires 'organism';
requires 'hit', 'query', 'subject';
requires 'analysis_name', 'analysis_description', 'program', 'version';
requires 'create_analysis';

has 'chadowriter' => (
    is      => 'ro',
    isa     => 'Modware::DataSource::Chado',
    lazy    => 1,
    handles => [qw/handler/],
);

has 'relationship' => (
    is      => 'ro',
    isa     => 'Modware::Chado::Reader::RelationShip',
    lazy    => 1,
    handles => qr/^\S+/,
);

has 'subject_type' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => 'match',
);

has 'subject_type_row' => (
    is      => 'ro',
    isa     => 'Bio::Chado::Schema::Cv::Cvterm',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->handler->resultset('Cvterm')->find(
            {   'name'      => $self->subject_type,
                'cv . name' => 'sequence',
            },
            { join => 'cv' },
        );
    },

);

has 'hsp_type' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => 'match_part',
);

has 'hsp_type_row' => (
    is      => 'ro',
    isa     => 'Bio::Chado::Schema::Cv::Cvterm',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->handler->resultset('Cvterm')->find(
            {   'name'      => $self->hsp_type,
                'cv . name' => 'sequence',
            },
            { join => 'cv' },
        );
    },

);

has 'alignment_rows' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Bio::Chado::Schema::Sequence::Feature]',
    default => sub { [] },
    handles => {
        each_alignment_row => 'elements',
        add_alignment_row  => 'push',
        num_alignment      => 'count',
        has_alignment      => 'count',
        get_alignment      => 'get',
    },
);

has 'analysis_record' => (
    is        => 'ro',
    isa       => 'Bio::Chado::Schema::CompAnalysis::Analysis',
    predicate => 'has_analysis',
);

before 'create_analysis' => sub {
    my ($self) = @_;
    $self->algorithm( $self->hit->algorithm );
};

has 'query_type' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        if ( $self->has_query ) {
            return $self->query->primary_tag;
        }
    },
);

has 'query_type_row' => (
    is      => 'ro',
    isa     => 'Bio::Chado::Schema::Cv::Cvterm',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->handler->resultset('Cvterm')->find(
            {   'name'      => $self->query_type,
                'cv . name' => 'sequence',
            },
            { join => 'cv' },
        );
        }

);

has 'subject_row' => (
    is  => 'rw',
    isa => 'Bio::Chado::Schema::Sequence::Feature',
);

has 'organism_row' => (
    is      => 'ro',
    isa     => 'Bio::Chado::Schema::Organism::Organism',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $name = $self->organism;
        return $self->handler->resultset('Organism')->find(
            {   -or => [
                    abbreviation => $name,
                    species      => $name,
                    common_name  => $name,
                ],
            }
        );
    }
);

has 'dbrow' => (
    is      => 'ro',
    isa     => 'Bio::Chado::Schema::General::Db',
    lazy    => 1,
    default => sub {
        my $self   = shift;
        my $source = $self->handler->resultset('Db')
            ->find_or_create( { name => $self->source } );
    },
);

has 'source' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => 'GFF_source'
);

sub uniquename {
    my ($self) = @_;
    return sprintf "%s_%s_%s", $self->query->seq_id, $self->subject->seq_id,
        $self->subject_type;
}

sub query_name {
    my ($self) = @_;
    my ($query_ann)
        = $self->query->annotation->get_Annotations('description');
    return $query_ann->value;
}

sub subject_name {
    my ($self) = @_;
    my ($sub_ann)
        = $self->subject->annotation->get_Annotations('description');
    return $sub_ann->value;
}

before 'create' => sub {
    my ($self) = @_;
    $self->analysis_record( $self->create_analysis ) if !$self->has_analysis;
    confess 'no organism name given: record cannot be created'
        if !$self->has_organism;
};

around 'create' => sub {
    my $orig        = shift;
    my $self        = shift;
    my $subject_row = $self->handler->resultset('Feature')->find(
        {   -or => [
                'uniquename'       => $self->subject->seq_id,
                'name'             => $self->subject->seq_id,
                'dbxref.accession' => $self->subject->seq_id,
            ],

        },
        { join => 'dbxref' },
    );

    return if !$subject_row;
    $self->subject_row($subject_row);
    $self->$orig(@_);

};

sub create {
    my ($self) = @_;

    my $query_row = $self->handler->resultset('Feature')->create(
        {   dbxref => {
                accession   => $self->query->seq_id,
                description => $self->query_name,
                db_id       => $self->source->db_id,
            },
            organism_id => $self->organism_row->organism_id,
            name        => $self->query_name,
            uniquename  => $self->query->seq_id,
            type_id     => $self->query_type_row->cvterm_id,
        }
    );

    my $hit_row = $self->handler->resultset('Feature')->create(
        {   organism_id      => $self->organism_row->organism_id,
            name             => $self->subject_name,
            uniquename       => $self->uniquename,
            type_id          => $self->subject_type_row->cvterm_id,
            analysisfeatures => [
                {   analysis_id  => $self->analysis_record->analysis_id,
                    rawscore     => $self->alignment->raw_score,
                    normscore    => $self->alignment->score,
                    significance => $self->alignment->significance,
                },
            ],
        }
    );

    while ( my $hsp = $self->alignment->next_hsp() ) {
        my $hsp_row = $self->handler->resultset('Feature')->create(
            {   organism_id => $self->organism_row->organism_id,
                type_id     => $self->hsp_type_row->cvterm_id,
                name        => sprintf "%s-%s",
                $self->query_name,
                $self->subject_name,
                uniquename => sprintf "%s_%d..%d::%d..%d",
                $self->uniquename,
                $hsp->start('query'),
                $hsp->end('query'),
                $hsp->start('subject'),
                $hsp->end('subject'),
                analysisfeatures => [
                    {   analysis_id  => $self->analysis_record->analysis_id,
                        rawscore     => $hsp->score,
                        normscore    => $hsp->score,
                        significance => $hsp->significance,
                        identity     => $hsp->percent_identity,
                    },
                ],
                feature_relationship_subject_ids => [
                    {   type_id   => $self->part_of_id,
                        object_id => $hit_row->feature_id,
                    },
                ],
                featureloc_feature_ids => [
                    {   srcfeature_id => $query_row->feature_id,
                        fmin          => $self->query->start - 1,
                        fmax          => $self->query->end,
                        strand        => $self->query->strand,
                        rank          => 1,
                    },
                    {   srcfeature_id => $self->subject_row->feature_id,
                        fmin          => $self->subject->start - 1,
                        fmax          => $self->subject->end,
                        strand        => $self->subject->strand,
                        rank          => 0,

                    },
                ],

            }
        );
    }

}

sub delete {
    my ($self) = @_;
    return if !$self->has_alignment;

    #get the query and hit record from db and delete them
    my $hsp_row = $self->get_alignment(0);
    my $query_row = $hsp_row->featureloc_feature_ids( { rank => 1, } )
        ->first->srcfeature;
    my $hit_row = $hsp_row->feature_relationship_subject_ids(
        { type_id => $self->part_of_id, } )->first->object;
    $query_row->delete();
    $hit_row->delete();
    $_->delete() for $self->each_alignment_row;

}

alias 'save'   => 'create';
alias 'insert' => 'create';
alias 'remove' => 'delete';

1;    # Magic true value required at end of module

__END__

=head1 NAME

<Modware::Chado::Writer::SimilarityPair> - [Moose role for writing SimilarityPair object
to chado source]


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

    = for author to fill in
    : A list of any modules that this module cannot be used in conjunction
    with . This may be due to name conflicts in the interface,
    or competition
    for system
    or program resources,
    or due to internal limitations of Perl(
    for example,
    many modules that use source code filters are mutually incompatible
    )
    .

    None reported .

    = head1 BUGS AND LIMITATIONS

    = for author to fill in : A list of known problems with the module,
    together with some indication Whether they are likely to be fixed in an
    upcoming release
    . Also a list of restrictions on the features the module does provide
    : data types that cannot be handled, performance issues
    and the circumstances in which they may arise,
    practical limitations on the size of data sets,
    special cases that are not(yet) handled, etc
    .

    No bugs have been reported . Please report any bugs
    or feature requests to dictybase @northwestern . edu

    = head1 TODO

    = over

    = item *

    [ Write stuff here ]

    = item *

    [ Write stuff here ]

    = back

    = head1 AUTHOR

    I <Siddhartha Basu> B <siddhartha-basu@northwestern.edu>

    = head1 LICENCE AND COPYRIGHT

    Copyright(c) B <2003>, Siddhartha Basu C
    <<siddhartha-basu @northwestern . edu >> . All rights reserved .

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



