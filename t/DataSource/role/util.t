use strict;
use Test::More qw/no_plan/;
use Test::Moose;

{
	package MyUtil;
	use Moose;

	with 'Modware::Role::DataSource::Util';

	no Moose;
}


my $util = MyUtil->new;
does_ok($util,  'Modware::Role::DataSource::Util');
has_attribute_ok($util, 'source',  'it has source attribute');
