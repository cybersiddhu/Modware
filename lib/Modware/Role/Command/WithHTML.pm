package Modware::Role::Command::WithHTML;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Path::Class::File;
use Modware::Publication::DictyBase;

# Module implementation
#

requires 'execute';
requires 'current_logger';

has 'output_html' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1
);

has '_update_stack' => (
    is      => 'rw',
    isa     => 'ArrayRef[Modware::Publication::DictyBase]',
    traits  => [qw/Array NoGetopt/],
    default => sub {
        return [ Modware::Publication::DictyBase->new ];
    },
    handles => {
        'add_publication'  => 'push',
        'all_publications' => 'elements'
    }, 
    lazy => 1
);

after 'execute' => sub {
    my ($self) = @_;
    my $logger = $self->current_logger;
    my $output = Path::Class::File->new( $self->output_html )->openw;
    $output->print('<br/><h4>This week\'s new papers</h4>');
    foreach my $ref ($self->all_publications) {
        my $link =
            '/publication/'.$ref->pub_id;
        my $citation = $ref->formatted_citation;
        $citation =~ s{<b>}{<a href=$link><b>};
        $citation =~ s{</b>}{</b></a>};
        $output->print( $citation, '<br/><hr/>' );
        $logger->info('pubmed id: ', $ref->pubmed_id,  ' written to html output');
    }
    $output->close;
};

1;    # Magic true value required at end of module

