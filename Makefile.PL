use inc::Module::Install;
name 'ModwareX';
all_from 'lib/ModwareX.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
