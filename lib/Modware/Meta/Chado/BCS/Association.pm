package Modware::Meta::Chado::BCS::Association;

use strict;

# Other modules:
use namespace::autoclean;
use Bio::Chado::Schema;
use Moose::Role;
use Class::MOP::Method;
use List::Util qw/first/;
use Lingua::EN::Inflect::Phrase qw/to_S/;
use Carp;
use Class::MOP;

# Module implementation
#


sub add_has_many {
    my ( $meta, $name, %options ) = @_;
    my $class_name ;
    my $accessor;

	if (defined $options{class_name}) {
		$class_name = $options{class_name};
	}
	else {
		$class_name = $meta->name.'::'.ucfirst (to_S($name));
	}

	if (defined $options{accessor}) {
		$accessor = $options{accessor};
	}
    else {
    	Class::MOP::load_class($class_name);	
        my $assoc_bcs
            = $meta->bcs->source( $class_name->new->meta->resultset )->source_name;
		my $bcs_source = $meta->bcs->source($meta->resultset);
        $accessor = first {
            $assoc_bcs eq
            $bcs_source->related_source($_)->source_name
        }
        $bcs_source->relationships;

        if ( !$accessor ) {
            warn "unable to find Bio::Chado::Schema relationship accessor\n";
            carp
                "please check your resultset name or provide a valid Bio::Chado::Schema accessor name\n";
        }
    }

    my $code = sub {
        my ($self) = @_;
        if ( wantarray() ) {
            my @arr;
            push @arr, $accessor . ' ' . $class_name for 0 .. 10;
            return @arr;
        }
        return $accessor . ' ' . $class_name;
    };
    $meta->add_method(
        $name,
        Class::MOP::Method->wrap(
            $code,
            name         => $name,
            package_name => $meta->name
        )
    );
}

1;    # Magic true value required at end of module

