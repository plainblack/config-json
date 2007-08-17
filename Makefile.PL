use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Config::JSON',
    AUTHOR              => 'JT Smith <jt@plainblack.com>',
    VERSION_FROM        => 'lib/Config/JSON.pm',
    ABSTRACT_FROM       => 'lib/Config/JSON.pm',
    PL_FILES            => {},
    PREREQ_PM => {
	'List::Util' 		    => 0,
	'JSON'	     		    => 0,
    'Class::InsideOut'      => 0,
    'Test::More' 		    => 0,
    'version'    		    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Config-JSON-*' },
);
