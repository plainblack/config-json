use Test::More tests => 12;

use lib '../lib';
use Test::Deep;
use Config::JSON;

my $config = Config::JSON->create("/tmp/test.conf");
ok (defined $config, "create new config");

# set up test data
if (open(my $file, ">", "/tmp/test.conf")) {
my $testData = <<END;
# config-file-type: JSON 1

 {
        "dsn" : "DBI:mysql:test",
        "user" : "tester",
        "password" : "xxxxxx", 

        # some colors to choose from
        "colors" : [ "red", "green", "blue" ],

        # some statistics
        "stats" : {
                "health" : 32,
                "vitality" : 11
        }
 } 

END
	print {$file} $testData;
	close($file);
	ok(1, "set up test data");
} else {
	ok(0, "set up test data");
}
$config = Config::JSON->new("/tmp/test.conf");
ok( defined $config, "load config" );

ok( $config->get("dsn") ne "", "get()" );
is( ref $config->get("stats"), "HASH", "get() hash" );
is( ref $config->get("colors"), "ARRAY", "get() array" );

is( $config->getFilename,"/tmp/test.conf","getFilename()" );

$config->addToArray("colors","TEST");
my $found = 0;
foreach my $color ( @{$config->get("colors")}) {
	$found = 1 if ($color eq "TEST");
}
ok($found, "addToArray()");


$config->deleteFromArray("colors","TEST");
$found = 0;
foreach my $color ( @{$config->get("colors")}) {
	$found = 1 if ($color eq "TEST");
}
ok(!$found, "deleteFromArray()");


$config->addToHash("stats","TEST","VALUE");
$found = 0;
foreach my $stat (keys %{$config->get("stats")}) {
	$found = 1 if ($stat eq "TEST" && $config->get("stats")->{$stat} eq "VALUE");
}
ok($found, "addToHash()");


$config->deleteFromHash("stats","TEST");
$found = 0;
foreach my $stat (keys %{$config->get("stats")}) {
	$found = 1 if ($stat eq "TEST");
}
ok(!$found, "deleteFromHash()");


$config->set('privateArray', ['a', 'b', 'c']);
cmp_bag($config->get('privateArray'), ['a', 'b', 'c'], 'set: array, not scalar');

END: {
    $config->delete('privateArray');
}
