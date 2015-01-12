use Test::More tests => 7;

use lib '../lib';
use Test::Deep;
use Config::JSON;
use File::Temp qw/ tempfile /;

my ($fh, $filename) = tempfile();
close($fh);
my $config = Config::JSON->create($filename);
ok (defined $config, "create new config");

# set up test data
if (open(my $file, ">", $filename)) {
my $testData = <<END;
# config-file-type: JSON 1

 {
        "dsn" : "DBI:mysql:test",
        "user" : "tester",
        "password" : "xxxxxx", 

        # some colors to choose from
        "colors" : [ "red", "green", "blue" ]

 } 

END
	print {$file} $testData;
	close($file);
	ok(1, "set up test data");
} 
else {
	ok(0, "set up test data");
}

$config = Config::JSON->new($filename);
isa_ok($config, "Config::JSON" );

is( $config->getFilePath, $filename, "getFilePath()" );
ok( -e $filename, "file exists" );
my $size_snapshot = -s $filename;

chmod 0675, $filename;  # unlikely permissions
$config->set('privateArray', ['a', 'b', 'c']);

my $perm = (stat $filename)[2] & 07777;
is( $perm, 0675, "unlikely permissions preserved" );
isnt( $size_snapshot, -s $filename, "size changed suggesting the file was written" );

