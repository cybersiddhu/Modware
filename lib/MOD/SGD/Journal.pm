package MOD::SGD::Journal;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("journal");
__PACKAGE__->add_columns(
  "journal_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "full_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 200,
  },
  "abbreviation",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 140,
  },
  "issn",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 20,
  },
  "publisher",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 100,
  },
  "url_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 1, size => 10 },
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
__PACKAGE__->set_primary_key("journal_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IN0cgHSdI+/uGPoMx1DLog


# You can replace this text with custom content, and it will be preserved on regeneration
1;
