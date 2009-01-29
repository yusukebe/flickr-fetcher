use inc::Module::Install;
name 'FlickrFetcher';
all_from 'lib/FlickrFetcher.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
