#!/usr/bin/perl -w

use strict;
use Cwd;
use Pod::Usage;
use Getopt::Long;
use SQL::Translator;
use Bio::Chado::Schema;
use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);
use Path::Class;
use List::MoreUtils qw/any/;

use vars qw[ $VERSION $DEBUG $WARN ];

$VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;
$WARN    = 0 unless defined $WARN;

our $max_id_length = 30;
my %global_names;

GetOptions( 'h|help' => sub { pod2usage(1); } );
my $views = do {
    my $names;
    my $view_file
        = Path::Class::Dir->new(getcwd)->parent->parent->subdir('data')
        ->file('chado_views.txt')->openr;
    while ( my $line = $view_file->getline ) {
        chomp $line;
        $line =~ s/\_//g;
        push @$names, $line;
    }
    $view_file->close;
    $names;
};

my $schema = Bio::Chado::Schema->connect;

my $allowed_sources;
for my $name ( $schema->sources ) {
    my $result_source = ( ( split /::/,  lc $name ) )[1];
    if ( any { $_ eq  $result_source } @$views ) {
        warn "skipping $name\n";
        next;
    }
    push @$allowed_sources, $name;
}

my $output = Path::Class::File->new('chado.sqlite')->openw;
my $trans = SQL::Translator->new(
    parser      => 'SQL::Translator::Parser::DBIx::Class',
    parser_args => {
        package      => $schema,
        add_fk_index => 1,
        sources      => $allowed_sources
    },
    producer => \&produce,
) or die SQL::Translator->error;

my $data = $trans->translate or die $trans->error;
$output->print($data);
$output->close;

sub extract_fkeys {
    my $schema = shift;
    for my $t ( $schema->get_tables ) {
        for my $ct ( $t->get_constraints ) {
            if ( $ct->type =~ /foreign/i ) {
                my ($ref_fields) = $ct->reference_fields;
                my ($field_name) = $ct->field_names;
                $t->add_constraint(
                    type            => 'foreign_key',
                    name            => $field_name,
                    fields          => $ref_fields,
                    reference_table => $ct->reference_table,
                );
            }
        }
    }
}

sub produce {
    my $translator = shift;
    local $DEBUG = $translator->debug;
    local $WARN  = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $producer_args  = $translator->producer_args;
    my $sqlite_version = $producer_args->{sqlite_version} || 0;
    my $no_txn         = $producer_args->{no_transaction};

    debug("PKG: Beginning production\n");

    %global_names = ();    #reset

    my @create = ();
    push @create, header_comment unless ($no_comments);
    $create[0] .= "\n\nBEGIN TRANSACTION" unless $no_txn;

    for my $table ( $schema->get_tables ) {
        push @create,
            create_table(
            $table,
            {   no_comments    => $no_comments,
                sqlite_version => $sqlite_version,
                add_drop_table => $add_drop_table,
            }
            );
    }

    for my $view ( $schema->get_views ) {
        push @create,
            create_view(
            $view,
            {   add_drop_view => $add_drop_table,
                no_comments   => $no_comments,
            }
            );
    }

    for my $trigger ( $schema->get_triggers ) {
        push @create,
            create_trigger(
            $trigger,
            {   add_drop_trigger => $add_drop_table,
                no_comments      => $no_comments,
            }
            );
    }

    if (wantarray) {
        push @create, "COMMIT" unless $no_txn;
        return @create;
    }
    else {
        push @create, "COMMIT;\n" unless $no_txn;
        return join( ";\n\n", @create );
    }
}

sub mk_name {
    my ( $name, $scope, $critical ) = @_;

    $scope ||= \%global_names;
    if ( my $prev = $scope->{$name} ) {
        my $name_orig = $name;
        $name .= sprintf( "%02d", ++$prev );
        substr( $name, $max_id_length - 3 ) = "00"
            if length($name) > $max_id_length;

        warn "The name '$name_orig' has been changed to ",
            "'$name' to make it unique.\n"
            if $WARN;

        $scope->{$name_orig}++;
    }

    $scope->{$name}++;
    return $name;
}

sub create_view {
    my ( $view, $options ) = @_;
    my $add_drop_view = $options->{add_drop_view};

    my $view_name = $view->name;
    debug("PKG: Looking at view '${view_name}'\n");

    # Header.  Should this look like what mysqldump produces?
    my $extra  = $view->extra;
    my $create = '';
    $create .= "--\n-- View: ${view_name}\n--\n"
        unless $options->{no_comments};
    $create .= "DROP VIEW IF EXISTS $view_name;\n" if $add_drop_view;
    $create .= 'CREATE';
    $create .= " TEMPORARY"
        if exists( $extra->{temporary} ) && $extra->{temporary};
    $create .= ' VIEW';
    $create .= " IF NOT EXISTS"
        if exists( $extra->{if_not_exists} ) && $extra->{if_not_exists};
    $create .= " ${view_name}";

    if ( my $sql = $view->sql ) {
        $create .= " AS\n    ${sql}";
    }
    return $create;
}

sub create_table {
    my ( $table, $options ) = @_;

    my $table_name     = $table->name;
    my $no_comments    = $options->{no_comments};
    my $add_drop_table = $options->{add_drop_table};
    my $sqlite_version = $options->{sqlite_version} || 0;

    debug("PKG: Looking at table '$table_name'\n");

    my ( @index_defs, @constraint_defs );
    my @fields = $table->get_fields or die "No fields in $table_name";

    my $temp = $options->{temporary_table} ? 'TEMPORARY ' : '';

    #
    # Header.
    #
    my $exists = ( $sqlite_version >= 3.3 ) ? ' IF EXISTS' : '';
    my @create;
    my ( $comment, $create_table ) = "";
    $comment = "--\n-- Table: $table_name\n--\n\n" unless $no_comments;
    if ($add_drop_table) {
        push @create, $comment . qq[DROP TABLE$exists $table_name];
    }
    else {
        $create_table = $comment;
    }

    $create_table .= "CREATE ${temp}TABLE $table_name (\n";

    #
    # Comments
    #
    if ( $table->comments and !$no_comments ) {
        $create_table .= "-- Comments: \n-- ";
        $create_table .= join "\n-- ", $table->comments;
        $create_table .= "\n--\n\n";
    }

    #
    # How many fields in PK?
    #
    my $pk = $table->primary_key;
    my @pk_fields = $pk ? $pk->fields : ();

    #
    # Fields
    #
    my ( @field_defs, $pk_set );
    for my $field (@fields) {
        push @field_defs, create_field($field);
    }

    if ( scalar @pk_fields > 1
        || ( @pk_fields && !grep /INTEGER PRIMARY KEY/, @field_defs ) )
    {
        push @field_defs, 'PRIMARY KEY (' . join( ', ', @pk_fields ) . ')';
    }

    #
    # Indices
    #
    my $idx_name_default = 'A';
    for my $index ( $table->get_indices ) {
        push @index_defs, create_index($index);
    }

    #
    # Foreign key
    #
FKEY:
    for my $ct ( $table->get_constraints ) {
        my $fkey_def = 'FOREIGN KEY(';
        next FKEY if $ct->type !~ /foreign/i;
        my @field_names = $ct->field_names;
        my $names
            = @field_names == 1
            ? $field_names[0]
            : join( ", ", @field_names );
        $fkey_def .= $names . ') REFERENCES ' . $ct->reference_table . '(';

        my @ref_fields = $ct->reference_fields;
        my $ref_names
            = @ref_fields == 1 ? $ref_fields[0] : join( ", ", @ref_fields );
		my $action = $ct->on_delete ? $ct->on_delete : 'CASCADE';
        $fkey_def .= $ref_names . ') ON DELETE '. $action;
        push @field_defs, $fkey_def;
    }

    #
    # Constraints
    #
    my $c_name_default = 'A';
    for my $c ( $table->get_constraints ) {
        next unless $c->type eq UNIQUE;
        push @constraint_defs, create_constraint($c);
    }

    $create_table .= join( ",\n", map {"  $_"} @field_defs ) . "\n)";

    return ( @create, $create_table, @index_defs, @constraint_defs );
}

sub create_field
{
    my ($field, $options) = @_;

    my $field_name = $field->name;
    debug("PKG: Looking at field '$field_name'\n");
    my $field_comments = $field->comments 
        ? "-- " . $field->comments . "\n  " 
        : '';

    my $field_def = $field_comments.$field_name;

    # data type and size
    my $size      = $field->size;
    my $data_type = $field->data_type;
    $data_type    = 'varchar' if lc $data_type eq 'set';
    $data_type  = 'blob' if lc $data_type eq 'bytea';

    if ( lc $data_type =~ /(text|blob)/i ) {
        $size = undef;
    }

#             if ( $data_type =~ /timestamp/i ) {
#                 push @trigger_defs, 
#                     "CREATE TRIGGER ts_${table_name} ".
#                     "after insert on $table_name\n".
#                     "begin\n".
#                     "  update $table_name set $field_name=timestamp() ".
#                        "where id=new.id;\n".
#                     "end;\n"
#                 ;
#
#            }

    #
    # SQLite is generally typeless, but newer versions will
    # make a field autoincrement if it is declared as (and
    # *only* as) INTEGER PRIMARY KEY
    #
    my $pk        = $field->table->primary_key;
    my @pk_fields = $pk ? $pk->fields : ();

    if ( 
         $field->is_primary_key && 
         scalar @pk_fields == 1 &&
         (
          $data_type =~ /int(eger)?$/i
          ||
          ( $data_type =~ /^number?$/i && $size !~ /,/ )
          )
         ) {
        $data_type = 'INTEGER PRIMARY KEY';
        $size      = undef;
#        $pk_set    = 1;
    }

    $field_def .= sprintf " %s%s", $data_type, 
    ( !$field->is_auto_increment && $size ) ? "($size)" : '';

    # Null?
    $field_def .= ' NOT NULL' unless $field->is_nullable;

    # Default?
    SQL::Translator::Producer->_apply_default_value(
        $field,
        \$field_def,
        [
         'NULL'              => \'NULL',
         'now()'             => 'now()',
         'CURRENT_TIMESTAMP' => 'CURRENT_TIMESTAMP',
        ],
    );

    return $field_def;

}

sub create_index {
    my ( $index, $options ) = @_;

    my $name = $index->name;
    $name = mk_name($name);

    my $type = $index->type eq 'UNIQUE' ? "UNIQUE " : '';

    # strip any field size qualifiers as SQLite doesn't like these
    my @fields = map { s/\(\d+\)$//; $_ } $index->fields;
    ( my $index_table_name = $index->table->name )
        =~ s/^.+?\.//;    # table name may not specify schema
    warn "removing schema name from '"
        . $index->table->name
        . "' to make '$index_table_name'\n"
        if $WARN;
    my $index_def
        = "CREATE ${type}INDEX $name ON "
        . $index_table_name . ' ('
        . join( ', ', @fields ) . ')';

    return $index_def;
}

sub create_constraint {
    my ( $c, $options ) = @_;

    my $name = $c->name;
    $name = mk_name($name);
    my @fields = $c->fields;
    ( my $index_table_name = $c->table->name )
        =~ s/^.+?\.//;    # table name may not specify schema
    warn "removing schema name from '"
        . $c->table->name
        . "' to make '$index_table_name'\n"
        if $WARN;

    my $c_def
        = "CREATE UNIQUE INDEX $name ON "
        . $index_table_name . ' ('
        . join( ', ', @fields ) . ')';

    return $c_def;
}

sub create_trigger {
    my ( $trigger, $options ) = @_;
    my $add_drop = $options->{add_drop_trigger};

    my @statements;

    my $trigger_name = $trigger->name;
    my $events       = $trigger->database_events;
    for my $evt (@$events) {

        my $trig_name = $trigger_name;
        if ( @$events > 1 ) {
            $trig_name .= "_$evt";

            warn
                "Multiple database events supplied for trigger '$trigger_name', ",
                "creating trigger '$trig_name' for the '$evt' event.\n"
                if $WARN;
        }

        push @statements, "DROP TRIGGER IF EXISTS $trig_name" if $add_drop;

        #$DB::single = 1;
        my $action = "";
        if ( not ref $trigger->action ) {
            $action .= "BEGIN " . $trigger->action . " END";
        }
        else {
            $action = $trigger->action->{for_each} . " "
                if $trigger->action->{for_each};

            $action = $trigger->action->{when} . " "
                if $trigger->action->{when};

            my $steps = $trigger->action->{steps} || [];

            $action .= "BEGIN ";
            $action .= $_ . "; " for (@$steps);
            $action .= "END";
        }

        push @statements,
            sprintf(
            'CREATE TRIGGER %s %s %s on %s %s',
            $trig_name, $trigger->perform_action_when,
            $evt, $trigger->on_table, $action
            );
    }

    return @statements;
}

sub alter_table { }    # Noop

sub add_field {
    my ($field) = @_;

    return sprintf( "ALTER TABLE %s ADD COLUMN %s",
        $field->table->name, create_field($field) );
}

sub alter_create_index {
    my ($index) = @_;

    # This might cause name collisions
    return create_index($index);
}

sub alter_create_constraint {
    my ($constraint) = @_;

    return create_constraint($constraint) if $constraint->type eq 'UNIQUE';
}

sub alter_drop_constraint { alter_drop_index(@_) }

sub alter_drop_index {
    my ($constraint) = @_;

    return sprintf( "DROP INDEX %s", $constraint->name );
}

sub batch_alter_table {
    my ( $table, $diffs ) = @_;

    # If we have any of the following
    #
    #  rename_field
    #  alter_field
    #  drop_field
    #
    # we need to do the following <http://www.sqlite.org/faq.html#q11>
    #
    # BEGIN TRANSACTION;
    # CREATE TEMPORARY TABLE t1_backup(a,b);
    # INSERT INTO t1_backup SELECT a,b FROM t1;
    # DROP TABLE t1;
    # CREATE TABLE t1(a,b);
    # INSERT INTO t1 SELECT a,b FROM t1_backup;
    # DROP TABLE t1_backup;
    # COMMIT;
    #
    # Fun, eh?
    #
    # If we have rename_field we do similarly.

    my $table_name = $table->name;
    my $renaming = $diffs->{rename_table} && @{ $diffs->{rename_table} };

    if (   @{ $diffs->{rename_field} } == 0
        && @{ $diffs->{alter_field} } == 0
        && @{ $diffs->{drop_field} } == 0 )
    {

        #    return join("\n", map {
        return map {
            my $meth = __PACKAGE__->can($_)
                or die __PACKAGE__ . " cant $_";
            map {
                my $sql = $meth->( ref $_ eq 'ARRAY' ? @$_ : $_ );
                $sql ? ("$sql") : ()
                } @{ $diffs->{$_} }

            } grep { @{ $diffs->{$_} } } qw/rename_table
            alter_drop_constraint
            alter_drop_index
            drop_field
            add_field
            alter_field
            rename_field
            alter_create_index
            alter_create_constraint
            alter_table/;
    }

    my @sql;
    my $old_table = $renaming ? $diffs->{rename_table}[0][0] : $table;

    do {
        local $table->{name} = $table_name . '_temp_alter';

        # We only want the table - dont care about indexes on tmp table
        my ($table_sql)
            = create_table( $table,
            { no_comments => 1, temporary_table => 1 } );
        push @sql, $table_sql;
    };

    push @sql,
        "INSERT INTO @{[$table_name]}_temp_alter SELECT @{[ join(', ', $old_table->get_fields)]} FROM @{[$old_table]}",
        "DROP TABLE @{[$old_table]}",
        create_table( $table, { no_comments => 1 } ),
        "INSERT INTO @{[$table_name]} SELECT @{[ join(', ', $old_table->get_fields)]} FROM @{[$table_name]}_temp_alter",
        "DROP TABLE @{[$table_name]}_temp_alter";

    return @sql;

    #  return join("", @sql, "");
}

sub drop_table {
    my ($table) = @_;
    return "DROP TABLE $table";
}

sub rename_table {
    my ( $old_table, $new_table, $options ) = @_;

    my $qt = $options->{quote_table_names} || '';

    return "ALTER TABLE $qt$old_table$qt RENAME TO $qt$new_table$qt";

}

=head1 NAME

B<Application name> - [One line description of application purpose]


=head1 SYNOPSIS

=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


=head1 REQUIRED ARGUMENTS

=for author to fill in:
A complete list of every argument that must appear on the command line.
when the application  is invoked, explaining what each of them does, any
restrictions on where each one may appear (i.e., flags that must appear
		before or after filenames), and how the various arguments and options
may interact (e.g., mutual exclusions, required combinations, etc.)
	If all of the application's arguments are optional, this section
	may be omitted entirely.


	=head1 OPTIONS

	B<[-h|-help]> - display this documentation.

	=for author to fill in:
	A complete list of every available option with which the application
	can be invoked, explaining what each does, and listing any restrictions,
	or interactions.
	If the application has no options, this section may be omitted entirely.


	=head1 DESCRIPTION

	=for author to fill in:
	Write a full description of the module and its features here.
	Use subsections (=head2, =head3) as appropriate.


	=head1 DIAGNOSTICS

	=head1 CONFIGURATION AND ENVIRONMENT

	=head1 DEPENDENCIES

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

	B<Siddhartha Basu>


	=head1 AUTHOR

	I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>

	=head1 LICENCE AND COPYRIGHT

	Copyright (c) B<2010>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

	This module is free software; you can redistribute it and/or
	modify it under the same terms as Perl itself. See L<perlartistic>.



