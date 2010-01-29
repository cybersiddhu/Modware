package MOD::SGD::Abstract;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("abstract");
__PACKAGE__->add_columns(
  "reference_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "abstract",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 4000,
  },
);
__PACKAGE__->set_primary_key("reference_no");
__PACKAGE__->belongs_to(
  "reference_no",
  "MOD::SGD::Reference",
  { reference_no => "reference_no" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-29 16:13:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Zq1nDsCyPw6lc7wObLgmuw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
