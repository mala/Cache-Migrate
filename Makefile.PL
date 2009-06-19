use inc::Module::Install;
name 'Cache-Migrate';
all_from 'lib/Cache/Migrate.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
