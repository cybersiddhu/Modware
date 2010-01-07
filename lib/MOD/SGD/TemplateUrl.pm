package MOD::SGD::TemplateUrl;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("template_url");
__PACKAGE__->add_columns(
  "template_url_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "template_url",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 480,
  },
  "source",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "description",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 240,
  },
  "date_created",
  {
    data_type => "DATE",
    default_value => "SYSDATE ",
    is_nullable => 0,
    size => 19,
  },
  "created_by",
  {
    data_type => "VARCHAR2",
    default_value => "SUBSTR(USER,1,12) ",
    is_nullable => 0,
    size => 12,
  },
);
__PACKAGE__->set_primary_key("template_url_no");
__PACKAGE__->add_unique_constraint(
  "tu_template_url_uk",
  ["template_url", "template_url", "template_url", "template_url"],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BnVg7ANTwyA2k0SA56ZKmQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
