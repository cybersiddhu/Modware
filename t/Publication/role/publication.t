use strict;
use Test::More qw/no_plan/;
use List::MoreUtils qw/any/;

{

    package MyArticle;
    use namespace::autoclean;
    use Moose;

## -- Roles for data persistence
    with 'Modware::Role::Adapter::BCS::Chado::Publication';

## -- Data Role
    with 'Modware::Role::Publication::HasAuthors';
    with 'Modware::Role::Publication::HasGeneric';
    with 'Modware::Role::Publication::HasArticle';

}

my @traits = (
    'Modware::Meta::Attribute::Trait::Persistent::Pubprop',
    'Modware::Meta::Attribute::Trait::Persistent::Cvterm'
);

my $article = MyArticle->new;

is( $article->cv, 'pub_type',    'It has default cv value' );
is( $article->db, 'Publication', 'It has default db value' );

for my $attr ( $article->meta->get_all_attributes ) {
    if ( any { $attr->does($_) } @traits ) {
        is( $attr->cv, 'pub_type',
            'It has default value for cv attribute in the trait' );
        is( $attr->db, 'Publication',
            'It has default value for db attribute in the trait' );
    }
}

$article->cv('mycv');
$article->db('mydb');

for my $attr ( $article->meta->get_all_attributes ) {
    if ( any { $attr->does($_) } @traits ) {
        is( $attr->cv, 'mycv',
            'It has new value for cv attribute in the trait' );
        is( $attr->db, 'mydb',
            'It has new value for db attribute in the trait' );
    }
}

$article->add_author( { first_name => 'Sammy', last_name => 'Hammy' } );
$article->add_author( { first_name => 'Polka', last_name => 'Dot' } );

my $collection_attr = $article->meta->get_attribute('collection');
my $authors         = $collection_attr->get_value($article);
is( scalar @$authors, 2, 'It has two authors' );
isa_ok( $_, 'Modware::Publication::Author' ) for @$authors;
for my $author_obj (@$authors) {
    my $attr = $author_obj->meta->get_attribute('given_name');
    isnt( $attr->has_value($author_obj),
        1, 'It does not yet have a defined value' );
    like( $attr->get_value($author_obj),
        qr/^\S+$/, 'It matches a defined value after calling the accessor' );
}
