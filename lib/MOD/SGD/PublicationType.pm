package MOD::SGD::PublicationType;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("publication_type");
__PACKAGE__->add_columns(
  "reference_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "pub_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
);
__PACKAGE__->set_primary_key("reference_no", "pub_type");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:U7fFH6lQHaOz2dptVdDvsQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
