package MOD::SGD::Book;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("book");
__PACKAGE__->add_columns(
  "book_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "title",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 400,
  },
  "volume_title",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 400,
  },
  "isbn",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 20,
  },
  "total_pages",
  { data_type => "NUMBER", default_value => undef, is_nullable => 1, size => 5 },
  "publisher",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 150,
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
__PACKAGE__->set_primary_key("book_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wQ++k7rEVd20u/YsE+NhTg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
