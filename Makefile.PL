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
	'List::Util' 		    => 1.19,
	'JSON'	     		    => 2.12,
    'Class::InsideOut'      => 1.06,
    'Test::More' 		    => 0.7,
    'Test::Deep'            => 0.095,
    'File::Temp'            => 0.18,
    'version'    		    => 0.7203,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Config-JSON-*' },
);
