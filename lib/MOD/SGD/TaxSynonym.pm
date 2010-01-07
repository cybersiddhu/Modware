package MOD::SGD::TaxSynonym;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("tax_synonym");
__PACKAGE__->add_columns(
  "tax_synonym_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "tax_synonym",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 240,
  },
  "taxon_id",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("tax_synonym_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OpH9M9ItY/4ud1QJkEDppw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
