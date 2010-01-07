package MOD::SGD::InSituExpressionPattern;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("in_situ_expression_pattern");
__PACKAGE__->add_columns(
  "dictybaseid",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  "type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 20,
  },
  "cdna_id",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
);
__PACKAGE__->set_primary_key("dictybaseid", "cdna_id");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:s7J7ijNGsqX2W6OM2Fpbbg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
