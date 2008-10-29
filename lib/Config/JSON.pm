package Config::JSON;

use warnings;
use strict;
use Carp;
use Class::InsideOut qw(readonly id register private);
use File::Copy;
use File::Temp qw/ tempfile /;
use JSON;
use List::Util;
use version; our $VERSION = qv('1.3.0');


use constant FILE_HEADER    => "# config-file-type: JSON 1\n";


readonly    getFilePath     => my %filePath;    # path to config file
readonly    isInclude       => my %isInclude;   # is an include file
private     config          => my %config;      # in memory config file
readonly    getIncludes     => my %includes;    # keeps track of any included config files

#-------------------------------------------------------------------
sub addToArray {
    my ($self, $property, $value) = @_;
    my $array = $self->get($property);
    unless (defined List::Util::first { $value eq $_ } @{$array}) { # check if it already exists
		# add it
      	push(@{$array}, $value);
      	$self->set($property, $array);
	}
}

#-------------------------------------------------------------------
sub addToHash {
    my ($self, $property, $key, $value) = @_;
    $self->set($property."/".$key, $value);
}

#-------------------------------------------------------------------
sub create {
	my ($class, $filename) = @_;
    if (open(my $FILE,">",$filename)) {
        print $FILE FILE_HEADER."\n{ }\n";
        close($FILE);
    } 
    else {
        carp "Can't write to config file ".$filename;
    }
	return $class->new($filename);	
}

#-------------------------------------------------------------------
sub delete {
    my ($self, $param) = @_;
	
	# inform the includes
	foreach my $include (@{$includes{id $self}}) {
		$include->delete($param);
	}
	
	# find the directive
    my $directive   = $config{id $self};
    my @parts       = split "/", $param;
    my $lastPart    = pop @parts;
    foreach my $part (@parts) {
        $directive = $directive->{$part};
    }
	
	# only delete it if it exists
	if (exists $directive->{$lastPart}) {
		delete $directive->{$lastPart};
		$self->write;
	}
}

#-------------------------------------------------------------------
sub deleteFromArray {
    my ($self, $property, $value) = @_;
    my $array	= $self->get($property);
    for (my $i = 0; $i < scalar(@{$array}); $i++) {
        if ($array->[$i] eq $value) {
            splice(@{$array}, $i, 1);
            last;
        }
    }
    $self->set($property, $array);
}

#-------------------------------------------------------------------
sub deleteFromHash {
    my ($self, $property, $key) = @_;
    $self->delete($property."/".$key);
}

#-------------------------------------------------------------------
sub get {
    my ($self, $property) = @_;

	# they want a specific property
	if (defined $property) {

		# look in this config
		my $value = $config{id $self};
		foreach my $part (split "/", $property) {
			$value = $value->{$part};
		}
		return $value if (defined $value);

		# look through includes
		foreach my $include (@{$includes{id $self}}) {
			my $value = $include->get($property);
			return $value if (defined $value);
		}

		# didn't find it
		return undef;
	}
	
	# they want the whole properties list
	my %whole = ();
	foreach my $include (@{$includes{id $self}}) {
		%whole = (%whole, %{$include->get});			
	}
	%whole = (%whole, %{$config{id $self}});
	return \%whole;
}

#-------------------------------------------------------------------
sub getFilename {
    my $self = shift;
    my @path = split "/", $self->getFilePath;
    return pop @path;
}

#-------------------------------------------------------------------
sub new {
    my ($class, $pathToFile, $options) = @_;
    if (open(my $FILE, "<", $pathToFile)) {
        # slurp
        local $/ = undef;
        my $json = <$FILE>;
        close($FILE);
        my $conf;
        eval {
            $conf = JSON->new->relaxed(1)->decode($json);
        };
        croak "Couldn't parse JSON in config file '$pathToFile'\n" unless ref $conf;
        my $self 		= register($class);
		my $id 			= id $self;
        $filePath{$id} 	= $pathToFile;
        $config{$id}   	= $conf;
        $isInclude{$id} = $options->{isInclude};
		
		# process includes
		my @includes = map { glob $_ } @{ $self->get('includes') || [] };
		foreach my $include (@includes) {
			push @{$includes{$id}},  $class->new($include, {isInclude=>1});
		}
		
        return $self;
    } 
    else {
        croak "Cannot read config file: ".$pathToFile;
    }
}

#-------------------------------------------------------------------
sub set {
    my ($self, $property, $value) 	= @_;

	# see if the directive exists in this config
    my $directive	= $config{id $self};
    my @parts 		= split "/", $property;
	my $numParts 	= scalar @parts;
	for (my $i=0; $i < $numParts; $i++) {
		my $part = $parts[$i];
		if (exists $directive->{$part}) { # exists so we continue
			if ($i == $numParts - 1) { # we're on the last part
				$directive->{$part} = $value;
				$self->write;
				return 1;
			}
			else {
				$directive = $directive->{$part};
			}
		}
		else { # doesn't exist so we quit
			last;
		}
	}

	# see if any of the includes have this directive
	foreach my $include (@{$includes{id $self}}) {
		my $found = $include->set($property, $value);
		return 1 if ($found);
	}

	# let's create the directive new in this config if it's not an include
	unless ($self->isInclude) {
		$directive	= $config{id $self};
		my $lastPart = pop @parts;
		foreach my $part (@parts) {
			unless (exists $directive->{$part}) {
				$directive->{$part} = {};
			}
			$directive = $directive->{$part};
		}
	    $directive->{$lastPart} = $value;
		$self->write;
		return 1;
	}

	# didn't find a place to write it	
	return 0;
}

#-------------------------------------------------------------------
sub write {
	my $self = shift;
	my $realfile = $self->getFilePath;

	# convert data to json
    my $json = JSON->new->pretty->encode($config{id $self});

	# create a temporary config file
	my ($fh, $tempfile) = tempfile();
	close($fh);
    if (open(my $FILE,">", $tempfile)) {
        print $FILE FILE_HEADER."\n".$json;
        close($FILE);
    } 
    else {
        croak "Can't write (".$realfile.") to temporary file (".$tempfile.")";
    }
	
	# move the temp file over the top of the existing file
	copy($tempfile, $realfile) or croak "Can't copy temporary file (".$tempfile.") to config file (".$realfile.")";
	unlink $tempfile or carp "Can't delete temporary config file (".$tempfile.")";
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Config::JSON - A JSON based config file system.


=head1 VERSION

This document describes Config::JSON version 1.3.0


=head1 SYNOPSIS

 use Config::JSON;

 my $config = Config::JSON->create($pathToFile);
 my $config = Config::JSON->new($pathToFile);

 my $element = $config->get($directive);

 $config->set($directive,$value);

 $config->delete($directive);
 $config->deleteFromHash($directive, $key);
 $config->deleteFromArray($directive, $value);

 $config->addToHash($directive, $key, $value);
 $config->addToArray($directive, $value);

 my $path = $config->getFilePath;
 my $filename = $config->getFilename;

=head2 Example Config File

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
		
		# including another file
		"includes" : ["macros.conf"]
 } 


=head1 DESCRIPTION

This package parses the config files written in JSON. It also does some non-JSON stuff, like allowing for comments in the files. 

If you want to see it in action, it is used as the config file system in WebGUI L<http://www.webgui.org/>.


=head2 Why?

Why build yet another config file system? Well there are a number of reasons: We used to use other config file parsers, but we kept running into limitations. We already use JSON in our app, so using JSON to store config files means using less memory because we already have the JSON parser in memory. In addition, with JSON we can have any number of hierarchcal data structures represented in the config file, whereas most config files will give you only one level of hierarchy, if any at all. JSON parses faster than XML and YAML. JSON is easier to read and edit than XML. Many other config file systems allow you to read a config file, but they don't provide any mechanism or utilities to write back to it. JSON is taint safe. JSON is easily parsed by languages other than Perl when we need to do that.


=head2 Multi-level Directives

You may of course access a directive called "foo", but since the config is basically a hash you can traverse
multiple elements of the hash when specifying a directive name by simply delimiting each level with a slash, like
"foo/bar". For example you may:

 my $vitality = $config->get("stats/vitality");
 $config->set("stats/vitality", 15);

You may do this wherever you specify a directive name.


=head2 Comments

You can put comments in the config file as long as # is the first non-space character on the line. However, if you use this API to write to the config file, your comments will be eliminated.


=head2 Includes

There is a special directive called "includes", which is an array of include files that may be brought in to
the config. Even the files you include can have an "includes" directive, so you can do hierarchical includes.

Any directive in the main file will take precedence over the directives in the includes. Likewise the files
listed first in the "includes" directive will have precedence over the files that come after it. When writing
to the files, the same precedence is followed.

If you're setting a new directive that doesn't currently exist, it will only be written to the main file.

If a directive is deleted, it will be deleted from all files, including the includes.

=head1 INTERFACE 

=head2 addToArray ( directive, value )

Adds a value to an array directive in the config file.

=head3 directive

The name of the array.

=head3 value

The value to add.


=head2 addToHash ( directive, key, value )

Adds a value to a hash directive in the config file. B<NOTE:> This is really the same as
$config->set("directive/key", $value);

=head3 directive

The name of the hash.

=head3 key

The key to add.

=head3 value

The value to add.


=head2 create ( pathToFile )

Constructor. Creates a new empty config file.

=head3 pathToFile

The path and filename of the file to create.



=head2 delete ( directive ) 

Deletes a key from the config file.

=head3 directive

The name of the directive to delete.


=head2 deleteFromArray ( directive, value )

Deletes a value from an array directive in the config file.

=head3 directive

The name of the array.

=head3 value

The value to delete.



=head2 deleteFromHash ( directive, key )

Delete a key from a hash directive in the config file. B<NOTE:> This is really just the same as doing
$config->delete("directive/key");

=head3 directive

The name of the hash.

=head3 key

The key to delete.



=head2 get ( directive ) 

Returns the value of a particular directive from the config file.

=head3 directive

The name of the directive to return.



=head2 getFilename ( )

Returns the filename for this config.



=head2 getFilePath ( ) 

Returns the filename and path for this config.



=head2 getIncludes ( )

Returns an array reference of Config::JSON objects that are files included by this config.



=head2 new ( pathToFile )

Constructor. Builds an object around a config file.

=head3 pathToFile

A string representing a path such as "/etc/my-cool-config.conf".



=head2 set ( directive, value ) 

Creates a new or updates an existing directive in the config file.

=head3 directive

A directive name.

=head3 value

The value to set the paraemter to. Can be a scalar, hash reference, or array reference.



=head2 write ( )

Writes the file to the filesystem. Normally you'd never need to call this as it's called automatically by the other methods when a change occurs.



=head1 DIAGNOSTICS

=over

=item C<< Couldn't parse JSON in config file >>

This means that the config file does not appear to be formatted properly as a JSON file. Common mistakes are missing commas or trailing commas on the end of a list.

=item C<< Cannot read config file >>

We couldn't read the config file. This usually means that the path specified in the constructor is incorrect.

=item C<< Can't write to config file >>

We couldn't write to the config file. This usually means that the file system is full, or the that the file is write protected.

=back


=head1 CONFIGURATION AND ENVIRONMENT

Config::JSON requires no configuration files or environment variables.


=head1 DEPENDENCIES

=over

=item JSON 2.0 or higher

=item List::Util

=item Class::InsideOut

=item Test::More

=item Test::Deep

=item File::Temp

=item version

=back


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-config-json@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

JT Smith  C<< <jt-at-plainblack-dot-com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008, Plain Black Corporation L<http://www.plainblack.com/>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
