package Modware::Role::Chado::Builder::BCS::Publication;

# Other modules:
use Moose::Role;
use aliased 'Modware::DataSource::Chado';
use aliased 'Modware::Publication::Author';
use Try::Tiny;
use Carp;
use Data::Dumper::Concise;
use namespace::autoclean;

# Module implementation
#

has 'dbrow' => (
    is        => 'rw',
    isa       => 'DBIx::Class::Row',
    predicate => 'has_dbrow',
    clearer   => '_clear_dbrow'
);

has 'cv' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => 'pub_type'
);

has 'db' => ( is => 'rw', isa => 'Str', lazy => 1, default => 'Pubmed' );

has 'dicty_cv' =>
    ( is => 'rw', isa => 'Str', default => 'dictyBase_literature_topic' );

sub _build_status {
    my $self = shift;
    return if !$self->has_dbrow;
    my $rs = $self->dbrow->search_related( 'pubprops',
        { 'type_id' => $self->cvterm_id_by_name('status') } );
    $rs->first->value if $rs;
}

sub _build_abstract {
    my ($self) = @_;
    return if !$self->has_dbrow;
    my $rs = $self->dbrow->search_related( 'pubprops',
        { 'type_id' => $self->cvterm_id_by_name('abstract') } );
    $rs->first->value if $rs->count > 0;
}

sub _build_title {
    my ($self) = @_;
    $self->dbrow->title if $self->has_dbrow;
}

sub _build_year {
    my ($self) = @_;
    $self->dbrow->pyear if $self->has_dbrow;
}

sub _build_source {
    my ($self) = @_;
    $self->dbrow->pubplace if $self->has_dbrow;
}

sub _build_authors {
    my ($self) = @_;
    my $collection = [];
    return $collection if !$self->has_dbrow;

    my $rs = $self->dbrow->pubauthors;

    #no authors for you
    return $collection if $rs->count == 0;

    while ( my $row = $rs->next ) {
        my $author = Author->new(
            id        => $row->pubauthor_id,
            rank      => $row->rank,
            is_editor => $row->editor,
            last_name => $row->surname,
            suffix    => $row->suffix
        );
        if ( $row->givennames =~ /^(\S+)\s+(\S+)$/ ) {
            $author->initials($1);
            $author->first_name($2);
        }
        else {
            $author->first_name( $row->givennames );
        }
        push @$collection, $author;
    }
    $collection;
}

sub _build_keywords_stack {
    my ($self) = @_;
    return [] if !$self->has_dbrow;
    my $rs = $self->dbrow->search_related(
        'pubprops',
        { 'cv.name' => $self->dicty_cv },
        { join      => { 'type' => 'cv' }, cache => 1 }
    );
    return [ map { $_->type->name } $rs->all ] if $rs->count > 0;
    return [];
}

1;    # Magic true value required at end of module

__END__