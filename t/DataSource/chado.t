use strict;
use Test::More qw/no_plan/;
use Test::Exception;
use File::Path;
use Path::Class::Dir;
use FindBin qw/$Bin/;
use DBI;
use Try::Tiny;
use lib '../lib';

BEGIN {
    use_ok('Modware::DataSource::Chado');
}

#make the tmp folder if not there
my $folder = Path::Class::Dir->new($Bin)->parent->subdir('tmp');
mkdir $folder->stringify
    or die "cannot create folder $!"
    if !-e $folder->stringify;

#now get some temporary sqlite database being setup
my $tmp1 = $folder->file('test1.sqlite')->stringify;
my $tmp2 = $folder->file('test2.sqlite')->stringify;
my $tmp3 = $folder->file('test3.sqlite')->stringify;
my $ddl  = Path::Class::Dir->new($Bin)->parent->subdir('data')->subdir('ddl')
    ->file('chado.sqlite')->stringify;

#set sqlite3 chado instance
set_chado(
    dbname => $tmp1,
    ddl    => $ddl,
    data   => {
        name        => 'tucker',
        description => 'tucker dies'
    }
);

#set sqlite3 chado instance
set_chado(
    dbname => $tmp2,
    ddl    => $ddl,
    data   => {
        name        => 'caboose',
        description => 'caboose dies'
    }
);

set_chado(
    dbname => $tmp3,
    ddl    => $ddl,
    data   => {
        name        => 'drago',
        description => 'drago dies'
    }
);

my $datasource = 'Modware::DataSource::Chado';

#1
$datasource->connect( dsn => "dbi:SQLite:dbname=$tmp1" );

#2
$datasource->connect(
    dsn         => "dbi:SQLite:dbname=$tmp2",
    source_name => 'beermod'
);

my $handler  = $datasource->handler;
my $handler2 = $datasource->handler('beermod');

isa_ok( $handler,  'Bio::Chado::Schema' );
isa_ok( $handler2, 'Bio::Chado::Schema' );

my $row  = $handler->resultset('General::Db')->find( { name => 'tucker' } );
my $row2 = $handler->resultset('General::Db')->find( { name => 'caboose' } );

my $row3 = $handler2->resultset('General::Db')->find( { name => 'caboose' } );
my $row4 = $handler2->resultset('General::Db')->find( { name => 'drago' } );

like( $row->description, qr/tucker/, 'tucker is in default handler' );
isnt( $row2, 1, 'caboose is not in default handler' );

like( $row3->description, qr/caboose/, 'caboose is in beermod' );
isnt( $row4, 1, 'drago is not in beermod' );

$datasource->connect(
    dsn         => "dbi:SQLite:dbname=$tmp3",
    source_name => 'modless',
    default     => 1
);

my $handler3 = $datasource->handler;
my $row5 = $handler3->resultset('General::Db')->find( { name => 'drago' } );
like( $row5->description, qr/drago/, 'drago is in default handler now' );

unlink grep {/sqlite$/} map { $_->stringify } $folder->children;

sub set_chado {
    my %arg = @_;

    #my $handler = Test::Chado::Handler->new(
    #    dsn => "dbi:SQLite:dbname=$arg{dbname}",
    #    ddl => $arg{ddl}
    #);
    #$handler->loader('bcs');
    #$handler->deploy_schema;
    #my $loader = $handler->loader_instance;
    #$loader->txn_do(
    #    sub {
    #        $loader->resultset('General::Db')->create(
    #            {   name        => $arg{data}{name},
    #                description => $arg{data}{description}
    #            }
    #        );
    #    }
    #);
    #$loader->txn_commit;
    my $dbh = DBI->connect( "dbi:SQLite:dbname=$arg{dbname}",
        '', '', { AutoCommit => 0, RaiseError => 1 } );
    try {
        $dbh->do(<<SQL);
        CREATE TABLE db (
            db_id INTEGER PRIMARY KEY,
            name character varying(255) NOT NULL,
            description character varying(255),
  			urlprefix character varying(255),
  			url character varying(255)
		)
SQL

        $dbh->do("CREATE UNIQUE INDEX db_c1 ON db (name)");
        $dbh->commit;
    }
    catch {
        $dbh->rollback;
        die "issue in creating table:$_";
    };

    my $sth = $dbh->prepare("INSERT into db(name, description) VALUES(?, ?)");
    try {
        $sth->execute( $arg{data}{name}, $arg{data}{description} );
        $dbh->commit;
    }
    catch {
        $dbh->rollback;
        die "unable to insert data:$_";
    };
    $dbh->disconnect;

}
