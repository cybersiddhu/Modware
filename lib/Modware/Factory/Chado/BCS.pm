package Modware::Factory::Chado::BCS;

use warnings;
use strict;

# Other modules:
use Module::Find;
use Carp;
use Class::MOP;
use Try::Tiny;

# Module implementation
#
sub new {
    my ( $class, %arg ) = @_;
    my $engine = $arg{engine} ? ucfirst lc( $arg{engine} ) : 'Generic';
    my $package = grep {/$engine$/}
        findsubmod('Modware::DataSource::Chado::BCS::Engine');
    croak "cannot find plugins for engine: $engine\n" if !$package;
    try {
        load_class($package);
    }
    catch {
        croak "Issue in loading $package $_\n";
    };
    return $package->new(%arg);
}

1;    # Magic true value required at end of module

__END__

