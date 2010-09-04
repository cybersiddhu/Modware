use strict;
use Test::Most qw/no_plan die/;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

use_ok('Modware::Publication');

my $build = Modware::Build->current;
Chado->connect(
    dsn      => $build->config_data('dsn'),
    user     => $build->config_data('user'),
    password => $build->config_data('password')
);

my $pub = Modware::Publication->new( year => 2004 );
$pub->title('The best title ever');
$pub->abstract('One of the best abstract ever');
$pub->status('unpublished');
$pub->cv('Modware-publication-pub_type');
my $record = $pub->create;

$pub->dbrow($record->dbrow);
$pub->delete;

#another new record
$pub = Modware::Publication->new(
    year     => 2010,
    title    => 'My title',
    abstract => 'My best abstract',
    status   => 'In press',
    cv       => 'Modware-publication-pub_type'
);

$pub->add_author(
    {   first_name => 'James',
        last_name  => 'Brown',
        suffix     => 'Sr.',
        initials    => 'King'

    }
);

$pub->add_author(
    {   first_name => 'Tucker',
        last_name  => 'Jones',
        initials    => 'Mr.'
    }
);

$record = $pub->create;
$pub->dbrow($record->dbrow);
$pub->delete;

