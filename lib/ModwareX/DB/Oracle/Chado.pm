=head1 NAME

    dicty::DB::Oracle::Chado

=head1 SYNOPSIS

    dicty::DB::Oracle::Chado is a Class::DBI driver.
    The only way to use it is to inherit from it:

    package Some::DB::Class;
    use base ' dicty::DB::Oracle::Chado'

  =head1 DESCRIPTION

   dicty::DB::Oracle::Chado exists for multiple reasons

   1. The Oracle driver on CPAN (Class::DBI::Oracle) is not sufficient. It does not rewrite queries
      based on clob columns, this is why we override the _do_search method. For example if you search 
      a CLOB column even for an exact match, you must use LIKE.  This driver rewrites CLOB queries
      to use the LIKE operator instead of the '=' operator
   2. To handle mod_perl and non-mod-perl connection caching (see db_Main method)
   3. 
   

  =head1 AUTHOR - Your Name

    Your Name your_email@northwestern.edu

=head1 APPENDIX

    The rest of the documentation details each of the object
    methods. Internal methods are usually preceded with a _

=cut

package dicty::DB::Oracle::Chado;
use strict;
#use dicty::Root;
use Carp;
use base 'Class::DBI';
use vars qw($VERSION);

$VERSION = '0.01';

# connection options for the database
my $db_options = {
    RaiseError         => 1,
    AutoCommit         => 0,
    FetchHashKeyName   => 'NAME_lc',
    ShowErrorStatement => 2,
    ChopBlanks         => 1,
    RootClass          => 'DBIx::ContextualFetch',
    LongReadLen        => 2**25
};

# store database handle here for caching (non mod_perl)
my $global_dbh;

# need to turn set this variable to 'off'
# with it on, each row object is a singleton
# this breaks previously written code in tests
# where we have two of the same objects in memory
# for example see dicty/lib/MRNA.t

$Class::DBI::Weaken_Is_Available = 0;

#
#  This code is taken from Class::DBI::Oracle
#  all the methods are either new here or overridden from there -- you
#  won't need Class::DBI::Oracle
#
# Setup an alias if the tablename is an Oracle reserved word -
# for example if the class name is: user
# make the table_alias q["user"]
#
# Note: actually not all oracle reserved words (v$reserved_words) seem
# to be a problem, but these have been identified

my @problemWords = qw{
        ACCESS ADD ALL ALTER AND ANY AS ASC AUDIT BETWEEN BY CHAR CHECK CLUSTER
        COLUMN COMMENT COMPRESS CONNECT CREATE CROSS CURRENT CURRENT_DATE
        CURRENT_TIMESTAMP CURSOR_SPECIFIC_SEGMENT DATE DBTIMEZONE DECIMAL
        DEFAULT DELETE DESC DISTINCT DROP ELSE ESCAPE EXCLUSIVE EXISTS FALSE
        FILE FLOAT FOR FROM GRANT GROUP HAVING IDENTIFIED IMMEDIATE IN INCREMENT
        INDEX INITIAL INSERT INTEGER INTERSECT INTO IS JOIN LDAP_REG_SYNC_INTERVAL
        LEVEL LIKE LOCALTIMESTAMP LOCK LOGICAL_READS_PER_SESSION LONG MAXEXTENTS
        MINUS MLSLABEL MODE MODIFY NLS_SORT NOAUDIT NOCOMPRESS NOT NOWAIT NULL
        NUMBER OF OFFLINE ON ONLINE OPTION OR ORDER PASSWORD_VERIFY_FUNCTION
        PRIOR PRIVILEGES PUBLIC RAW RENAME RESOURCE REVOKE ROW ROWID ROWNUM ROWS
        SELECT SESSION SESSIONTIMEZONE SET SHARE SIZE SMALLINT START SUCCESSFUL
        SYNONYM SYSDATE SYSTIMESTAMP SYS_OP_BITVEC SYS_OP_ENFORCE_NOT_NULL$ TABLE
        THEN TO TRIGGER UID UNION UNIQUE UPDATE USER VALIDATE VALUES VARCHAR
        VARCHAR2 VIEW WHENEVER WHERE WITH
};

# Class::DBI uses this to get the next value of a sequence
__PACKAGE__->set_sql('Nextval', <<'');
SELECT %s.NEXTVAL from DUAL

=head2 owner

 Title    : owner
 Usage    : my $owner = $self->owner();
 Function : returns owner for the schema of the table being set up
          : Need this because sometimes we query the CGM_DDB schema
          : Even though we are logged in as CGM_CHADO
 Returns  : owner string
 Args     : none

=cut

sub owner {
   $ENV{'CHADO_USER'};
}

=head2 get_single_row

 Title    : get_single_row
 Usage    : my $record = dicty::DB::Some_class->get_single_row( id => $some_id );
 Function : Gets a single record based on criteria.  Throws error if more than one recor
 Returns  : Class::DBI object
 Args     : user specifiec (passed to search method)

=cut

sub get_single_row {
   my ($proto, @args) = @_;
   my $class = ref $proto || $proto;

   my @dbxrefs  = $class->search( @args );

   my $count = @dbxrefs;
   die "only one row expected, @dbxrefs returned" if @dbxrefs > 1;

   return $dbxrefs[0];
}

=head2 db_Main

 Title    : db_Main
 Usage    : Used internally
 Function : connects to the database based on environment variables
          : Caches database handle in both mod_perl and non-mod_perl environments
 Returns  : DBI database handle
 Args     : none

=cut

sub db_Main {
    my $dbh;

    if ( $ENV{ 'MOD_PERL' } ) {

        if ( $ENV{ 'MOD_PERL' }
            && !$Apache::Server::Starting && !$Apache::Server::ReStarting ) {
            $dbh = Apache2::RequestUtil->request()->pnotes( 'dbh' );
        }
        if ( !$dbh ) {
            #Apache2::RequestUtil->request()->warn( "Creating HANDLE" );

            # $config is my config object. replace with your own settings...
            $dbh =
                DBI->connect_cached( "dbi:Oracle:$ENV{'DATABASE'}", "$ENV{'CHADO_USER'}", "$ENV{'CHADO_PW'}", $db_options )
                || die $DBI::errstr;

            if ( !$Apache::Server::Starting ) {
                Apache2::RequestUtil->request()->pnotes( 'dbh', $dbh );
            }
        }
        #Apache2::RequestUtil->request()->warn( "RETURNING HANDLE" );
        return $dbh;
    }
    else {

        if ( !$global_dbh ) {

            $global_dbh =
                DBI->connect_cached( "dbi:Oracle:$ENV{'DATABASE'}", "$ENV{'CHADO_USER'}", "$ENV{'CHADO_PW'}", $db_options )
                || die $DBI::errstr;
        }

        return $global_dbh;
    }

}


=head2 _die

 Title    : _die
 Usage    : Used internally
 Function : Throws errors using dicty::Root which will 
          : output a nice stack trace
 Returns  : DBI database handle
 Args     : none

=cut

sub _die { 
   my ($class, @args ) = @_;
   confess @args;
}

sub legacy {

    my $ldbh
        = DBI->connect_cached( "dbi:Oracle:$ENV{DATABASE}", $ENV{DBUSER},
        $ENV{PASSWORD}, $db_options )
        || die $DBI::errstr;
    return $ldbh;
}



=head2 set_up_table

 Title    : set_up_table
 Usage    : package dicty::DB::SomeTable;
          : dicty::DB::SomeTable->set_up_table( 'SOME_TABLE' );
 Function : The workhorse, this queries the system tables
          : and sets up a class based on the table and column
          : definitions.  Ripped from Class::DBI::Oracle and modified
          : Adds Clob group
 Returns  : Nothing
 Args     : the name of a database table

=cut

sub set_up_table {
        my($class, $table) = @_;
        my $dbh = $class->db_Main();

        $class->table($table);

        $table = uc $table;

        # alias the table if needed.
        (my $alias = $class) =~ s/.*:://g;
        $class->table_alias(qq["$alias"]) if grep /$alias/i, @problemWords;

        # find the primary key and column names.
        my $sql = qq[
                select         lower(a.column_name), b.position, a.data_type
                from         all_tab_columns a,
                                (
                                select         column_name, position
                                from           all_constraints a, all_cons_columns b
                                where         a.constraint_name = b.constraint_name
                                and        a.constraint_type = 'P'
                                and        a.table_name = ?
                                and a.owner = b.owner
                                and b.owner = ?
                                ) b
                where         a.column_name = b.column_name (+)
                and        a.table_name = ?
                and        a.owner = ?
                    order by position, a.column_name];


        my $sth = $dbh->prepare($sql);

        $sth->execute($table,$class->owner(),$table,$class->owner());

        my $col = $sth->fetchall_arrayref;
        $sth->finish();

        # deal with old revisions
        my $msg;
        my @primary = ();

        $msg = qq{has no primary key} unless $col->[0][1];

        # Class::DBI >= 0.93 can use multiple-primary-column keys.
        if ($Class::DBI::VERSION >= 0.93) {

                map { push @primary, $_->[0] if $_->[1] } @$col;

        } else {

                $msg = qq{has a composite primary key} if $col->[1][1];

                push @primary, $col->[0][0];
        }

        _die('The "',$class->table,qq{" table $msg}) if $msg;

        $class->columns(All => map {$_->[0]} @$col);
        $class->columns(Primary => @primary);

        #
        # add a 'Clob' group to help construct queries involving "CLOBS"
        #
        $class->columns(Clob => map {$_->[0]} grep {$_->[2] eq "CLOB"} @$col);

        # finally, set up sequence
        my $seq_name = $class->Sequence_name_from_table( $table, $primary[0] );
        $class->sequence($class->owner() .".". $seq_name);

        # Now, prepend table with owner
        $class->table( $class->owner() .".". $class->table() );
}


=head2 write_table_config

 Title    : write_table_config
 Usage    : package dicty::DB::SomeTable;
          : dicty::DB::SomeTable->write_table_config( 'SOME_TABLE' );
 Function : Prints a static definition of the class.  Very handy for performance
          : If you load the output of this method as a class, you get
          : tables set up witout having to call set_up_table which can 
          : take a while to query all those system tables.
          : Good point: performance
          : Bad point: You have to regenerate static classes when you make changes to
          : the database
 Returns  : Nothing
 Args     : the name of a database table

=cut

sub write_table_config {
        my($class, $table) = @_;

        $class->set_up_table($table) if !$class->columns();

        (my $alias = $class) =~ s/.*:://g;

        print "$class->table('$table');\n";
        print "$class->table_alias(".qq["$alias"].");\n" if grep /$alias/i, @problemWords;
        my $col_name_str = join ",", $class->columns('All');
        print "$class->columns(All =>($col_name_str));\n";

        my $primary_str = join ",", $class->columns('Primary');
        print "$class->columns(Primary =>($primary_str));\n";

        my $clob_name_str = join ",", $class->columns('Clob');
        print "$class->columns(Clob =>($clob_name_str));\n";

        my $sequence_str = $class->sequence();
        print "$class->sequence('$sequence_str');\n" if $sequence_str;

}


=head2 _auto_increment_value

 Title    : _auto_increment_value
 Usage    : Used internally (overridden from Class:DBI)
 Function : select the last sequence value for the last inserted record
          : will return nothing if there is not an inserted record in the
          : current session
 Returns  : number
 Args     : nothting

=cut

sub _auto_increment_value {
   my($class, @args) = @_;
   my $dbh = $class->db_Main();

   # Oracle's way of gettting the sequence value
   my $sth = $dbh->prepare("
      SELECT ".$class->sequence().".CURRVAL FROM DUAL
   ");

   $sth->execute();

   my $returnvalue = $sth->fetchrow();

   $sth->finish;

   return $returnvalue;
}



=head2 _do_search

 Title    : _do_search
 Usage    : Used internally (overridden from Class:DBI)

  have to override this method to account for Oracle queries involving CLOB datatypes

  In Oracle you cannot have a query like
   select column from table where clob_column = ?

   and clob_colum has type 'CLOB'
   you'll get ORA-00932: inconsistent datatypes: expected - got CLOB (DBD ERROR)

   You can do
    select column from table where clob_column like ?

   and as long as theres no wildcards it should yeild the same result

   This overriden subroutine uses the 'Clob' group added for columns with Clob datatype
   defined in set_table. and changes the search type to 'LIKE' when the search type is "="
   and the column is a CLOB column

 Returns  : Array of class::DBI::Objects
 Args     : 

=cut

sub _do_search {
        my ($proto, $search_type, @args) = @_;
        my $class = ref $proto || $proto;
        @args = %{ $args[0] } if ref $args[0] eq "HASH";
        my (@cols, @vals);
        my $search_opts = @args % 2 ? pop @args : {};

     while (my ($col, $val) = splice @args, 0, 2) {


                my $column = $class->find_column($col)
                        || (first { $_->accessor eq $col } $class->columns)
                        || $class->_croak("$col is not a column of $class");
                push @cols, $column;
                push @vals, $class->_deflated_column($column, $val);
        }

        my $frag = join " AND ", map {
        my $is_clob = grep{ $_ eq "Clob" } $_->groups();
        my $my_search_type = ( $is_clob && ( $search_type eq "=" ) ) ? "LIKE" : $search_type;
        "$_ $my_search_type ?";
     } @cols;
        $frag .= " ORDER BY $search_opts->{order_by}" if $search_opts->{order_by};

     my @newvals;
     foreach my $value ( @vals ) {
        if ( length( $value ) > 4000 ) {
           push @newvals, substr( $value,0,4000 );
           warn "Searching with really long value - truncating value ".substr( $value,0,20 ).'...'." to 4000 characters\n";
        }
        else {
           push @newvals, $value;
        }
     }
        return $class->sth_to_objects($class->sql_Retrieve($frag), \@newvals);
}



=head2 Sequence_name_from_table

 Title    : Sequence_name_from_table
 Usage    : Used internally
 Function : Given a table name and another argumetn (user specified),
          : create sequence name.  This is based on the Chado conventions
          : Other implementations will have to override.
 Returns  : string (Sequence_name)
 Args     : 

=cut

sub Sequence_name_from_table{
   my($class, $table, $other) = @_;

   # Chado convetions here:
   my $seq_name = uc("SQ_${table}_${other}");
   $seq_name = substr( $seq_name, 0, 30 );

   return $seq_name;
}


END {
   #
   # perform a global commit by default
   #
   $global_dbh->commit()
        if ($global_dbh && $global_dbh->ping());;
   $global_dbh->disconnect()
       if $global_dbh;
}

