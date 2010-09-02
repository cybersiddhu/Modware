
=head1 NAME

Modware::DB::Adaptor::GBrowse::Chado::Segment - ModwareBase specific adaptor for DAS-style access to a chado database

=head1 SYNOPSIS

  # Get a Bio::Das::SegmentI object from a Modware::DB::Adaptor::GBrowse::Chado database...

  $segment = $das->segment(-name => 'Landmark',
                           -start=> $start,
                           -stop => $stop);

  @features = $segment->overlapping_features(-type=>['type1','type2']);
  # each feature is a Bio::SeqFeatureI-compliant object

  @features = $segment->contained_features(-type=>['type1','type2']);

  @features = $segment->contained_in(-type=>['type1','type2']);

  $stream = $segment->get_feature_stream(-type=>['type1','type2','type3'];
  while (my $feature = $stream->next_seq) {
     # do something with feature
  }

  $count = $segment->features_callback(-type=>['type1','type2','type3'],
                                       -callback => sub { ... { }
                                       );

=head1 DESCRIPTION

Modware::DB::Adaptor::GBrowse::Segment iprovides ModwareBase customisation for
Bio::DB::Das::Chado::Segment object ("segment").

=head1 AUTHOR

Email y-bushmanova@northwestern.edu

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

package Modware::DB::Adaptor::GBrowse::Segment;

use strict;
use Carp qw(carp croak cluck confess);
use Bio::Root::Root;
use Bio::SeqI;
use Bio::Das::SegmentI;
use Modware::DB::Adaptor::GBrowse::Chado;
use Modware::DB::Adaptor::GBrowse::Segment::Feature;
use Bio::DB::Das::Chado::Segment;
use Bio::DB::GFF::Typename;
use Data::Dumper;

use overload '""'  => \&asString;
use constant DEBUG => 0;

use vars '@ISA';
@ISA
    = qw( Bio::Root::Root Bio::SeqI Bio::Das::SegmentI Modware::DB::Adaptor::GBrowse::Chado );

# construct a virtual segment that works in a lazy way
sub new {

    #validate that the name/accession is valid, and start and end are valid,
    #then return a new segment

    my $self       = {};
    my $class_type = shift;

    my ( $name, $factory, $base_start, $stop, $db_id, $target, $feature_id )
        = @_;

    bless $self, ref $class_type || $class_type;
    $self->{'factory'} = $factory;
    $self->{'name'}    = $name;
    $target ||= 0;

    my $strand;

    warn "na:$name, id:$db_id, $factory\n"          if DEBUG;
    warn "base_start = $base_start, stop = $stop\n" if DEBUG;

    # clicking on the help in gbrowse calls this constructor without a
    # name. return to avoid performances issues
    return if not defined $name;

    $base_start = $base_start ? int($base_start) : 1;
    my $interbase_start = $base_start - 1;

    my $quoted_name = $factory->dbh->quote( lc $name );
    warn "quoted name:$quoted_name\n" if DEBUG;

    # need to change this query to allow for Target queries

    ##URGI - Changed the request to be sure we are getting the srcfeature_id of type 'reference class'
    ##from gbrowse configuration file
    ##We also check if we are not in the recursive call from feactory->segment, in this case we already set the ref feature_id
    ##for reference class feature.

    ##minor change: calling name2term with no arg returna a hashref (as documented)
    ##so if $factory->default_class() is empty, you would get a hashref in $refclass

    my $refclass
        = $factory->default_class
        ? $factory->name2term( $factory->default_class )
        : undef;

    my $ref_feature_id = $factory->refclass_feature_id() || undef;
    my $where_part = " and rank = $target " if defined $target;
    if ( defined($ref_feature_id) ) {
        $where_part .= " and fl.srcfeature_id = $ref_feature_id ";
    }
    else {
        $where_part .= " and srcf.type_id = $refclass "
            if ( defined $refclass );
    }

    $where_part .= " and srcf.organism_id = " . $self->factory->organism_id
        if $self->factory->organism_id;

    my $srcfeature_txt = "select srcfeature_id from featureloc fl
          join feature srcf on (fl.srcfeature_id = srcf.feature_id) 
        where fl.feature_id = ? " . $where_part;

    my $landmark_is_txt = "select f.name,f.feature_id,f.seqlen,f.type_id
       from V_NOTDELETED_FEATURE f
       where f.feature_id = ?
         ";

    my $feature_txt
        = "select f.name,f.feature_id,f.seqlen,f.type_id,fl.fmin,fl.fmax,fl.strand
       from V_NOTDELETED_FEATURE f, featureloc fl
       where fl.feature_id = ? and
             ? = f.feature_id";

    my $fetch_uniquename_txt
        = "select f.name,fl.fmin,fl.fmax,f.uniquename from V_NOTDELETED_FEATURE f, featureloc fl
       where f.feature_id = ? and
             f.feature_id = fl.feature_id";

    my $ref = $self->_search_by_name( $factory, $quoted_name, $db_id,
        $feature_id );

    #returns either a feature_id scalar (if there is only one result)
    #or an arrayref (of feature_ids) if there is more than one result
    #or nothing if there is no result

    if ( ref $ref eq 'ARRAY' ) {    #more than one result returned
        my @segments;
        foreach my $feature_id (@$ref) {
            $fetch_uniquename_query = $factory->conn->run(
                sub {
                    my $sth = $_->prepare($fetch_uniquename_txt);
                    $sth->execute($feature_id)
                        or Bio::Root::Root->throw(
                        "fetching uniquename from feature_id failed");
                    $sth;
                }
            );

            my $hashref
                = $fetch_uniquename_query->fetchrow_hashref("NAME_lc");
            warn "$base_start, $stop\n" if DEBUG;
            warn Dumper($hashref) if DEBUG;

            $base_start = $base_start ? $base_start : $$hashref{fmin} + 1;
            $stop       = $stop       ? $stop       : $$hashref{fmax};
            $db_id = $$hashref{uniquename};

            next
                if not defined $base_start
                    or not defined $stop
                    or not defined $db_id;

            warn
                "calling factory->segment with name:$name, start:$base_start, stop:$stop, db_id:$db_id\n"
                if DEBUG;

            push @segments,
                $factory->segment(
                -name  => $name,
                -start => $base_start,
                -stop  => $stop,
                -db_id => $db_id
                );

 #reset these variables so subsequent passes through the loop wont be confused
            $base_start = '';
            $stop       = '';
            $db_id      = '';
            $strand     = '';
        }

        if ( @segments < 2 ) {
            return $segments[0];    #I don't think this should ever happen
        }
        elsif (wantarray) {
            return @segments;
        }
        else {
            warn
                "The query for $name returned multiple segments\nPlease call in a list context to get them all";
            Bio::Root::Root->throw("multiple segment exception");
        }
    }
    elsif ( ref $ref eq 'SCALAR' ) {    #one result returned

        my $landmark_feature_id = $$ref;

        warn "landmark feature_id:$landmark_feature_id\n" if DEBUG;

        $srcfeature_query = $factory->conn->run(
            sub {
                my $sth = $_->prepare($srcfeature_txt);
                $sth->execute($landmark_feature_id)
                    or Bio::Root::Root->throw("finding srcfeature_id failed");
                $sth;
            }
        );

        my $hash_ref = $srcfeature_query->fetchrow_hashref("NAME_lc");
        my $srcfeature_id
            = defined $hash_ref->{'srcfeature_id'}
            ? $hash_ref->{'srcfeature_id'}
            : $landmark_feature_id;

        warn "srcfeature_id:$srcfeature_id" if DEBUG;

        ###URGI Is it the right place to set it?
        $factory->refclass_feature_id($srcfeature_id);

        if ( $landmark_feature_id == $srcfeature_id ) {

            $landmark_is_src_query = $factory->conn->run(
                sub {
                    my $sth = $_->prepare($landmark_is_src_txt);
                    $sth->execute($landmark_feature_id)
                        or Bio::Root::Root->throw("something else failed");
                    $sth;
                }
            );
            $hash_ref = $landmark_is_src_query->fetchrow_hashref("NAME_lc");

            $name = $$hash_ref{'name'};

            my $length = $$hash_ref{'seqlen'};
            my $type   = $factory->term2name( $$hash_ref{'type_id'} );

            if ( $$hash_ref{'fmin'} ) {
                $interbase_start = $$hash_ref{'fmin'};
                $base_start      = $interbase_start + 1;
                $stop            = $$hash_ref{'fmax'};
                $strand          = $$hash_ref{'strand'};
            }

            warn "base_start:$base_start, stop:$stop, length:$length"
                if DEBUG;

            if ( defined($interbase_start) and $interbase_start < 0 ) {
                $self->warn( "start value ($interbase_start) less than zero,"
                        . " resetting to zero" )
                    if DEBUG;
                $base_start      = 1;
                $interbase_start = 0;
            }

            if ( defined($stop) and defined($length) and $stop > $length ) {
                $self->warn(
                          "end value ($stop) greater than length ($length),"
                        . " truncating to $length" )
                    if DEBUG;
                $stop = $length;
            }
            $stop = $stop ? int($stop) : $length;
            $length = $stop - $interbase_start;

            warn "base_start:$base_start, stop:$stop, length:$length"
                if DEBUG;

            $self->start($base_start);
            $self->end($stop);
            $self->{'length'} = $length;
            $self->srcfeature_id($srcfeature_id);
            $self->class($type);
            $self->name($name);
            $self->strand($strand);

            warn $self if DEBUG;
            return $self;
        }

        else {    #return a Feature object for the feature_id
            my ($feat) = $self->features(
                -feature_id => $landmark_feature_id,
                -factory    => $factory,
                -start      => $base_start,
                -stop       => $stop,
                -strand     => $strand,
            );
            return $feat;
        }

    }
    else {
        warn "no segment found" if DEBUG;
        return;    #nothing returned
    }
}

=head2 name

 Title   : name
 Usage   : $segname = $seg->name();
 Function: Returns the name of the segment
 Returns : see above
 Args    : none
 Status  : public

=cut

sub name {
    my $self = shift;
    return undef unless ref $self;
    return $self->{'name'};
}

=head2 strand()

  Title   : strand
  Usage   : $obj->strand()
  Function: Returns the strand of the feature.  Unlike the other
            methods, the strand cannot be changed once the object is
            created (due to coordinate considerations).
            corresponds to featureloc.strand
  Returns : -1, 0, or 1
  Args    : on set, new value (a scalar or undef, optional)

=cut

sub strand {
    my $self = shift;

    return $self->{'strand'} = shift if @_;
    return $self->{'strand'} || 0;
}

=head2 _search_by_name

 Title   : _search_by_name 
 Usage   : _search_by_name($name);
 Function: Searches for segments based on a name
 Returns : Either a scalar (a feature_id) or an arrary ref (containing feature_ids)
 Args    : A string (name)
 Status  : private (used by new)

=cut

sub _search_by_name {
    my $self = shift;
    my ( $factory, $quoted_name, $db_id, $feature_id ) = @_;

    warn "_search_by_name args:@_" if DEBUG;

    my $obsolete_part = "";
    $obsolete_part .= " and organism_id = " . $self->factory->organism_id
        if $self->factory->organism_id;

    my $query;
    if ($feature_id) {
        $query = "select name,feature_id,seqlen from V_NOTDELETED_FEATURE
             where feature_id = $feature_id $obsolete_part";
    }
    elsif ($db_id) {
        $query = "select name,feature_id,seqlen from V_NOTDELETED_FEATURE
             where uniquename = \'$db_id\' $obsolete_part";

    }
    else {
        $query = "select name,feature_id,seqlen from V_NOTDELETED_FEATURE
             where lower(name) = $quoted_name $obsolete_part
             union
             select name,feature_id,seqlen from V_NOTDELETED_FEATURE
             where lower(uniquename) = $quoted_name $obsolete_part";
    }

    my $where_part = '';
    $where_part = " and f.organism_id = " . $self->factory->organism_id
        if $self->factory->organism_id;

    my $sth = $factory->conn->run(
        sub {
            my $sth = $_->prepare($query);
            $sth->execute
                or Bio::Root::Root->throw("unable to validate name/length");
            $sth;
        }
    );

    my $rows_returned = @{ $sth->fetchall_arrayref() };

    if ( $rows_returned == 0 ) {    #look in synonym for an exact match
        warn "looking for a synonym to $quoted_name" if DEBUG;
        my $isth = $factory->conn->run(
            sub {
                my $sth = $_->prepare(
                    "select fs.feature_id from feature_synonym fs, synonym_ s
       						where fs.synonym_id = s.synonym_id and
       						lower(s.synonym_sgml) = $quoted_name $where_part"
                );

                $sth->execute
                    or Bio::Root::Root->throw(
                    "query for name in synonym failed");
                $sth;
            }
        );

        $rows_returned = @{ $isth->fetchall_arrayref() };
        $isth->execute or Bio::Root::Root->throw();

        if ( $rows_returned == 0 )
        {    #look in dbxref for accession number match
            warn "looking in dbxref for $quoted_name" if DEBUG;

            $isth = $factory->conn->run(
                sub {
                    my $sth = $_->prepare(
                        "select feature_id from feature_dbxref fd, dbxref d
         						   where fd.dbxref_id = d.dbxref_id and
               					   lower(d.accession) = $quoted_name $where_part"
                    );
                    $sth->execute
                        or
                        Bio::Root::Root->throw("query for accession failed");
                    $sth;
                }
            );
            $rows_returned = @{ $isth->fetchall_arrayref() };
            return if $rows_returned == 0;

            if ( $rows_returned == 1 ) {
                my $hashref    = $isth->fetchrow_hashref("NAME_lc");
                my $feature_id = $$hashref{'feature_id'};
                return \$feature_id;
            }
            else {
                my @feature_ids;
                while ( my $hashref = $isth->fetchrow_hashref("NAME_lc") ) {
                    push @feature_ids, $$hashref{'feature_id'};
                }
                return \@feature_ids;
            }

        }
        elsif ( $rows_returned == 1 ) {
            my $hashref    = $isth->fetchrow_hashref("NAME_lc");
            my $feature_id = $$hashref{'feature_id'};
            warn "found $feature_id in feature_synonym" if DEBUG;
            return \$feature_id;
        }
        else {
            my @feature_ids;
            while ( my $hashref = $isth->fetchrow_hashref("NAME_lc") ) {
                push @feature_ids, $$hashref{'feature_id'};
            }
            return \@feature_ids;
        }

    }
    elsif ( $rows_returned == 1 ) {
        my $hashref    = $sth->fetchrow_hashref("NAME_lc");
        my $feature_id = $$hashref{'feature_id'};
        warn "feature_id in _search_by_name:$feature_id" if DEBUG;
        return \$feature_id;
    }
    else {
        my @feature_ids;
        while ( my $hashref = $sth->fetchrow_hashref("NAME_lc") ) {
            push @feature_ids, $$hashref{'feature_id'};
        }
        return \@feature_ids;
    }
}

=head2 class

  Title   : class
  Usage   : $obj->class($newval)
  Function: Returns the segment class (synonymous with type)
  Returns : value of class (a scalar)
  Args    : on set, new value (a scalar or undef, optional)

=cut

sub class {
    my $self = shift;

    return $self->{'class'} = shift if @_;
    return $self->{'class'};
}

=head2 start

 Title   : start
 Usage   : $s->start
 Function: start of segment
 Returns : integer
 Args    : none
 Status  : Public

=cut

sub start {
    my $self = shift;
    return undef unless ref $self;
    return $self->{'start'} = shift if @_;
    return $self->{'start'} if $self->{'start'};
    return undef;

}

=head2 end

 Title   : end
 Usage   : $s->end
 Function: end of segment
 Returns : integer
 Args    : none
 Status  : Public

=cut

sub end {
    my $self = shift;
    return undef unless ref $self;
    return $self->{'end'} = shift if @_;
    return $self->{'end'} if $self->{'end'};
    return undef;
}

=head2 length

 Title   : length
 Usage   : $s->length
 Function: length of segment
 Returns : integer
 Args    : none
 Status  : Public

Returns the length of the segment.  Always a positive number.

=cut

sub length { shift->{length} }

=head2 features

 Title   : features
 Usage   : @features = $s->features(@args)
 Function: get features that overlap this segment
 Note    : This method will find all features that intersect the segment in a
           variety of ways and return a list of Bio::SeqFeatureI objects.  The
           feature locations will use coordinates relative to the reference
           sequence in effect at the time that features() was called.

           The returned list can be limited to certain types, attributes or
           range intersection modes.  Types of range intersection are one of:

           "overlaps"      the default
           "contains"      return features completely contained within the segment
           "contained_in"  return features that completely contain the segment
 Returns : a list of Bio::SeqFeatureI objects. 
 Args    : Two types of argument lists are accepted.  In the positional argument
           form, the arguments are treated as a list of feature types.  In the
           named parameter form, the arguments are a series of -name=E<gt>value
           pairs.

           Argument    Description
           --------   ------------

           -types      An array reference to type names in the format "method:source"

           -attributes A hashref containing a set of attributes to match

           -rangetype  One of "overlaps", "contains", or "contained_in".

           -iterator   Return an iterator across the features.

           -callback   A callback to invoke on each feature

           The -attributes argument is a hashref containing one or more
           attributes to match against:

           -attributes => { Gene => 'abc-1',
                        Note => 'confirmed' }

           Attribute matching is simple string matching, and multiple attributes
           are ANDed together.  More complex filtering can be performed using the
           -callback option (see below).

           If -iterator is true, then the method returns an object reference that
           implements the next_seq() method.  Each call to next_seq() returns a
           new Bio::SeqFeatureI object.

           If -callback is passed a code reference, the code reference will be
           invoked on each feature returned.  The code will be passed two
           arguments consisting of the current feature and the segment object
           itself, and must return a true value. If the code returns a false
           value, feature retrieval will be aborted.

           -callback and -iterator are mutually exclusive options.  If -iterator
           is defined, then -callback is ignored.
=cut

sub features {
    my $self = shift;
    warn "Segment->features() args:@_\n" if DEBUG;

    my @sub_args = @_;

    # In some cases (url search : ?name=foo) $self isn't a hash ref ie
    # object but a simple scalar ie string. So we need to get the
    # factory the right way before accessing it
    my ( $factory, $feature_id );
    if ( ref($self) && $self->factory->do2Level ) {
        return $self->_features2level(@sub_args);
    }    # should put an else here to try to get the factory from @_
    else {
        if ( $sub_args[0] and $sub_args[0] =~ /^-/ ) {
            my %args = @_;
            $factory    = $args{-factory}    if ( $args{-factory} );
            $feature_id = $args{-feature_id} if ( $args{-feature_id} );
        }
    }

    my ($types,    $type_placeholder, $attributes, $rangetype,
        $iterator, $callback,         $base_start, $stop,
        $seq_id,   $end
    );
    if ( ref($self) and $sub_args[0] and $sub_args[0] =~ /^-/ ) {
        (   $types,    $type_placeholder, $attributes, $rangetype,
            $iterator, $callback,         $base_start, $stop,
            $seq_id,   $end
            )
            = $self->_rearrange(
            [   qw(TYPES
                    TYPE
                    ATTRIBUTES
                    RANGETYPE
                    ITERATOR
                    CALLBACK
                    START
                    STOP
                    SEQ_ID
                    END )
            ],
            @sub_args
            );
        warn
            "type and types after calling _rearrange:$type_placeholder,$types"
            if DEBUG;
    }
    elsif ( defined $factory and $sub_args[0] and $sub_args[0] =~ /^-/ ) {
        (   $types,    $type_placeholder, $attributes, $rangetype,
            $iterator, $callback,         $base_start, $stop,
            $seq_id,   $end
            )
            = $factory->_rearrange(
            [   qw(TYPES
                    TYPE
                    ATTRIBUTES
                    RANGETYPE
                    ITERATOR
                    CALLBACK
                    START
                    STOP
                    SEQ_ID
                    END )
            ],
            @sub_args
            );
        warn
            "type and types after calling factory->_rearrange:$type_placeholder,$types"
            if DEBUG;

    }
    else {
        warn "didn't call rearrange" if DEBUG;
        $types = \@sub_args;
    }

    #UGG, allow both -types and -type to be used in the args
    if ( $type_placeholder and !$types ) {
        $types = $type_placeholder;
    }

    warn "@$types\n" if ( defined $types and DEBUG );

    $factory ||= $self->factory();
    my $feat = Modware::DB::Adaptor::GBrowse::Segment::Feature->new();
    my @features;

    my ( $interbase_start, $rend, $srcfeature_id, $sql_types );
    unless ($feature_id) {
        $rangetype ||= 'overlaps';

        # set range variable

        $base_start      = defined $base_start ? $base_start : $self->start;
        $interbase_start = $base_start - 1;
        $rend            = defined $end ? $end : $self->end;

        $sql_types = '';

        my $valid_type = undef;
        if ( $types && scalar @$types != 0 ) {

            warn "first type:$$types[0]\n" if DEBUG;

            my $temp_type   = $$types[0];
            my $temp_source = '';
            if ( $$types[0] =~ /(.*):(.*)/ ) {
                $temp_type   = $1;
                $temp_source = $2;
            }

            $valid_type = $factory->name2term($temp_type);
            $self->throw("feature type: '$temp_type' is not recognized")
                unless $valid_type;

            my $temp_dbxref = $factory->source2dbxref($temp_source);
            if ( $temp_source && $temp_dbxref ) {
                $sql_types
                    .= "((f.type_id = $valid_type and fd.dbxref_id = $temp_dbxref)";
            }
            else {
                $sql_types .= "((f.type_id = $valid_type)";
            }

            if ( scalar @$types > 1 ) {
                for ( my $i = 1; $i < ( scalar @$types ); $i++ ) {

                    $temp_type   = $$types[$i];
                    $temp_source = '';
                    if ( $$types[$i] =~ /(.*):(.*)/ ) {
                        $temp_type   = $1;
                        $temp_source = $2;
                    }
                    warn "more types:$$types[$i]\n" if DEBUG;

                    $valid_type = $factory->name2term($temp_type);
                    $self->throw(
                        "feature type: '$temp_type' is not recognized")
                        unless $valid_type;

                    $temp_dbxref = $factory->source2dbxref($temp_source);
                    if ( $temp_source && $temp_dbxref ) {
                        $sql_types
                            .= " OR \n     (f.type_id = $valid_type and fd.dbxref_id = $temp_dbxref)";
                    }
                    else {
                        $sql_types .= " OR \n     (f.type_id = $valid_type)";
                    }
                }
            }
            $sql_types .= ") and ";
        }

        #  $factory->dbh->trace(1) if DEBUG;

        $srcfeature_id = $self->{srcfeature_id} if ref $self;

    }

    if ( !$srcfeature_id && defined($seq_id) ) {

        my $query
            = $factory->organism_id
            ? {
            'name'        => { -like => $seq_id },
            'organism_id' => $factory->organism_id
            }
            : { 'name' => { -like => $seq_id } };

        my $schema = $factory->schema;
        my $row
            = $schema->resultset('Sequence::Feature')
            ->search( { 'UPPER(name)' => uc $seq_id }, { rows => 1 } )
            ->single;
        $srcfeature_id = $row->feature_id;
    }

    my $select_part
        = "select distinct f.name,fl.fmin,fl.fmax,fl.strand,fl.phase,"
        . "fl.locgroup,fl.srcfeature_id,f.type_id,f.uniquename,"
        . "f.feature_id, af.significance as score, "
        . "fd.dbxref_id ";

    my $order_by = "order by f.type_id,fl.fmin ";

    my $where_part;
    my $from_part;
    if ($feature_id) {
        $from_part
            = "from V_NOTDELETED_FEATURE f "
            . "inner join featureloc fl           on fl.feature_id = f.feature_id "
            . "left outer join feature_dbxref fd  on fd.feature_id = f.feature_id "
            . "left outer join dbxref dbx         on dbx.dbxref_id = fd.dbxref_id "
            . "                                   and dbx.db_id     = "
            . $factory->gff_source_db_id
            . " left outer join analysisfeature af on af.feature_id = f.feature_id";

        $where_part = "where f.feature_id = $feature_id and fl.rank=0 ";

        ##URGI Added a sub request to get the refclass srcfeature id to map all the features from this reference region.
        ##We then filter and are sure that we are getting the features located on the reference feature with the good
        ##coordinates.
        my $refclass = $factory->name2term( $factory->default_class() );
        my $refclass_feature_id = $factory->refclass_feature_id() || undef;

        #In case we already have the reference class feature_id
        if ( defined($refclass_feature_id) ) {
            $where_part .= " and fl.srcfeature_id = $refclass_feature_id ";
        }
        elsif ($refclass) {

#From the type_id of the reference class and the feature_id we are working with
#we get the srcfeature_id of the reference class feature
            my $srcquery = "select srcfeature_id ";
            $srcquery
                .= "from featureloc fl join feature f on (fl.srcfeature_id = f.feature_id) ";
            $srcquery .= "where fl.feature_id = ? and f.type_id = $refclass";
            my $sth = $factory->conn->run(
                sub {
                    my $sth = $_->prepare($srcquery);
                    $sth->execute($feature_id)
                        or $self->throw("refclass_srcfeature query failed");
                    $sth;
                }
            );
            my $hashref = $sth->fetchrow_hashref("NAME_lc");
            my $srcfeature_id = $hashref->{srcfeature_id} || undef;
            $where_part .= " and fl.srcfeature_id = $srcfeature_id "
                if defined $srcfeature_id;
        }

    }
    else {

        #warn "gff_source_id is ", $factory->gff_source_db_id;
        $from_part
            = "from V_NOTDELETED_FEATURE f "
            . "inner join featureloc fl           on fl.feature_id = f.feature_id "
            . "left outer join feature_dbxref fd  on fd.feature_id = f.feature_id  "
            . "left outer join dbxref dbx         on dbx.dbxref_id = fd.dbxref_id "
            . "                                   and dbx.db_id     = "
            . $factory->gff_source_db_id
            . "left outer join analysisfeature af on af.feature_id = f.feature_id";

        $where_part
            = "where $sql_types "
            . "fl.srcfeature_id = $srcfeature_id and fl.rank=0 "
            . "and fl.fmin <= $rend and fl.fmax >= $interbase_start ";
    }

    $where_part .= " and f.organism_id = " . $self->factory->organism_id
        if $self->factory && $self->factory->organism_id;

    my $query = "$select_part\n$from_part\n$where_part\n$order_by\n";

    #Recursive Mapping
    #  Construct a query that recursively maps clone's features on
    #  the underlying chromosome
    if ( $factory->recursivMapping && !$feature_id ) {
        my $qFrom = $from_part;
        $qFrom =~ s/featureslice/recurs_featureslice/g;
        $query
            = "$select_part\n$from_part\n$where_part\nUNION\n$select_part\n$qFrom\n$where_part\norder by type_id, fmin";
    }
    $query =~ s/\s+/ /gs if DEBUG;
    warn $query if DEBUG;

    #END Recursive Mapping

    warn "Segement->features query:$query" if DEBUG;

    my $sth = $factory->conn->run(
        sub {
            my $sth = $_->prepare($query);
            $sth->execute or $self->throw("feature query failed");
            $sth;
        }
    );

    while ( my $hashref = $sth->fetchrow_hashref("NAME_lc") ) {
        warn "dbstart:$$hashref{fmim}, dbstop:$$hashref{fmax}" if DEBUG;
        warn "start:$base_start, stop:$stop\n"                 if DEBUG;

        if (   $feature_id
            && defined($stop)
            && $stop != $$hashref{fmax} )
        {
            $stop = $$hashref{fmin} + $stop + 1;
        }
        else {
            $stop = $$hashref{fmax};
        }
        if (   $feature_id
            && defined($base_start)
            && $base_start != ( $$hashref{fmin} + 1 ) )
        {
            my $interbase_start = $$hashref{fmin} + $base_start - 1;
            $base_start = $interbase_start + 1;
        }
        else {
            my $interbase_start = $$hashref{fmin};
            $base_start = $interbase_start + 1;
        }
        warn "base_start:$base_start, end:$stop" if DEBUG;

        my $source = $factory->dbxref2source( $$hashref{dbxref_id} ) || "";
        my $type = Bio::DB::GFF::Typename->new(
            $factory->term2name( $$hashref{type_id} ), $source );

        $feat = Modware::DB::Adaptor::GBrowse::Segment::Feature->new(
            $factory,
            $feature_id ? undef : $self,    #only give the segment as the
                                            # parent if the feature_id wasn't
                                            # provided
            $feature_id
            ? $factory->srcfeature2name( $$hashref{'srcfeature_id'} )
            : $self->seq_id,

            $base_start, $stop,
            $type,
            $$hashref{score},
            $$hashref{strand},
            $$hashref{phase},
            $$hashref{name},
            $$hashref{uniquename}, $$hashref{feature_id}
        );

        push @features, $feat;

        my $fstart = $feat->start() if DEBUG;
        my $fend   = $feat->end()   if DEBUG;

#  warn "$feat->{annotation}, $$hashref{nbeg}, $fstart, $$hashref{nend}, $fend\n" if DEBUG;
    }

    if ($iterator) {
        warn "using Bio::DB::Das::ChadoIterator\n" if DEBUG;
        return Bio::DB::Das::ChadoIterator->new( \@features ) if @features;
    }
    elsif (wantarray) {
        return @features;
    }
    elsif ( @features > 0 ) {
        return \@features;
    }
    else {
        return;
    }
}

=head2 _features2level

  See   : features
  Note  : Its a crude copy past from feature + additionnal code to handle
          prefetching of 2 levels features. The generated query is ~ as
          performant as the one generated by features, and the calls to
          Bio::DB::Das::Chado::Segment->sub_SeqFeatures are avoided, but this
          doesn't lead to a huge performace boost.

          If a further development increases the performances provided by this 2
          level prefetch, we will need to refactor features and _features2level
          to avoid code duplication
=cut

sub _features2level() {
    my $self = shift;

    warn "Segment->_features2level() args:@_\n" if DEBUG;

    my ($types,      $type_placeholder, $attributes, $rangetype,
        $iterator,   $callback,         $base_start, $stop,
        $feature_id, $factory
    );
    if ( $_[0] and $_[0] =~ /^-/ ) {
        (   $types,      $type_placeholder, $attributes, $rangetype,
            $iterator,   $callback,         $base_start, $stop,
            $feature_id, $factory
            )
            = $self->_rearrange(
            [   qw(TYPES
                    TYPE
                    ATTRIBUTES
                    RANGETYPE
                    ITERATOR
                    CALLBACK
                    START
                    STOP
                    FEATURE_ID
                    FACTORY)
            ],
            @_
            );
        warn "$types\n" if DEBUG;
    }
    else {
        $types = \@_;
    }

    #UGG, allow both -types and -type to be used in the args
    if ( $type_placeholder and !$types ) {
        $types = $type_placeholder;
    }

    warn "@$types\n" if ( defined $types and DEBUG );

    $factory ||= $self->factory();
    my $feat = Modware::DB::Adaptor::GBrowse::Segment::Feature->new();
    my @features;

    my ( $interbase_start, $rend, $srcfeature_id, $sql_types );
    unless ($feature_id) {
        $rangetype ||= 'overlaps';

        # set range variable

        $base_start      = $self->start;
        $interbase_start = $base_start - 1;
        $rend            = $self->end;

        $sql_types = '';

        my $valid_type = undef;
        if ( scalar @$types != 0 ) {

            warn "first type:$$types[0]\n" if DEBUG;

            my $temp_type   = $$types[0];
            my $temp_source = '';
            if ( $$types[0] =~ /(.*):(.*)/ ) {
                $temp_type   = $1;
                $temp_source = $2;
            }

            $valid_type = $factory->name2term($temp_type);
            $self->throw("feature type: '$temp_type' is not recognized")
                unless $valid_type;

            my $temp_dbxref = $factory->source2dbxref($temp_source);
            if ( $temp_source && $temp_dbxref ) {
                $sql_types
                    .= "((f.type_id = $valid_type and fd.dbxref_id = $temp_dbxref)";
            }
            else {
                $sql_types .= "((f.type_id = $valid_type)";
            }

            if ( scalar @$types > 1 ) {
                for ( my $i = 1; $i < ( scalar @$types ); $i++ ) {

                    $temp_type   = $$types[$i];
                    $temp_source = '';
                    if ( $$types[$i] =~ /(.*):(.*)/ ) {
                        $temp_type   = $1;
                        $temp_source = $2;
                    }
                    warn "more types:$$types[$i]\n" if DEBUG;

                    $valid_type = $factory->name2term($temp_type);
                    $self->throw(
                        "feature type: '$temp_type' is not recognized")
                        unless $valid_type;

                    $temp_dbxref = $factory->source2dbxref($temp_source);
                    if ( $temp_source && $temp_dbxref ) {
                        $sql_types
                            .= " OR \n     (f.type_id = $valid_type and fd.dbxref_id = $temp_dbxref)";
                    }
                    else {
                        $sql_types .= " OR \n     (f.type_id = $valid_type)";
                    }
                }
            }
            $sql_types .= ") and ";
        }
        $srcfeature_id = $self->{srcfeature_id};
    }

    my $select_part
        = "select distinct f.name,fl.fmin,fl.fmax,fl.strand,fl.phase,"
        . "fl.locgroup,fl.srcfeature_id,f.type_id,f.uniquename,"
        . "f.feature_id, af.significance as score, "
        . "fd.dbxref_id";

    my $order_by = "order by f.type_id,fl.fmin ";
    my $where_part;
    my $from_part;
    if ($feature_id) {
        $from_part
            = "from (feature f join featureloc fl ON (f.feature_id = fl.feature_id)) "
            . "left join feature_dbxref fd ON 
            (f.feature_id = fd.feature_id 
            AND fd.dbxref_id in (select dbxref_id from dbxref where db_id="
            . $factory->gff_source_db_id . ")) "
            . "left join analysisfeature af ON (af.feature_id = f.feature_id) ";

        $where_part = " where f.feature_id = $feature_id and fl.rank=0 ";
        $where_part .= " and f.organism_id = " . $self->factory->organism_id
            if $self->factory->organism_id;

        ##URGI Added a sub request to get the refclass srcfeature id to map all the features from this reference region.
        ##We then filter and are sure that we are getting the features located on the reference feature with the good
        ##coordinates.
        my $refclass = $factory->name2term( $factory->default_class() );
        my $refclass_feature_id = $factory->refclass_feature_id() || undef;

        #In case we already have the reference class feature_id
        if ( defined($refclass_feature_id) ) {
            $where_part .= " and fl.srcfeature_id = $refclass_feature_id ";
        }
        elsif ($refclass) {

#From the type_id of the reference class and the feature_id we are working with
#we get the srcfeature_id of the reference class feature
            my $srcquery = "select srcfeature_id ";
            $srcquery
                .= "from featureloc fl join feature f on (fl.srcfeature_id = f.feature_id) ";
            $srcquery .= "where fl.feature_id = ? and f.type_id = $refclass";

            my $sth = $factory->conn->run(
                sub {
                    my $sth = $_->prepare($srcquery);
                    $sth->execute($feature_id)
                        or $self->throw("refclass_srcfeature query failed");
                    $sth;
                }
            );
            my $hashref = $sth->fetchrow_hashref("NAME_lc");
            my $srcfeature_id = $hashref->{srcfeature_id} || undef;
            $where_part .= " and fl.srcfeature_id = $srcfeature_id "
                if ( defined($srcfeature_id) );
        }

    }
    else {
        my $featureslice;
        if ( $factory->srcfeatureslice ) {
            $featureslice
                = "featureloc_slice($srcfeature_id,$interbase_start, $rend)";
        }
        else {
            $featureslice = "featureslice($interbase_start, $rend)";
        }
        $from_part
            = "from ((feature f join $featureslice fl ON (f.feature_id = fl.feature_id)) "
            . "left join feature_dbxref fd ON 
            (f.feature_id = fd.feature_id
            AND fd.dbxref_id in (select dbxref_id from dbxref where db_id="
            . $factory->gff_source_db_id . ")) "
            . "left join analysisfeature af ON (af.feature_id = f.feature_id)) "
            . 'left join feature_relationship fr on (f.feature_id = fr.object_id)  left  join feature sub_f on (sub_f.feature_id = fr.subject_id) left  join featureloc sub_fl on  (sub_f.feature_id=sub_fl.feature_id) ';

        $where_part
            = "where $sql_types "
            . "fl.srcfeature_id = $srcfeature_id and fl.rank=0 "
            . ' AND (fl.locgroup=sub_fl.locgroup OR sub_fl.locgroup is null) ';
    }

    $select_part
        .= ', sub_f.name as sname,sub_fl.fmin as sfmin,sub_fl.fmax as sfmax,sub_fl.strand as sstrand,sub_fl.phase as sphase,sub_fl.locgroup as slocgroup,sub_f.type_id as stype_id,sub_f.uniquename as suniquename,sub_f.feature_id as sfeature_id';
    my $query = "$select_part\n $from_part\n$where_part\n$order_by\n";

    $query =~ s/\s+/ /gs if DEBUG;
    warn $query if DEBUG;

    warn "Segement->features query:$query" if DEBUG;

    my $sth = $factory->conn->run(
        sub {
            my $sth = $_->prepare($query);
            $sth->execute or $self->throw("feature query failed");
            $sth;
        }
    );

#2Level Optimisation
#each feature is spaned over several tuples, each of which store a different SUBfeature (only one tuple if no subfeat of course)

    while ( my $hashref = $sth->fetchrow_hashref("NAME_lc") ) {

        warn "dbstart:$$hashref{fmim}, dbstop:$$hashref{fmax}" if DEBUG;
        warn "start:$base_start, stop:$stop\n"                 if DEBUG;

        if ( !defined( $feat->feature_id )
            || $feat->feature_id != $$hashref{feature_id} )
        {

            #either first feature or new feature
            if ( defined( $feat->feature_id )
                && $feat->feature_id != $$hashref{feature_id} )
            {

                # not the first feat , adding the previous feat
                push @features, $feat;

            }
            if (   $feature_id
                && defined($stop)
                && $stop != $$hashref{fmax} )
            {
                $stop = $$hashref{fmin} + $stop + 1;
            }
            else {
                $stop = $$hashref{fmax};
            }
            if (   $feature_id
                && defined($base_start)
                && $base_start != ( $$hashref{fmin} + 1 ) )
            {
                my $interbase_start = $$hashref{fmin} + $base_start - 1;
                $base_start = $interbase_start + 1;
            }
            else {
                my $interbase_start = $$hashref{fmin};
                $base_start = $interbase_start + 1;
            }
            warn "base_start:$base_start, end:$stop" if DEBUG;

            my $source = $factory->dbxref2source( $$hashref{dbxref_id} )
                || "";
            my $type = Bio::DB::GFF::Typename->new(
                $factory->term2name( $$hashref{type_id} ), $source );

            $feat = Modware::DB::Adaptor::GBrowse::Segment::Feature->new(
                $factory,
                $feature_id ? undef : $self, #only give the segment as the
                                             # parent if the feature_id wasn't
                                             # provided
                $feature_id
                ? $factory->srcfeature2name( $$hashref{'srcfeature_id'} )
                : $self->seq_id,

                $base_start, $stop,
                $type,
                $$hashref{score},
                $$hashref{strand},
                $$hashref{phase},
                $$hashref{name},
                $$hashref{uniquename},
                $$hashref{feature_id}
            );
            print STDERR
                "Created Feature obj $$hashref{name}][[$$hashref{feature_id}][$$hashref{'srcfeature_id'}]\n"
                if DEBUG;
        }

        #handling sub feat, if any
        if ( $$hashref{sfeature_id} ) {
            if (   $feature_id
                && defined($stop)
                && $stop != $$hashref{sfmax} )
            {
                $stop = $$hashref{sfmin} + $stop + 1;
            }
            else {
                $stop = $$hashref{fmax};
            }
            if (   $feature_id
                && defined($base_start)
                && $base_start != ( $$hashref{sfmin} + 1 ) )
            {
                my $interbase_start = $$hashref{sfmin} + $base_start - 1;
                $base_start = $interbase_start + 1;
            }
            else {
                my $interbase_start = $$hashref{sfmin};
                $base_start = $interbase_start + 1;
            }
            warn "base_start:$base_start, end:$stop" if DEBUG;

            my $source = $factory->dbxref2source( $$hashref{dbxref_id} )
                || "";
            my $type = Bio::DB::GFF::Typename->new(
                $factory->term2name( $$hashref{stype_id} ), $source );

            my $subFeat = Modware::DB::Adaptor::GBrowse::Feature->new(
                $factory,
                $feat,
                $feature_id
                ? $factory->srcfeature2name( $$hashref{'srcfeature_id'} )
                : $self->seq_id,

                #$base_start,$stop,
                $$hashref{sfmin} + 1, $$hashref{sfmax},
                $type,
                $$hashref{score},  #TODO : add the subfeat score, not the feat
                $$hashref{sstrand},
                $$hashref{sphase},
                $$hashref{sname},
                $$hashref{suniquename}, $$hashref{sfeature_id}
            );

            #adding the subfeat to its parent, ie $feat
            # $feat->subfeatures($subFeat);
            $feat->add_subfeature($subFeat);

#warn $feat->feature_id . ":".$feat->start  ."..".$feat->end  ."  base_start:$base_start, end:$stop";
        }    #end of the subfeat handling

        my $fstart = $feat->start() if DEBUG;
        my $fend   = $feat->end()   if DEBUG;

#  warn "$feat->{annotation}, $$hashref{nbeg}, $fstart, $$hashref{nend}, $fend\n" if DEBUG;

    }    #end while hashref loop

#We check if the last feature creatd is the same as the last pushed in the array
    if ( @features > 0 && $features[-1]->feature_id() ne $feat->feature_id() )
    {
        push @features, $feat;
    }

    if ($iterator) {
        warn "using Bio::DB::Das::ChadoIterator\n" if DEBUG;
        return Bio::DB::Das::ChadoIterator->new( \@features ) if @features;
    }
    elsif (wantarray) {
        return @features;
    }
    else {
        return \@features;
    }
}

sub get_SeqFeatures {return}

=head2 dna

 Title   : dna
 Usage   : $s->dna
 Function: get the dna string this segment. Returns the sequence for this segment as a string.
 Returns : a string
 Args    : none
 Status  : Public

=cut

sub dna {
    my $self = shift;
    my %arg  = @_;
    my ( $ref, $class, $base_start, $stop, $strand )
        = @{$self}{qw(sourceseq class start end strand)};

    warn "ref:$ref, class:$class, $base_start..$stop, ($strand)\n" if DEBUG;

    if ( $arg{self} ) {
        my $r_id = $self->feature_id;

        $self->warn(
            "FIXME: incomplete implementation of alternate sequence selection"
        ) if $self->verbose;

        my $sth = $self->factory->dbh->prepare( "
      select residues from V_NOTDELETED_FEATURE
      where feature_id = $r_id " );

        $sth->execute or $self->throw("seq query failed");

        my $array_ref = $sth->fetchrow_arrayref;
        my $seq       = $$array_ref[0];
        return $seq;
    }

    my $feat_id = $self->{srcfeature_id};

    my $has_start = defined $base_start;
    my $has_stop  = defined $stop;

    my $reversed;
    if ( $has_start && $has_stop && $base_start > $stop ) {
        $reversed++;
        ( $base_start, $stop ) = ( $stop, $base_start );
    }
    elsif ( $strand && $strand < 0 ) {
        $reversed++;
    }

    my $sth;
    if ( !$has_start and !$has_stop ) {
        $sth = $self->factory->dbh->prepare( "
     select residues from V_NOTDELETED_FEATURE
     where feature_id = $feat_id " );
    }
    elsif ( !$has_start ) {
        $sth = $self->factory->dbh->prepare( "
     select substr(residues, $stop) from V_NOTDELETED_FEATURE
     where feature_id = $feat_id " );
    }
    elsif ( !$has_stop ) {
        $sth = $self->factory->dbh->prepare( "
     select substr(residues, $base_start) from V_NOTDELETED_FEATURE
     where feature_id = $feat_id " );
    }
    else {    #has both start and stop
        my $sslen = $stop - $base_start + 1;
        $sth = $self->factory->dbh->prepare( "
     select substr(residues, $base_start, $sslen) from V_NOTDELETED_FEATURE
     where feature_id = $feat_id " );
    }

    $sth->execute or $self->throw("seq query failed");

    my $array_ref = $sth->fetchrow_arrayref;
    my $seq       = $$array_ref[0];

    if ($reversed) {
        $seq = reverse $seq;
        $seq =~ tr/gatcGATC/ctagCTAG/;
    }

    return $seq;
}

sub subseq {
    my $self = shift;
    my ( $start, $stop ) = @_;
    $start--;

    my $dna    = $self->dna;
    my $length = $stop - $start + 1;

    my $substr = substr( $dna, $start, $length );

    my $subseqobj = Bio::Seq->new(
        -display_id => $self->seq_id,
        -seq        => $substr
    );

    return $subseqobj;
}

=head2 seq

 Title   : seq
 Usage   : $s->seq
 Function: get a Bio::Seq object for this segment
 Note    : Returns the sequence for this segment as a Bio::Seq object.
 Returns : a Bio::Seq object
 Args    : none
 Status  : Public

=cut

sub seq {
    my $self = shift;

    my $seqobj = Bio::Seq->new(
        -display_id => $self->seq_id . ":" . $self->start . ".." . $self->end,
        -seq        => $self->dna,
    );

    return $seqobj;
}

=head2 factory

 Title   : factory
 Usage   : $factory = $s->factory
 Function: return the segment factory
 Note    : This method returns a Bio::DasI object that can be used to fetch
           more segments.  This is typically the Bio::DasI object from which
           the segment was originally generated.
 Returns : a Bio::DasI object
 Args    : see below
 Status  : Public

=cut

#sub factory {shift->{factory} }

sub factory {
    my $self = shift;
    return unless ref $self;
    return $self->{factory};
}

=head2 srcfeature_id

  Title   : srcfeature_id
  Usage   : $obj->srcfeature_id($newval)
  Function: undocumented method by Scott Cain
  Returns : value of srcfeature_id (a scalar)
  Args    : on set, new value (a scalar or undef, optional)

=cut

sub srcfeature_id {
    my $self = shift;
    return unless ref $self;
    return $self->{'srcfeature_id'} = shift if @_;
    return $self->{'srcfeature_id'};
}

=head2 alphabet

  Title   : alphabet
  Usage   : $obj->alphabet($newval)
  Function: undocumented method by Scott Cain
  Returns : scalar 'dna'
  Args    : on set, new value (a scalar or undef, optional)

=cut

sub alphabet {
    return 'dna';
}

#dgg patch for SeqI.desc -- use ref segment Note property for description
sub desc {
    my $self = shift;
    return $self->{'desc'} if defined $self->{'desc'};

    my $sth = $self->factory->conn->run(
        sub {
            my $sth = $_->prepare(
                "select value from featureprop 
    			where feature_id =  ? and type_id in (select cvterm_id from cvterm where name = 'description') "
            );
            $sth->execute( $self->feature_id );
            $sth;
        }
    );
    my $hashref = $sth->fetchrow_hashref("NAME_lc");
    return $self->{'desc'} = $hashref->{value};
}

#dgg patch for SeqI -- Bio::SeqI::species
sub species {
    my $self = shift;
    return $self->{'species'} if defined $self->{'species'};

    my $sth = $self->factory->conn->run(
        sub {
            my $sth = $_->prepare(
                "select genus,species from organism 
    where organism_id = (select organism_id from V_NOTDELETED_FEATURE where feature_id = ?) "
            );
            $sth->execute( $self->srcfeature_id );
            $sth;
        }
    );
    my $hashref = $sth->fetchrow_hashref("NAME_lc");
    my $spp     = $hashref->{genus} . ' '
        . $hashref->{species};    # works for display uses
    return $self->{'species'} = $spp;
}

=head2 get_feature_stream

  Title   : get_feature_stream
  Usage   : $db->get_feature_stream(@args)
  Function: creates a feature iterator
  Returns : A Bio::DB::Das::ChadoIterator object
  Args    : The same arguments as the feature method

=cut

sub get_feature_stream {
    my $self     = shift;
    my @args     = @_;
    my $features = $self->features(@args);
    warn "get_feature_stream args: @_\n"               if DEBUG;
    warn "using get_feature_stream\n"                  if DEBUG;
    warn "feature array: $features\n"                  if DEBUG;
    warn "first feature: $$features[0]\n"              if DEBUG;
    return Bio::DB::Das::ChadoIterator->new($features) if $features;
    return;
}

=head2 clone

 Title   : clone
 Usage   : $copy = $s->clone
 Function: make a copy of this segment
 Returns : a Bio::DB::GFF::Segment object
 Args    : none
 Status  : Public

=cut

sub clone {
    my $self = shift;
    my %h    = %$self;
    return bless \%h, ref($self);
}

=head2 sourceseq

  Title   : sourceseq
  Usage   : $obj->sourceseq($newval)
  Function: undocumented method by Scott Cain
  Returns : value of sourceseq (a scalar)
  Args    : on set, new value (a scalar or undef, optional)


=cut

sub sourceseq {
    my $self = shift;

    return $self->{'sourceseq'} if $self->{'sourceseq'};

    my $sth = $self->factory->conn->run(
        sub {
            my $sth = $dbh->prepare( "select name from V_NOTDELETED_FEATURE where feature_id = ?" );
            $sth->execute( $self->srcfeature_id )
                or $self->throw("getting sourceseq name query failed");
            $sth;
        }
    );

    my $rows_returned = @{ $sth->fetchall_arrayref() };
    $sth->execute or Bio::Root::Root->throw("unable to validate name/length");

    return if $rows_returned < 1;
    my $hashref = $sth->fetchrow_hashref("NAME_lc");

    $self->{'sourceseq'} = $$hashref{'name'};
    return $self->{'sourceseq'};

}

=head2 asString

 Title   : asString
 Usage   : $s->asString
 Function: human-readable string for segment
 Returns : a string
 Args    : none
 Status  : Public

Returns a human-readable string representing this sequence.  Format
is:

   sourceseq:start,stop

=cut

sub asString {
    my $self  = shift;
    my $label = $self->refseq;
    my $start = $self->start;
    my $stop  = $self->stop;
    return "$label:$start,$stop";
}

sub primary_id {return}

sub overlaps {
    my $self          = shift;
    my $other_segment = shift or return;
    my $start         = $self->start;
    my $end           = $self->end;
    my $other_start   = $other_segment->start;
    my $other_end     = $other_segment->end;

    return $end >= $other_start && $start <= $other_end;
}

=head2 abs2rel

 Title   : abs2rel
 Usage   : @rel_coords = $s->abs2rel(@abs_coords)
 Function: convert absolute coordinates into relative coordinates
 Returns : a list of relative coordinates
 Args    : a list of absolute coordinates
 Status  : Public

This function takes a list of positions in absolute coordinates
and returns a list expressed in relative coordinates.

=cut

sub abs2rel {
    my $self = shift;
    my @result;

    my ( $start, $strand ) = ( $self->start, $self->abs_strand );
    @result
        = $strand < 0
        ? map { $start - $_ + 1 } @_
        : map { $_ - $start + 1 } @_;

  # if called with a single argument, caller will expect a single scalar reply
  # not the size of the returned array!
    return $result[0] if @result == 1 and !wantarray;
    @result;
}

=head2 rel2abs

 Title   : rel2abs
 Usage   : @coords = $s->rel2abs(@coords)
 Function: convert relative coordinates into absolute coordinates
 Returns : a list of absolute coordinates
 Args    : a list of relative coordinates
 Status  : Public

This function takes a list of positions in relative coordinates to the
segment, and converts them into absolute coordinates.

=cut

sub rel2abs {
    my $self = shift;
    my @result;

    if ( $self->absolute ) {
        @result = @_;
    }
    else {
        my ( $abs_start, $abs_strand )
            = ( $self->abs_start, $self->abs_strand );
        @result
            = $abs_strand < 0
            ? map { $abs_start - $_ + 1 } @_
            : map { $_ + $abs_start - 1 } @_;
    }

  # if called with a single argument, caller will expect a single scalar reply
  # not the size of the returned array!
    return $result[0] if @result == 1 and !wantarray;
    @result;
}

######################################################################
# Aliases
######################################################################

*abs_strand = \&strand;

=head2 type

  Title   : type
  Usage   : $obj->type($newval)
  Function: alias of class() for backward compatibility
  Returns : value of type (a scalar)
  Args    : on set, new value (a scalar or undef, optional)

=cut

*type = \&class;

=head2 display_id, display_name, accession_number, desc, seq_id

  Title   : display_id, display_name, accession_number, desc, seq_id
  Function: Alias of name
  Returns : string
  Args    : none

=cut

*display_id = *display_name = *accession_number = *seq_id = \&name;

=head2 low, abs_start

 Title   : low, abs_start
 Function: Alias of start
 Returns : value of start (a scalar)
 Args    : none
 Status  : Public

=cut

*low = *abs_start = \&start;

=head2 high, stop, abs_end

 Title   : high, stop, abs_end
 Function: Alias of end
 Returns : integer
 Args    : none
 Status  : Public

=cut

*high = *stop = *abs_end = \&end;

=head2 get_all_SeqFeature, get_SeqFeatures, top_SeqFeatures, all_SeqFeatures

 Title   : get_all_SeqFeature, get_SeqFeatures, top_SeqFeatures, all_SeqFeatures
 Function: get the sequence string for this segment
 Note    : Several aliases of features() for backward compatibility
 Returns : a string
 Args    : none
 Status  : Public
 
=cut

*get_all_SeqFeature = *top_SeqFeatures = *all_SeqFeatures = \&features;

=head2 abs_ref

  Title   : abs_ref
  Usage   : $obj->abs_ref()
  Function: Alias of sourceseq
  Returns : value of sourceseq (a scalar)
  Args    : none

Alias of sourceseq for backward compatibility

=cut

*abs_ref = \&sourceseq;

*protein = \&dna;

*get_seq_stream = \&get_feature_stream;

1;