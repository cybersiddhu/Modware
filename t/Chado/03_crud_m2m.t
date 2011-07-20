use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use Test::More qw/no_plan/;
use Digest::MD5 qw/md5/;

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my $expression;
use_ok('TestExpression');
subtest 'Test::Modware::Chado::Expression' => sub {
    lives_ok {
        $expression = Test::Modware::Chado::Expression->create(
            checksum   => md5('exp2'),
            name       => 'exp2',
            uniquename => 'exp2'
        );
    }
    'creates a new instance';

    lives_ok {
        $expression->images(
            Test::Modware::Chado::Expression::Image->new(
                type => 'png',
                uri  => 'http://image.com',
                data => 'image_data'
            )
        );
    }
    'saved one image';

    lives_ok {
        $expression->images(
            Test::Modware::Chado::Expression::Image->new(
                type => 'tiff',
                uri  => 'http://image.com',
                data => 'tiff data'
            )
        );
    }
    'saved another image';


    is( $expression->expression_images->size, 2,
        'has two exp_images through has_many associations' );
    is( $expression->images->size, 2,
        'has two images through many_to_many assoications' );
    isa_ok($_,  'Test::Modware::Chado::ExpressionImage') for $expression->expression_images;
    isa_ok($_,  'Test::Modware::Chado::Expression::Image') for $expression->images;
    is_deeply( [ sort { $a cmp $b } map { $_->type } $expression->images ],
        [qw/png tiff/], 'has images with correct types' );
};

subtest 'Test::Modware::Chado::Expression returns iterator in scalar context' => sub {
    my $itr = $expression->images;
    isa_ok( $itr, 'Modware::Chado::BCS::Relation::Many2Many' );
    while ( my $row = $itr->next ) {
        isa_ok( $row, 'Test::Modware::Chado::Expression::Image' );
        like($row->type,  qr/\w+/,  'matches the type of image');
    }
};

subtest 'Test::Modware::Chado::Expression' => sub {
    my $image;
    lives_ok {
        $image = $expression->images->add_new(
            type => 'gif',
            uri  => 'http://gif.com',
            data => 'gif data'
        );
    }
    'adds a new image';
    isa_ok( $image, 'Test::Modware::Chado::Expression::Image' );
    is( $image->new_record, 1, 'image is not yet saved in the database' );
    lives_ok { $expression->save } 'is saved with the new image';
    is( $expression->images->size, 3, 'image is saved in the database' );
};

subtest 'Test::Modware::Chado::Expression' => sub {
    my $image2;
    lives_ok {
        $image2 = $expression->images->create(
            type => 'gif45',
            uri  => 'http://gif45.com',
            data => 'gif45 data'
        );
    }
    'creates a new image';
    isa_ok( $image2, 'Test::Modware::Chado::Expression::Image' );
    isnt( $image2->new_record, 1, 'image is saved in the database' );
    is( $expression->images->size, 4, 'has 4 images saved in the database' );
};
