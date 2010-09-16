use strict;
use Test::More qw/no_plan/;
use Test::Moose;
use Test::Exception;
use Moose::Util;

{
	package MyBadPub;
	use Moose;
}

{
	package MyPub;
	use Moose;
	use namespace::autoclean;
	with 'Modware::Role::HasPublication';

	sub _build_abstract {
		'abstract';
	}

	sub _build_title {
	}

	sub _build_year {
		'year';
	}

	sub _build_source {
		'source';
	}

	sub _build_status {
		'status';
	}

	sub _build_keywords_stack {
	   	[qw/hello house hut/];
	}

}

dies_ok { Moose::Util::apply_all_roles(MyBadPub->meta, ('Modware::Role::Publication')) }  'throws without unimplemented methods';

my $pub = MyPub->new;

does_ok($pub, 'Modware::Role::HasPublication', 'it does the Publiction role');
has_attribute_ok($pub, $_,  "it has the attribute $_") for qw/abstract title year source
status keywords_stack/;
is($pub->status,  'status',  'it has the default status value');
is($pub->source,  'source',  'it has the default source value');
is($pub->title,  undef,  'it has undefined title value as default');
is($pub->keywords,  3,  'it has the default keywords');

$pub->add_keyword('test');
is($pub->keywords,  4,  'it has the new keyword');



