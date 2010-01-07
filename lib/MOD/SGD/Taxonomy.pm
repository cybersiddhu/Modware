package MOD::SGD::Taxonomy;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("taxonomy");
__PACKAGE__->add_columns(
  "taxon_id",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "tax_term",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 240,
  },
  "is_default_display",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 1,
  },
  "common_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 240,
  },
  "rank",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 20,
  },
  "created_by",
  {
    data_type => "VARCHAR2",
    default_value => "SUBSTR(USER,1,12) ",
    is_nullable => 0,
    size => 12,
  },
  "date_created",
  {
    data_type => "DATE",
    default_value => "SYSDATE ",
    is_nullable => 0,
    size => 19,
  },
);
__PACKAGE__->set_primary_key("taxon_id");
__PACKAGE__->add_unique_constraint(
  "tax_term_uk",
  ["tax_term", "tax_term", "tax_term", "tax_term"],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KQXTukri231u/ohdPpYCpw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
