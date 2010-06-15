package ModwareX::Types::Publication;

use warnings;
use strict;

use version; our $VERSION = qv('1.0.0');

# Other modules:
use MooseX::Types -declare => [qw/PubAuthor/];
use MooseX::Types::Moose qw/HashRef/;
use ModwareX::Publication::Author;

# Module implementation
#

class_type PubAuthor, { class => 'ModwareX::Publication::Author' };

coerce PubAuthor, from HashRef, via {
    ModwareX::Publication::Author->new(%$_);
};

1;    # Magic true value required at end of module

