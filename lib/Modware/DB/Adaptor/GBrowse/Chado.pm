
=head1 NAME

Modware::DB::Adaptor::GBrowse::Chado - ModwareBase specific adaptor for DAS-style access to a chado database

=head1 SYNOPSIS

# Open up a feature database
 $db    = Modware::DB::Adaptor::GBrowse::Chado->new();

  @segments = $db->segment(-name  => '2L',
                           -start => 1,
			   -end   => 1000000);

  # segments are Bio::Das::SegmentI - compliant objects

  # fetch a list of features
  @features = $db->features(-type=>['type1','type2','type3']);

  # invoke a callback over features
  $db->features(-type=>['type1','type2','type3'],
                -callback => sub { ... }
		);


  # get all feature types
  @types   = $db->types;

  # count types
  %types   = $db->types(-enumerate=>1);

  @feature = $db->get_feature_by_name($class=>$name);
  @feature = $db->get_feature_by_target($target_name);
  @feature = $db->get_feature_by_attribute($att1=>$value1,$att2=>$value2);
  $feature = $db->get_feature_by_id($id);

  $error = $db->error;

=head1 DESCRIPTION

Modware::Adaptor::GBrowse::Chado provides ModwareBase customisation for
Bio::DB::Das::Chado object.

=head1 AUTHOR - Yulia Bushmanova

Email y-bushmanova@northwestern.edu

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

package Modware::DB::Adaptor::GBrowse::Chado;
use strict;

use Modware::DB::Adaptor::GBrowse::Segment;
use Bio::Root::Root;
use Bio::DasI;
use Bio::PrimarySeq;
use Bio::DB::GFF::Typename;

use DBIx::Connector;
use Bio::Chado::Schema;

#use DBI::Profile;
use Carp qw(croak confess longmess);
use base qw(Bio::Root::Root Bio::DasI);
use vars qw($VERSION @ISA);

use constant SEGCLASS => 'Modware::DB::Adaptor::GBrowse::Segment';
use constant MAP_REFERENCE_TYPE => 'MapReferenceType';    #dgg
use constant DEBUG              => 0;

=head2 new

 Title   : new
 Usage   : $db = Modware::DB::Adaptor::GBrowse::Chado();

 Function: Open up a Bio::DB::DasI interface to a Chado database. 
 Returns : a new Modware::DB::Adaptor::GBrowse::Chado object
 Args    : none

=cut

sub new {
    my $proto = shift;
    my $self = bless {}, ref($proto) || $proto;

    my %arg = @_;

    #  $dbh->{Profile} = "DBI::Profile";

    croak "database dsn parameter not given\n" if not defined $arg{'-dsn'};
    croak "database user not given\n"          if not defined $arg{'-user'};
    croak "database password not given\n" if not defined $arg{'-password'};

    my $schema = Bio::Chado::Schema->connect( $arg{'-dsn'}, $arg{'-user'},
        $arg{'-password'}, { LongReadLen => 2**25 } );

    my $conn = DBIx::Connector->new( $arg{'-dsn'}, $arg{'-user'},
        $arg{'-password'}, { LongReadLen => 2**25 } );
    $conn->mode('fixup');

    $self->schema($schema);
    $self->conn($conn);
    $self->dbh( $conn->dbh );

    # determine which cv to use for SO terms

    $self->sofa_id(1);

    warn "SOFA id to use: ", $self->sofa_id() if DEBUG;

    # get the cvterm relationships here and save for later use

    my $cvterm_query = "select ct.cvterm_id,ct.name as name, c.name as cvname
                           from cvterm ct, cv c
                           where ct.cv_id=c.cv_id and
                           (c.name IN (
                               'relationship',
                               'relationship type','Relationship Ontology',
                               'autocreated')
                            OR c.cv_id = " . $self->sofa_id() . ")";

    warn "cvterm query: $cvterm_query\n" if DEBUG;

    my $sth = $conn->run(
        sub {
            my $sth = $_->prepare($cvterm_query);
            $sth->execute;
            $sth;
        }
    );

    #or warn "unable to prepare select cvterms";
    #$sth->execute or $self->throw("unable to select cvterms");
    #  my $cvterm_id  = {}; replaced with better-named variables
    #  my $cvname = {};

    my ( %term2name, %name2term ) = ( {}, {} );
    my %termcv = ();

    while ( my $hashref = $sth->fetchrow_hashref("NAME_lc") ) {
        $term2name{ $hashref->{cvterm_id} } = $hashref->{name};
        $termcv{ $hashref->{cvterm_id} }    = $hashref->{cvname};    # dgg

#this addresses a bug in gmod_load_gff3 (Scott!), which creates a 'part_of'
#term in addition to the OBO_REL one that already exists!  this will also
#help with names that exist in both GO and SO, like 'protein'.
# dgg: but this array is bad for callers of name2term() who expect scalar result
#    mostly want only sofa terms

        if ( defined( $name2term{ $hashref->{name} } ) )
        {    #already seen this name

            if ( ref( $name2term{ $hashref->{name} } ) ne 'ARRAY' )
            {    #already array-converted

                $name2term{ $hashref->{name} }
                    = [ $name2term{ $hashref->{name} } ];

            }

            push @{ $name2term{ $hashref->{name} } }, $hashref->{cvterm_id};

        }
        else {

            $name2term{ $hashref->{name} } = $hashref->{cvterm_id};

        }
    }

    $self->term2name( \%term2name );
    $self->name2term( \%name2term, \%termcv );

    #Recursive Mapping
    $self->recursivMapping(
        $arg{-recursivMapping} ? $arg{-recursivMapping} : 0 );

    $self->inferCDS( $arg{-inferCDS} ? $arg{-inferCDS} : 0 );
    $self->allow_obsolete(
        $arg{-allow_obsolete} ? $arg{-allow_obsolete} : 0 );

    if ( exists( $arg{-enable_seqscan} ) && !$arg{-enable_seqscan} ) {
        $self->dbh->do("set enable_seqscan=0");
    }

    $self->srcfeatureslice(
        $arg{-srcfeatureslice} ? $arg{-srcfeatureslice} : 0 );
    $self->do2Level( $arg{-do2Level} ? $arg{-do2Level} : 0 );

    if ( $arg{-organism} ) {
        $self->organism_id( $arg{-organism} );
    }

    #determine if all_feature_names view or table exist
    #$self->use_all_feature_names();

    return $self;
}

= head2 use_all_feature_names

      Title
    : use_all_feature_names Usage
    : $obj->use_all_feature_names() Function
    : set
    or return flag indicating that all_feature_names view is present Returns
    : 1
    if all_feature_names present, 0
        if not Args : to return the flag, none;
to set, 1

    = cut

    sub use_all_feature_names {
    my ( $self, $flag ) = @_;

    $self->{use_all_feature_names} = 0;
    return $self->{use_all_feature_names};
}

=head2 organism_id

  Title   : organism_id
  Usage   : $obj->organism_id()
  Function: set or return the organism_id
  Note    : If -organism is set when the Chado feature is instantiated, this method
            queries the database with the common name to cache the organism_id.
  Returns : the value of the id
  Args    : to return the flag, none; to set, the common name of the organism
  
=cut

sub organism_id {
    my $self          = shift;
    my $organism_name = shift;

    if ( !$organism_name ) {
        return $self->{'organism_id'};
    }

    my $org_query = $self->conn->run(
        sub {
            my $sth = $_->prepare(
                "SELECT organism_id FROM organism WHERE common_name = ?");
            $sth->execute($organism_name);
            $sth;
        }
    );
    my ($organism_id) = $org_query->fetchrow_array;
    if ($organism_id) {
        return $self->{'organism_id'} = $organism_id;
    }
    else {
        $self->warn(
            "organism query returned nothing--I don't know what to do");
    }
}

=head2 inferCDS

  Title   : inferCDS
  Usage   : $obj->inferCDS()
  Function: set or return the inferCDS flag
  Note    : Often, chado databases will be populated without CDS features, since
            they can be inferred from a union of exons and polypeptide features.
            Setting this flag tells the adaptor to do the inferrence to get
            those derived CDS features (at some small performance penatly).
  Returns : the value of the inferCDS flag
  Args    : to return the flag, none; to set, 1

=cut

sub inferCDS {
    my $self = shift;

    my $flag = shift;
    return $self->{inferCDS} = $flag if defined($flag);
    return $self->{inferCDS};
}

=head2 allow_obsolete

  Title   : allow_obsolete
  Usage   : $obj->allow_obsolete()
  Function: set or return the allow_obsolete flag
  Note    : The chado feature table has a flag column called 'is_obsolete'.  
            Normally, these features should be ignored by GBrowse, but
            the -allow_obsolete method is provided to allow displaying
            obsolete features.
  Returns : the value of the allow_obsolete flag
  Args    : to return the flag, none; to set, 1

=cut

sub allow_obsolete {
    my $self = shift;
    my $allow_obsolete = shift if defined(@_);
    return $self->{'allow_obsolete'} = $allow_obsolete
        if defined($allow_obsolete);
    return $self->{'allow_obsolete'};
}

=head2 sofa_id

  Title   : sofa_id 
  Usage   : $obj->sofa_id()
  Function: get or return the ID to use for SO terms
  Returns : the cv.cv_id for the SO ontology to use
  Args    : to return the id, none; to determine the id, 1

=cut

sub sofa_id {
    my $self = shift;
    return $self->{'sofa_id'} unless @_;

    my $query = "select cv_id from cv where name in (
                     'SOFA',
                     'Sequence Ontology Feature Annotation',
                     'sofa.ontology')";

    my $sth = $self->conn->run(
        sub {
            my $sth = $_->prepare($query);
            $sth->execute() or $self->throw("trying to find SOFA");
            $sth;
        }
    );

    my $data    = $sth->fetchrow_hashref("NAME_lc");
    my $sofa_id = $$data{'cv_id'};

    return $self->{'sofa_id'} = $sofa_id if $sofa_id;

    $query = "select cv_id from cv where name in (
                    'Sequence Ontology',
                    'sequence')";

    $sth = $self->conn->run(
        sub {
            my $sth = $_->prepare($query);
            $sth->execute() or $self->throw("trying to find SO");
            $sth;
        }
    );

    $data    = $sth->fetchrow_hashref("NAME_lc");
    $sofa_id = $$data{'cv_id'};

    return $self->{'sofa_id'} = $sofa_id if $sofa_id;

    $self->throw("unable to find SO or SOFA in the database!");
}

=head2 recursivMapping

  Title   : recursivMapping
  Usage   : $obj->recursivMapping($newval)
  Function: Flag for activating the recursive mapping (desactivated by default)
  Note    : When we have a clone mapped on a chromosome, the recursive mapping 
            maps the features of the clone on the chromosome.
  Returns : value of recursivMapping (a scalar)
  Args    : on set, new value (a scalar or undef, optional)

=cut

sub recursivMapping {
    my $self = shift;

    return $self->{'recursivMapping'} = shift if @_;
    return $self->{'recursivMapping'};
}

=head2 srcfeatureslice

  Title   : srcfeatureslice
  Usage   : $obj->srcfeatureslice
  Function: Flag for activating 
  Returns : value of srcfeatureslice
  Args    : on set, new value (a scalar or undef, optional)
  Desc    : Allows to use a featureslice of type featureloc_slice(srcfeat_id, int, int)
  Important : this and recursivMapping are mutually exclusives

=cut

sub srcfeatureslice {
    my $self = shift;
    return $self->{'srcfeatureslice'} = shift if @_;
    return $self->{'srcfeatureslice'};
}

=head2 do2Level

  Title   : do2Level
  Usage   : $obj->do2Level
  Function: Flag for activating the fetching of 2levels in segment->features
  Returns : value of do2Level
  Args    : on set, new value (a scalar or undef, optional)

=cut

sub do2Level {
    my $self = shift;
    return $self->{'do2Level'} = shift if @_;
    return $self->{'do2Level'};
}

=head2 dbh

  Title   : dbh
  Usage   : $obj->dbh($newval)
  Function:
  Returns : value of dbh (a scalar)
  Args    : on set, new value (a scalar or undef, optional)
  
=cut

sub dbh {
    my ( $self, $arg ) = @_;

    if ($arg) {
        $self->{dbh} = $arg;
        return;
    }
    return $self->{dbh};
}

sub conn {
    my ( $self, $conn ) = @_;

    if ($conn) {
        $self->{conn} = $conn;
        return;
    }
    return $self->{conn};
}

=head2 term2name

  Title   : term2name
  Usage   : $obj->term2name($newval)
  Function: When called with a hashref, sets cvterm.cvterm_id to cvterm.name 
            mapping hashref; when called with an int, returns the name
            corresponding to that cvterm_id; called with no arguments, returns
            the hashref.
  Note    : should be replaced by Bio::GMOD::Util->term2name
  Returns : see above
  Args    : on set, a hashref; to retrieve a name, an int; to retrieve the
            hashref, none.
            
=cut

sub term2name {
    my $self = shift;
    my $arg  = shift;

    if ( ref($arg) eq 'HASH' ) {
        return $self->{'term2name'} = $arg;
    }
    elsif ($arg) {
        return $self->{'term2name'}{$arg};
    }
    else {
        return $self->{'term2name'};
    }
}

=head2 name2term

  Title   : name2term
  Usage   : $obj->name2term($newval)
  Function: When called with a hashref, sets cvterm.name to cvterm.cvterm_id
            mapping hashref; when called with a string, returns the cvterm_id
            corresponding to that name; called with no arguments, returns
            the hashref.
  Note    : Should be replaced by Bio::GMOD::Util->name2term
  Returns : see above
  Args    : on set, a hashref; to retrieve a cvterm_id, a string; to retrieve
            the hashref, none.

=cut

sub name2term {
    my $self    = shift;
    my $arg     = shift;
    my $cvnames = shift;

    if ( ref($cvnames) eq 'HASH' ) { $self->{'termcvs'} = $cvnames; }
    if ( ref($arg) eq 'HASH' ) {
        return $self->{'name2term'} = $arg;
    }
    elsif ($arg) {
        return $self->{'name2term'}{$arg};
    }
    else {
        return $self->{'name2term'};
    }
}

=head2 segment

 Title   : segment
 Note    : This method generates a Bio::Das::SegmentI object (see L<Bio::Das::SegmentI>).  
           The segment can be used to find overlapping features and the raw sequence.
           When making the segment() call, you specify the ID of a sequence landmark 
           (e.g. an accession number, a clone or contig), and a positional range 
           relative to the landmark.  If no range is specified, then the entire region 
           spanned by the landmark is used to generate the segment.
 Usage   : $db->segment(@args);
 Function: create a segment object
 Returns : list of Bio::Das::SegmentI objects.  If the method is called in a scalar context 
           and there are no more than one segments that satisfy the request, 
           then it is allowed to return the segment. Otherwise, the method must throw a 
           "multiple segment exception".
 Args    : Arguments are -option=E<gt>value pairs as follows:
           -name         ID of the landmark sequence.
           
           -class        A namespace qualifier.  It is not necessary for the
                         database to honor namespace qualifiers, but if it
                         does, this is where the qualifier is indicated.

           -version      Version number of the landmark.  It is not necessary for
                        the database to honor versions, but if it does, this is
                        where the version is indicated.

           -start        Start of the segment relative to landmark.  Positions
                        follow standard 1-based sequence rules.  If not specified,
                        defaults to the beginning of the landmark.

           -end          End of the segment relative to the landmark.  If not specified,
                        defaults to the end of the landmark.
=cut

sub segment {
    my $self = shift;
    my ($name,  $base_start, $stop,  $end,
        $class, $version,    $db_id, $feature_id
        )
        = $self->_rearrange(
        [   qw(NAME
                START
                STOP
                END
                CLASS
                VERSION
                DB_ID
                FEATURE_ID )
        ],
        @_
        );

    # lets the Segment class handle all the lifting.

    $end ||= $stop;
    return $self->_segclass->new( $name, $self, $base_start, $end, $db_id, 0,
        $feature_id );
}

=head2 features

 Title   : features
 Usage   : $db->features(@args)
 Function: get all features, possibly filtered by type
 Note    : This routine will retrieve features in the database regardless of position.  
           It can be used to return all features, or a subset based on their type
 Returns : a list of Bio::SeqFeatureI objects
 Args    : Arguments are -option=E<gt>value pairs as follows:

          -type      List of feature types to return.  Argument is an array
                     of Bio::Das::FeatureTypeI objects or a set of strings
                     that can be converted into FeatureTypeI objects.

          -callback  A callback to invoke on each feature.  The subroutine
                     will be passed each Bio::SeqFeatureI object in turn.

          -attributes A hash reference containing attributes to match.
          
          The -attributes argument is a hashref containing one or more attributes
          to match against:

          -attributes => { Gene => 'abc-1',
                           Note => 'confirmed' }

          Attribute matching is simple exact string matching, and multiple
          attributes are ANDed together.

          If one provides a callback, it will be invoked on each feature in
          turn.  If the callback returns a false value, iteration will be
          interrupted.  When a callback is provided, the method returns undef.

=cut

sub features {
    my $self = shift;
    my ( $type, $types, $callback, $attributes, $iterator )
        = $self->_rearrange( [qw(TYPE TYPES CALLBACK ATTRIBUTES ITERATOR)],
        @_ );

    $type ||= $types;    #GRRR

    warn "Chado,features: $type\n" if DEBUG;
    my @features = $self->_segclass->features(
        -type       => $type,
        -attributes => $attributes,
        -callback   => $callback,
        -iterator   => $iterator,
        -factory    => $self
    );
    return @features;
}

=head2 types

 Title   : types
 Usage   : $db->types(@args)
 Function: return list of feature types in database
 Returns : a list of Bio::Das::FeatureTypeI objects
 Args    : -option=E<gt>value pairs as follows:
           -enumerate  if true, count the features

This routine returns a list of feature types known to the database. It
is also possible to find out how many times each feature occurs.



The returned value will be a list of Bio::Das::FeatureTypeI objects
(see L<Bio::Das::FeatureTypeI>.

If -enumerate is true, then the function returns a hash (not a hash
reference) in which the keys are the stringified versions of
Bio::Das::FeatureTypeI and the values are the number of times each
feature appears in the database.

NOTE: This currently raises a "not-implemented" exception, as the
BioSQL API does not appear to provide this functionality.

=cut

sub types {
    my $self = shift;
    my ($enumerate) = $self->_rearrange( [qw(ENUMERATE)], @_ );
    $self->throw_not_implemented;

    #if lincoln didn't need to implement it, neither do I!
}

=head2 get_feature_by_alias, get_features_by_alias 

 Title   : get_features_by_alias
 Usage   : $db->get_feature_by_alias(@args)
 Function: return list of feature whose name or synonyms match
 Returns : a list of Bio::Das::Chado::Segment::Feature objects
 Args    : See below

This method finds features matching the criteria outlined by the
supplied arguments.  Wildcards (*) are allowed.  Valid arguments are:

=over

=item -name

=item -class

=item -ref (refrence sequence)

=item -start

=item -end 

=back

=cut

sub get_feature_by_alias {
    my $self = shift;
    my @args = @_;

    if ( @args == 1 ) {
        @args = ( -name => $args[0] );
    }

    push @args, -operation => 'by_alias';

    return $self->_by_alias_by_name(@args);
}

*get_features_by_alias = \&get_feature_by_alias;

=head2 get_feature_by_name, get_features_by_name

 Title   : get_features_by_name
 Usage   : $db->get_features_by_name(@args)
 Function: return list of feature whose names match
 Returns : a list of Bio::Das::Chado::Segment::Feature objects
 Args    : See below

This method finds features matching the criteria outlined by the
supplied arguments.  Wildcards (*) are allowed.  Valid arguments are:

=over

=item -name

=item -class

=item -ref (refrence sequence)

=item -start

=item -end

=back

=cut

*get_features_by_name = \&get_feature_by_name;

sub get_feature_by_name {
    my $self = shift;
    my @args = @_;

    if ( @args == 1 ) {
        @args = ( -name => $args[0] );
    }

    push @args, -operation => 'by_name';

    return $self->_by_alias_by_name(@args);
}

=head2 _by_alias_by_name

 Title   : _by_alias_by_name
 Usage   : $db->_by_alias_by_name(@args)
 Function: return list of feature whose names match
 Note    : A private method that implements the get_features_by_name and
           get_features_by_alias methods.  It accepts the same args as
           those methods, plus an addtional on (-operation) which is 
           either 'by_alias' or 'by_name' to indicate what rule it is to
           use for finding features.
 Returns : a list of Bio::Das::Chado::Segment::Feature objects
 Args    : See below

=cut

sub _by_alias_by_name {
    my $self = shift;

    my ( $name, $class, $ref, $base_start, $stop, $operation )
        = $self->_rearrange( [qw(NAME CLASS REF START END OPERATION)], @_ );

    my $wildcard = 0;
    if ( $name =~ /\*/ ) {
        $wildcard = 1;
    }

    warn "name:$name in get_feature_by_name" if DEBUG;

    #  $name = $self->_search_name_prep($name);

    #  warn "name after protecting _ and % in the string:$name\n" if DEBUG;

    my ( @features, $sth );

   # get feature_id
   # foreach feature_id, get the feature info
   # then get src_feature stuff (chromosome info) and create a parent feature,

    my ( $select_part, $from_part, $where_part );

    if ($class) {
        my $type
            = ( $class eq 'CDS' && $self->inferCDS )
            ? $self->name2term('polypeptide')
            : $self->name2term($class);
        return unless $type;

        if ( ref $type eq 'ARRAY' ) {
            $type = join( ',', @$type );
        }
        elsif ( ref $type eq 'HASH' ) {
            $type = join( ',', map( $$type{$_}, keys %$type ) );
        }
        $from_part = " feature f ";
        $where_part .= " f.type_id in ( $type ) ";
    }

    if ( $self->organism_id ) {
        $where_part .= " AND f.organism_id =" . $self->organism_id;
    }

    if ( $operation eq 'by_alias' ) {
        $select_part = "select distinct fs.feature_id \n";
        $from_part
            = $from_part
            ? "$from_part, feature_synonym fs, synonym_ s "
            : "feature_synonym fs, synonym_ s ";

        my $alias_only_where;
        if ($wildcard) {
            $alias_only_where = "where fs.synonym_id = s.synonym_id and\n"
                . "lower(s.synonym_sgml) like ?";
        }
        else {
            $alias_only_where = "where fs.synonym_id = s.synonym_id and\n"
                . "lower(s.synonym_sgml) = ?";
        }

        $where_part
            = $where_part
            ? "$alias_only_where AND $where_part"
            : $alias_only_where;
    }
    else {    #searching by name only
        $select_part = "select f.feature_id ";
        $from_part   = " feature f ";

        my $name_only_where;
        if ($wildcard) {
            $name_only_where = "where lower(f.name) like ?";
        }
        else {
            $name_only_where = "where lower(f.name) = ?";
        }

        $where_part
            = $where_part
            ? "$name_only_where AND $where_part"
            : $name_only_where;
    }

    my $query = $select_part . ' FROM ' . $from_part . $where_part;

    warn "first get_feature_by_name query:$query" if DEBUG;

    if ($wildcard) {
        $name = $self->_search_name_prep($name);
        warn "name after protecting _ and % in the string:$name\n"
            if DEBUG;
    }

    # what the hell happened to the lower casing!!!
    # left over bug from making the adaptor case insensitive?
    $name = lc($name);

    $sth = $self->conn->run(
        {   my $sth = $_->prepare($query);
                $sth->execute($name)
                or $self->throw("getting the feature_ids failed");
                $sth;
        }
    );

  # this makes performance awful!  It does a wildcard search on a view
  # that has several selects in it.  For any reasonably sized database,
  # this won't work.
  #
  #  if ($sth->rows < 1 and
  #      $class ne 'chromosome' and
  #      $class ne 'region' and
  #      $class ne 'contig') {
  #
  #    my $query;
  #    ($name,$query) = $self->_complex_search($name,$class,$wildcard);
  #
  #    warn "complex_search query:$query\n";
  #
  #    $sth = $self->dbh->prepare($query);
  #    $sth->execute($name) or $self->throw("getting the feature_ids failed");
  #    }
  #  }

    # prepare sql queries for use in while loops
    my $iquery = "
    select f.feature_id, f.name, f.type_id,f.uniquename,af.significance as score,
        fl.fmin,fl.fmax,fl.strand,fl.phase, fl.srcfeature_id, fd.dbxref_id
    from V_NOTDELETED_FEATURE f 
        inner join featureloc fl            on f.feature_id = fl.feature_id
        left outer join analysisfeature af  on f.feature_id = af.feature_id
        left outer join feature_dbxref fd   on fd.feature_id = f.feature_id
    where
        f.feature_id = ? and fl.rank=0 
        and (fd.dbxref_id is null or fd.dbxref_id in
            (select dbxref_id from dbxref where db_id ="
        . $self->gff_source_db_id . "))
    order by fl.srcfeature_id
  " );

    my $jquery = "select name from V_NOTDELETED_FEATURE
                                      where feature_id = ?"
        );

    while ( my $feature_id_ref = $sth->fetchrow_hashref("NAME_lc") ) {
            my $isth = $self->conn->run(
                sub {
                    my $isth = $_->prepare($iquery);
                    $isth->execute( $$feature_id_ref{'feature_id'} )
                        or $self->throw("getting feature info failed");
                    $isth;
                }
            );

            my $rows_returned = @{ $isth->fetchall_arrayref() };
            if ( $rows_returned == 0 && ( $class ne 'gene' ) )
            {    #this might be a srcfeature

                warn "$name might be a srcfeature" if DEBUG;
                my $is_srcfeature_query = $self->conn->run(
                    sub {
                        my $sth
                            = $_->prepare(
                            "select srcfeature_id from featureloc where srcfeature_id=?"
                            );
                        $sth->execute( $$feature_id_ref{'feature_id'} )
                            or $self->throw(
                            "checking if feature is a srcfeature failed");
                        $sth;
                    }
                );

                my $rows_returned
                    = @{ $is_srcfeature_query->fetchall_arrayref() };
                $is_srcfeature_query->execute or Bio::Root::Root->throw();

                if ( $rows_returned >= 1 ) {    #yep, its a srcfeature
                        #build a feature out of the srcfeature:
                    warn "Yep, $name is a srcfeature" if DEBUG;
                    my @args = ($name);
                    push @args, $base_start if $base_start;
                    push @args, $stop       if $stop;
                    warn "srcfeature args:$args[0]" if DEBUG;
                    my @seg = ( $self->segment(@args) );
                    return @seg;
                }
                else {
                    return;    #I got nothing!
                }
            }

            #getting chromosome info
            my $old_srcfeature_id = -1;
            my $parent_segment;
            while ( my $hashref = $isth->fetchrow_hashref("NAME_lc") ) {
                if ( $$hashref{'srcfeature_id'} != $old_srcfeature_id ) {
                    $jsth->execute( $$hashref{'srcfeature_id'} )
                        or die("getting assembly info failed");
                    my $src_name = $jsth->fetchrow_hashref("NAME_lc");
                    $parent_segment
                        = Modware::DB::Adaptor::GBrowse::Segment->new(
                        $$src_name{'name'}, $self );
                    $old_srcfeature_id = $$hashref{'srcfeature_id'};
                }

                #now build the feature

                #Recursive Mapping
                if ( $self->{recursivMapping} ) {
                    my $sql = "select fl.fmin,fl.fmax,fl.strand,fl.phase
                   from feat_remapping("
                        . $$feature_id_ref{'feature_id'} . ")  fl
                   where fl.rank=0";

                    #$sql =~ s/\s+/ /gs;

                    my $recurs_sth = $self->conn->run(
                        sub {
                            my $sth = $_->prepare($sql);
                            $sth->execute;
                            $sth;
                        }
                    );
                    my $hashref2 = $recurs_sth->fetchrow_hashref("NAME_lc");
                    my $strand_  = $$hashref{'strand'};
                    my $phase_   = $$hashref{'phase'};
                    my $fmax_    = $$hashref{'fmax'};
                    my $interbase_start;

                   #If unable to recursively map we assume that the feature is
                   # already mapped on the lowest refseq

                    if ( $recurs_sth->rows != 0 ) {
                        $interbase_start = $$hashref2{'fmin'};
                        $strand_         = $$hashref2{'strand'};
                        $phase_          = $$hashref2{'phase'};
                        $fmax_           = $$hashref2{'fmax'};
                    }
                    else {
                        $interbase_start = $$hashref{'fmin'};
                    }
                    $base_start = $interbase_start + 1;
                    my $feat
                        = Modware::DB::Adaptor::GBrowse::Segment::Feature
                        ->new(
                        $self,
                        $parent_segment,
                        $parent_segment->seq_id,
                        $base_start,
                        $fmax_,
                        $self->term2name( $$hashref{'type_id'} ),
                        $$hashref{'score'},
                        $strand_,
                        $phase_,
                        $$hashref{'name'},
                        $$hashref{'uniquename'},
                        $$hashref{'feature_id'}
                        );
                    push @features, $feat;

                    #END Recursive Mapping
                }
                else {

                    if ( $class && $class eq 'CDS' && $self->inferCDS ) {

                        #$hashref holds info for the polypeptide
                        my $poly_min = $$hashref{'fmin'};
                        my $poly_max = $$hashref{'fmax'};
                        my $poly_fid = $$hashref{'feature_id'};

                        #get fid of parent transcript
                        my $id_list
                            = ref $self->term2name('derives_from') eq 'ARRAY'
                            ? "in ("
                            . join( ",",
                            @{ $self->term2name('derives_from') } )
                            . ")"
                            : "= " . $self->term2name('derives_from');

                        my $transcript_query = $self->conn->run(
                            sub {
                                my $sth = $_->prepare(
                                    "SELECT object_id FROM feature_relationship
                										WHERE type_id " 
                                        . $id_list
                                        . " AND subject_id = $poly_fid"
                                );
                                $sth->execute;
                                $sth;
                            }
                        );
                        my ($trans_id) = $transcript_query->fetchrow_array;
                        $id_list
                            = ref $self->term2name('part_of') eq 'ARRAY'
                            ? "in ("
                            . join( ",", @{ $self->term2name('part_of') } )
                            . ")"
                            : "= " . $self->term2name('part_of');

                        #now get exons that are part of the transcript
                        my $exon_query = $self->conn->run(
                            sub {
                                my $sth = $_->prepare( "
               SELECT f.feature_id,f.name,f.type_id,f.uniquename,
                      af.significance as score,fl.fmin,fl.fmax,fl.strand,
                      fl.phase, fl.srcfeature_id, fd.dbxref_id
               FROM feature f join featureloc fl using (feature_id)
                    left join analysisfeature af using (feature_id)
                    left join feature_dbxref fd using (feature_id)
               WHERE
                   f.type_id = "
                                        . $self->term2name('exon')
                                        . " and f.feature_id in
                     (select subject_id from feature_relationship where object_id = $trans_id and
                             type_id " . $id_list . " ) and 
                   fl.rank=0 and
                   (fd.dbxref_id is null or fd.dbxref_id in
                     (select dbxref_id from dbxref where db_id ="
                                        . $self->gff_source_db_id
                                        . "))        
            " );
                                $sth->execute();
                                $sth;
                            }
                        );

                        #warn $self->dbh->{Profile}->format;
                        while ( my $exonref
                            = $exon_query->fetchrow_hashref("NAME_lc") )
                        {
                            next if ( $$exonref{fmax} < $poly_min );
                            next if ( $$exonref{fmin} > $poly_max );

                            my ( $start, $stop );
                            if (   $$exonref{fmin} <= $poly_min
                                && $$exonref{fmax} >= $poly_max )
                            {

                                #the exon starts before polypeptide start
                                $start = $poly_min + 1;
                            }
                            else {
                                $start = $$exonref{fmin} + 1;
                            }

                            if (   $$exonref{fmax} >= $poly_max
                                && $$exonref{fmin} <= $poly_min )
                            {
                                $stop = $poly_max;
                            }
                            else {
                                $stop = $$exonref{fmax};
                            }

                            my $feat
                                = Modware::DB::Adaptor::GBrowse::Segment::Feature
                                ->new(
                                $self,
                                $parent_segment,
                                $parent_segment->seq_id,
                                $start,
                                $stop,
                                'CDS',
                                $$hashref{'score'},
                                $$hashref{'strand'},
                                $$hashref{'phase'},
                                $$hashref{'name'},
                                $$hashref{'uniquename'},
                                $$hashref{'feature_id'}
                                );
                            push @features, $feat;
                        }

                    }
                    else {

                        #the normal case where you don't infer CDS features
                        my $interbase_start = $$hashref{'fmin'};
                        $base_start = $interbase_start + 1;
                        my $feat
                            = Modware::DB::Adaptor::GBrowse::Segment::Feature
                            ->new(
                            $self,
                            $parent_segment,
                            $parent_segment->seq_id,
                            $base_start,
                            $$hashref{'fmax'},
                            $self->term2name( $$hashref{'type_id'} ),
                            $$hashref{'score'},
                            $$hashref{'strand'},
                            $$hashref{'phase'},
                            $$hashref{'name'},
                            $$hashref{'uniquename'},
                            $$hashref{'feature_id'}
                            );
                        push @features, $feat;
                    }
                }
            }
    }
    @features;
}

*fetch_feature_by_name = \&get_feature_by_name;

sub _complex_search {
        my $self  = shift;
        my $name  = shift;
        my $class = shift;

        warn "name before wildcard subs:$name\n" if DEBUG;

        $name = "\%$name" unless ( 0 == index( $name,          "%" ) );
        $name = "$name%"  unless ( 0 == index( reverse($name), "%" ) );

        warn "name after wildcard subs:$name\n" if DEBUG;

        my $select_part = "select ga.feature_id ";
        my $from_part   = "from gffatts ga ";
        my $where_part  = "where lower(ga.attribute) like ? ";

        if ($class) {
            my $type = $self->name2term($class);
            return unless $type;
            $from_part  .= ", V_NOTDELETED_FEATURE f ";
            $where_part .= "and ga.feature_id = f.feature_id and "
                . "f.type_id = $type";
        }

        $where_part .= " and organism_id = " . $self->organism_id
            if $self->organism_id;

        my $query = $select_part . $from_part . $where_part;
        return ( $name, $query );
}

sub _search_name_prep {
        my $self = shift;
        my $name = shift;

        $name =~ s/_/\\_/g;     # escape underscores in name
        $name =~ s/\%/\\%/g;    # ditto for percent signs

        $name =~ s/\*/%/g;

        return lc($name);
}

=head2 srcfeature2name

 Title   : srcfeature2name
 Usage   :
 Function: returns a srcfeature name given a srcfeature_id

=cut

sub srcfeature2name {
        my $self = shift;
        my $id   = shift;

        return $self->{'srcfeature_id'}->{$id}
            if $self->{'srcfeature_id'}->{$id};

        my $sth = $self->conn->run( sub {
                my $sth
                    = $_->prepare( "select name from V_NOTDELETED_FEATURE "
                        . "where feature_id = ?" );
                $sth->execute($id);
                $sth;
        } );

        my $hashref = $sth->fetchrow_hashref("NAME_lc");
        $self->{'srcfeature_id'}->{$id} = $$hashref{'name'};
        return $self->{'srcfeature_id'}->{$id};
}

=head2 gff_source_db_id

  Title   : gff_source_db_id
  Function: caches the chado db_id from the chado db table

=cut

sub gff_source_db_id {
        my $self = shift;
        return $self->{'gff_source_db_id'}
            if defined $self->{'gff_source_db_id'};

        my $row = $self->schema->resultset('General::Db')->find(
            { name => 'GFF_source' } );

        $self->{'gff_source_db_id'} = $row->db_id;
        return $self->{'gff_source_db_id'};
}

=head2 source2dbxref

Title   : source2dbxref
Function: Gets dbxref_id for features that have a gff source associated

=cut

sub source2dbxref {
        my $self   = shift;
        my $source = shift;

        return 'fake' unless defined $self->gff_source_db_id;

        return $self->{'source_dbxref'}->{$source}
            if $self->{'source_dbxref'}->{$source};

        my $schema    = $self->schema;
        my $dbxref_rs = $schema->resultset('General::Dbxref')->search(
            { 'db_id' => $self->gff_source_db_id } );

        while ( my $row = $dbxref_rs->next ) {
            $self->{source_dbxref}->{ $row->accession } = $row->dbxref_id;
            $self->{dbxref_source}->{ $row->dbxref_id } = $row->accession;
        }

        return $self->{source_dbxref}->{$source};

        #my $sth = $self->dbh->prepare( "
        #    select dbxref_id,accession from dbxref where db_id="
        #        . $self->gff_source_db_id );
        #$sth->execute();

#while ( my $hashref = $sth->fetchrow_hashref("NAME_lc") ) {
#    warn
#        "s2d:accession:$$hashref{accession}, dbxref_id:$$hashref{dbxref_id}\n"
#        if DEBUG;

        #    $self->{'source_dbxref'}->{ $$hashref{accession} }
        #        = $$hashref{dbxref_id};
        #    $self->{'dbxref_source'}->{ $$hashref{dbxref_id} }
        #        = $$hashref{accession};
        #}

        #return $self->{'source_dbxref'}->{$source};

}

=head2 dbxref2source

 Title   : dbxref2source
 Function: returns the source (string) when given a dbxref_id

=cut

sub dbxref2source {
        my $self   = shift;
        my $dbxref = shift;

        return '.' unless defined( $self->gff_source_db_id );

        warn "d2s:dbxref:$dbxref\n" if DEBUG;

        if ( defined( $self->{'dbxref_source'} )
            && $dbxref
            && defined( $self->{'dbxref_source'}->{$dbxref} ) )
        {
            return $self->{'dbxref_source'}->{$dbxref};
        }

        my $sth = $self->conn->run( sub {
                my $sth
                    = $_->prepare(
                    "select dbxref_id,accession from dbxref where db_id="
                        . $self->gff_source_db_id );
                $sth->execute();
                $sth;
        } );

        my $rows_returned = @{ $sth->fetchall_arrayref() };
        $sth->execute or Bio::Root::Root->throw();

        if ( $rows_returned < 1 ) {
            return ".";
        }

        while ( my $hashref = $sth->fetchrow_hashref("NAME_lc") ) {
            warn
                "d2s:accession:$$hashref{accession}, dbxref_id:$$hashref{dbxref_id}\n"
                if DEBUG;

            $self->{'source_dbxref'}->{ $$hashref{accession} }
                = $$hashref{dbxref_id};
            $self->{'dbxref_source'}->{ $$hashref{dbxref_id} }
                = $$hashref{accession};
        }

        if ( defined $self->{'dbxref_source'}
            && $dbxref
            && defined $self->{'dbxref_source'}->{$dbxref} )
        {
            return $self->{'dbxref_source'}->{$dbxref};
        }
        else {
            $self->{'dbxref_source'}->{$dbxref} = "." if $dbxref;
            return ".";
        }

}

=head2 source_dbxref_list

 Title   : source_dbxref_list
 Usage   : @all_dbxref_ids = $db->source_dbxref_list()
 Function: Gets a list of all dbxref_ids that are used for GFF sources
 Returns : a comma delimited string that is a list of dbxref_ids
 Args    : none
 Status  : public

This method queries the database for all dbxref_ids that are used
to store GFF source terms.

=cut

sub source_dbxref_list {
        my $self = shift;
        return $self->{'source_dbxref_list'}
            if defined $self->{'source_dbxref_list'};

        my $query = "select dbxref_id from dbxref where db_id = "
            . $self->gff_source_db_id;
        my $sth = $self->conn->run( sub {
                my $sth = $_->prepare($query);
                $sth->execute();
                $sth;
        } );

        #unpack it here to make it easier
        my @dbxref_list;
        while ( my $row = $sth->fetchrow_arrayref ) {
            push @dbxref_list, $$row[0];
        }

        $self->{'source_dbxref_list'} = join( ",", @dbxref_list );
        return $self->{'source_dbxref_list'};
}

=head2 attributes

 Title   : attributes
 Usage   : @attributes = $db->attributes($id,$name)
 Function: get the "attributes" on a particular feature
 Note    : This method is intended as a "work-alike" to Bio::DB::GFF's 
           attributes method, which has the following returns:

           Called in list context, it returns a list.  If called in a
           scalar context, it returns the first value of the attribute
           if an attribute name is provided, otherwise it returns a
           hash reference in which the keys are attribute names
           and the values are anonymous arrays containing the values.
 Returns : an array of string
 Args    : feature ID [, attribute name]

=cut

sub attributes {
        my $self = shift;
        my ( $id, $tag ) = @_;

        #get feature_id

        my $query
            = "select feature_id from V_NOTDELETED_FEATURE where uniquename = ?";
        $query .= " and organism_id = " . $self->organism_id
            if $self->organism_id;

        my $sth = $self->conn->run( sub {
                my $sth = $_->prepare($query);
                $sth->execute($id)
                    or $self->throw("failed to get feature_id in attributes");
                $sth;
        } );
        my $hashref    = $sth->fetchrow_hashref("NAME_lc");
        my $feature_id = $$hashref{'feature_id'};

        if ( defined $tag ) {
            my $query = qq{
        SELECT VALUE 
        FROM FEATUREPROP FP
        INNER JOIN CVTERM C
          ON C.CVTERM_ID = FP.TYPE_ID
        WHERE FP.FEATURE_ID = ?
          AND C.NAME = ?
       };
            $sth = $self->conn->run(
                sub {
                    my $sth = $_->prepare($query);
                    $sth->execute( $feature_id, $tag );
                    $sth;
                }
            );
        }
        else {
            my $query = qq{SELECT type,attribute FROM gfffeatureatts = ?};
            $sth = $self->conn->run(
                sub {
                    my $sth = $_->prepare($query);
                    $sth->execute($feature_id);
                    $sth;
                }
            );
        }

        my $arrayref = $sth->fetchall_arrayref;

        my @array = @$arrayref;
        return () if scalar @array == 0;

## dgg; ugly patch to copy polypeptide/protein residues into 'translation' attribute
        # need to add to gfffeatureatts ..
        if ( !defined $tag || $tag eq 'translation' ) {
            my $sth = $self->conn->run(
                sub {
                    my $sth
                        = $_->prepare(
                        "select type_id from V_NOTDELETED_FEATURE where feature_id = ?"
                        );
                    $sth->execute($feature_id);
                    $sth;
                }
            );
            $hashref = $sth->fetchrow_hashref("NAME_lc");
            my $type_id = $$hashref{'type_id'};
            ## warn("DEBUG: dgg ugly prot. patch; type=$type_id for ftid=$feature_id\n");

            if (   $type_id == $self->name2term('polypeptide')
                || $type_id == $self->name2term('protein') )
            {
                $sth = $self->conn->run(
                    sub {
                        my $sth
                            = $_->prepare(
                            "select residues from V_NOTDELETED_FEATURE where feature_id = ?"
                            );
                        $sth->execute($feature_id);
                        $sth;
                    }
                );
                $hashref = $sth->fetchrow_hashref("NAME_lc");
                my $aa = $$hashref{'residues'};
                if ($aa) {
                    ## warn("DEBUG: dgg ugly prot. patch; aalen=",length($aa),"\n");
                    ## this wasn't working till I added in a featureprop 'translation=dummy' .. why?
                    if ($tag) { push( @array, [$aa] ); }
                    else { push( @array, [ 'translation', $aa ] ); }
                }
            }
        }

        my @result;
        foreach my $lineref (@array) {
            my @la = @$lineref;
            push @result, @la;
        }
        return @result if wantarray;
        return $result[0] if $tag;

        my %result;
        foreach my $lineref (@array) {
            my ( $key, $value ) = splice( @$lineref, 0, 2 );
            push @{ $result{$key} }, $value;
        }
        return \%result;

}

=head2 _segclass

 Title   : _segclass
 Usage   : $class = $db->_segclass
 Function: returns the perl class that we use for segment() calls
 Returns : a string containing the segment class
 Args    : none
 Status  : reserved for subclass use

=cut

#sub default_class {return 'Sequence' }
## URGI changes
sub default_class {

        my $self = shift;

        #dgg
        unless ( $self->{'reference_class'} || @_ ) {
            $self->{'reference_class'} = $self->chado_reference_class();
        }

        if (@_) {
            my $checkref = $self->check_chado_reference_class(@_);
            unless ($checkref) {
                $self->throw(
                    "unable to find reference_class '$_[0]' feature in the database"
                );
            }
        }

        $self->{'reference_class'} = shift || 'Sequence' if (@_);

        return $self->{'reference_class'};

}

sub check_chado_reference_class {
        my $self = shift;
        if (@_) {
            my $refclass = shift;
            my $type_id  = $self->name2term($refclass);
            my $query    = "select feature_id from feature where type_id = ?";
            $self->conn->run(
                sub {
                    my $sth = $_->prepare($query);
                    $sth->execute($type_id)
                        or
                        $self->throw("trying to find chado_reference_class");
                    $sth;
                }
            );
            my $data  = $sth->fetchrow_hashref("NAME_lc");
            my $refid = $$data{'feature_id'};
            ## warn("check_chado_reference_class: $refclass = $type_id -> $refid"); # DEBUG
            return $refid;
        }
}

=head2 chado_reference_class

  Title   : chado_reference_class 
  Usage   : $obj->chado_reference_class()
  Function: get or return the ID to use for Gbrowse map reference class 
            using cvtermprop table, value = MAP_REFERENCE_TYPE 
  Note    : Optionally test that user/config supplied ref class is indeed a proper
            chado feature type.
  Returns : the cvterm.name 
  Args    : to return the id, none; to determine the id, 1
  See also: default_class, refclass_feature_id
  
=cut

sub chado_reference_class {
        my $self = shift;
        return $self->{'chado_reference_class'}
            if ( $self->{'chado_reference_class'} );

        my $chado_reference_class = 'Sequence';    # default ?

        my $query = "select cvterm_id from cvtermprop where value = ?";
        my $sth   = $self->conn->run( sub {
                my $sth = $_->prepare($query);
                $sth->execute(MAP_REFERENCE_TYPE)
                    or $self->throw("trying to find chado_reference_class");
                $sth;
        } );

        my $data = $sth->fetchrow_hashref(
            "NAME_lc");    #? FIXME: could be many values *?
        my $ref_cvtermid = $$data{'cvterm_id'};

        if ($ref_cvtermid) {
            $query = "select name from cvterm where cvterm_id = ?";
            $sth   = $self->conn->run(
                sub {
                    my $sth = $_->prepare($query);
                    $sth->execute($ref_cvtermid)
                        or
                        $self->throw("trying to find chado_reference_class");
                    $sth;
                }
            );
            $data = $sth->fetchrow_hashref("NAME_lc");
            $chado_reference_class = $$data{'name'} if ( $$data{'name'} );

# warn("chado_reference_class: $chado_reference_class = $ref_cvtermid"); # DEBUG
        }
        return $self->{'chado_reference_class'} = $chado_reference_class;
}

=head2 refclass_feature_id

 Title   : refclass_feature_id
 Usage   : $self->refclass_srcfeature_id()
 Function: Used to store the feature_id of the reference class feature we are working on (e.g. contig, supercontig)
           With this feature we can filter out all the request to be sure we are extracting a feature located on 
           the reference class feature.
 Returns : A scalar
 Args    : The feature_id on setting

=cut

sub refclass_feature_id {

        my $self = shift;

        $self->{'refclass_feature_id'} = shift if (@_);

        return $self->{'refclass_feature_id'};

}

sub get_seq_stream {
        my $self = shift;

        #warn "get_seq_stream args:@_";
        my ( $type, $types, $callback, $attributes, $iterator,
            $feature_id, $seq_id, $start, $end ) = $self->_rearrange( [
                qw(TYPE TYPES CALLBACK ATTRIBUTES ITERATOR FEATURE_ID SEQ_ID START END)
            ],
            @_ );

        my @features = $self->_segclass->features(
            -type       => $type,
            -attributes => $attributes,
            -callback   => $callback,
            -iterator   => $iterator,
            -factory    => $self,
            -feature_id => $feature_id,
            -seq_id     => $seq_id,
            -start      => $start,
            -end        => $end,
            );

        return Bio::DB::Das::ChadoIterator->new( \@features );

}

sub _segclass { return SEGCLASS }

sub absolute {return}

=head1 LEFTOVERS FROM BIO::DB::GFF NEEDED FOR DAS

these methods should probably be declared in an interface class
that Bio::DB::GFF implements.  for instance, the aggregator methods
could be described in Bio::SeqFeature::AggregatorI

=cut

sub aggregators { return (); }

sub schema {
        my ( $self, $schema ) = @_;
        if ( defined $schema ) {
            $self->{bcs} = $schema;
            return;
        }
        return $self->{bcs} if defined $self->{bcs};
}

=head1 END LEFTOVERS

=cut

package Bio::DB::Das::ChadoIterator;

sub new {
        my $package  = shift;
        my $features = shift;
        return bless $features, $package;
}

sub next_seq {
        my $self = shift;
        return unless @$self;
        my $next_feature = shift @$self;
        return $next_feature;
}

1;          
