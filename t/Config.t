use Test::More tests => 25;

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
        },

        # multilevel
        "this" : {
            "that" : {
                "scalar" : "foo",
                "array" : ["foo", "bar"],
                "hash" : { 
                    "foo" : 1,
                    "bar" : 2
                }
            }
        }
 } 

END
	print {$file} $testData;
	close($file);
	ok(1, "set up test data");
} 
else {
	ok(0, "set up test data");
}
$config = Config::JSON->new("/tmp/test.conf");
isa_ok($config, "Config::JSON" );

# getFilePath and getFilename
is( $config->getFilePath,"/tmp/test.conf","getFilePath()" );
is( $config->getFilename,"test.conf","getFilename()" );

# get
ok( $config->get("dsn") ne "", "get()" );
is( ref $config->get("stats"), "HASH", "get() hash" );
is( ref $config->get("colors"), "ARRAY", "get() array" );
is( $config->get("this/that/scalar"), "foo", "get() multilevel");
is( ref $config->get("this/that/hash"), "HASH", "get() hash multilevel" );
is( ref $config->get("this/that/array"), "ARRAY", "get() array multilevel" );

# set
$config->set('privateArray', ['a', 'b', 'c']);
cmp_bag($config->get('privateArray'), ['a', 'b', 'c'], 'set()');
$config->set('cars/ford', "mustang");
is($config->get('cars/ford'), "mustang", 'set() multilevel non-exisistant');
$config->set('cars/ford', [qw( mustang pinto maverick )]);
cmp_bag($config->get('cars/ford'),[qw( mustang pinto maverick )], 'set() multilevel');

# delete 
$config->delete("dsn");
ok(!(defined $config->get("dsn")), "delete()");
$config->delete("stats/vitality");
ok(!(defined $config->get("stats/vitality")), "delete() multilevel");
ok(defined $config->get("stats"), "delete() multilevel - doesn't delete parent");

# addToArray
$config->addToArray("colors","TEST");
ok((grep /TEST/, @{$config->get("colors")}), "addToArray()");
$config->addToArray("cars/ford", "fairlane");
ok((grep /fairlane/, @{$config->get("cars/ford")}), "addToArray() multilevel");

# deleteFromArray
$config->deleteFromArray("colors","TEST");
ok(!(grep /TEST/, @{$config->get("colors")}), "deleteFromArray()");
$config->deleteFromArray("cars/ford", "fairlane");
ok(!(grep /fairlane/, @{$config->get("cars/ford")}), "deleteFromArray() multilevel");

# addToHash
$config->addToHash("stats","TEST","VALUE");
is($config->get("stats/TEST"), "VALUE", "addToHash()");
$config->addToHash("this/that/hash", "three", 3);
is($config->get("this/that/hash/three"), 3, "addToHash() multilevel");

# deleteFromHash
$config->deleteFromHash("stats","TEST");
my $hash = $config->get("stats");
ok(!(exists $hash->{TEST}), "deleteFromHash()");
$config->deleteFromHash("this/that/hash", "three");
$hash = $config->get("this/that/hash");
ok(!(exists $hash->{three}), "deleteFromHash() multilevel");


END: {
    unlink "/tmp/test.conf";
}
