use Test::Most qw/no_plan die/;
use aliased 'Modware::DataSource::Chado';
use aliased 'Modware::ConfigData';

BEGIN {
    use_ok('Modware::Chado::Query::BCS::Publication::JournalArticle');
}

Chado->connect(
    dsn      => ConfigData->config('dsn'),
    user     => ConfigData->config('user'),
    password => ConfigData->config('password')
);

#Chado->handler->storage->debug(1);

my $Pub = 'Modware::Chado::Query::BCS::Publication::JournalArticle';
my $pub_itr = $Pub->search(
    journal => 'Text' );
isa_ok( $pub_itr, 'Modware::Collection::Iterator::BCS::ResultSet' );
is( $pub_itr->count, 3, 'has three journal article' );

$pub_itr = $Pub->search(
    journal => 'Text7',
    cond    => { match => 'exact' }
);
is( $pub_itr->count, 1, 'has one journal article' );

$pub_itr = $Pub->search(
    title => 'Text503',
    cond    => { match => 'exact' }
);

is( $pub_itr->count, 1, 'has one journal article' );
