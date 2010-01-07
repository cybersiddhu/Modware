package MOD::SGD::FeatPheno;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("feat_pheno");
__PACKAGE__->add_columns(
  "feature_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "phenotype_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "phenotype_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "sentence",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 720,
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
__PACKAGE__->set_primary_key("feature_no", "phenotype_no", "phenotype_type");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rcnXVNV2rIvZNsVj8ukErA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
