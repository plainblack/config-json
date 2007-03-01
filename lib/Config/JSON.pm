package Config::JSON;

use warnings;
use strict;
use Carp;
use JSON;
use List::Util;

use version; our $VERSION = qv('1.0.2');

#-------------------------------------------------------------------
sub addToArray {
        my $self = shift;
        my $property = shift;
        my $value = shift;
        my $array = $self->get($property);
        unless (defined List::Util::first { $value eq $_ } @{$array}) { # check if it already exists
		# add it
        	push(@{$array}, $value);
        	$self->set($property, $array);
	}
}


#-------------------------------------------------------------------
sub addToHash {
        my $self = shift;
        my $property = shift;
        my $key = shift;
        my $value = shift;
        my $hash = $self->get($property);
        $hash->{$key} = $value;
        $self->set($property, $hash);
}


#-------------------------------------------------------------------
sub create {
	my $class = shift;
	my $filename = shift;
        if (open(my $FILE,">",$filename)) {
                print $FILE "# config-file-type: JSON 1\n{ }\n";
                close($FILE);
        } else {
                carp "Can't write to config file ".$filename;
        }
	return $class->new($filename);	
}



#-------------------------------------------------------------------
sub delete {
        my $self = shift;
        my $param = shift;
        delete $self->{_config}{$param};
        if (open(my $FILE,">",$self->getFilename)) {
                print $FILE "# config-file-type: JSON 1\n".objToJson($self->{_config}, {pretty => 1, indent => 4, autoconv=>0, skipinvalid=>1});
                close($FILE);
        } else {
                carp "Can't write to config file ".$self->getFilename;
        }
}

#-------------------------------------------------------------------
sub deleteFromArray {
        my $self = shift;
        my $property = shift;
        my $value = shift;
        my $array = $self->get($property);
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
        my $self = shift;
        my $property = shift;
        my $key = shift;
        my $hash = $self->get($property);
        delete $hash->{$key};
        $self->set($property, $hash);
}


#-------------------------------------------------------------------
sub DESTROY {
        my $self = shift;
        undef $self;
}


#-------------------------------------------------------------------
sub get {
        my $self = shift;
        my $param = shift;
        return $self->{_config}{$param};
}


#-------------------------------------------------------------------
sub getFilename {
        my $self = shift;
        return $self->{_pathToFile};
}


#-------------------------------------------------------------------
sub new {
        my $class = shift;
        my $pathToFile = shift;
        my $json = "";
        if (open(my $FILE, "<", $pathToFile)) {
                while (my $line = <$FILE>) {
                        $json .= $line unless ($line =~ /^\s*#/);
                }
                close($FILE);
                my $conf = jsonToObj($json);
                croak "Couldn't parse JSON in config file '$pathToFile'\n" unless ref $conf;
                my $self = {_pathToFile=>$pathToFile, _config=>$conf};
                bless $self, $class;
                return $self;
        } else {
                croak "Cannot read config file: ".$pathToFile;
        }
}


#-------------------------------------------------------------------
sub set {
        my $self = shift;
        my $param = shift;
        my $value = shift;
        $self->{_config}{$param} = $value;
        if (open(my $FILE, ">" ,$self->getFilename)) {
                print $FILE "# config-file-type: JSON 1\n".objToJson($self->{_config}, {pretty => 1, indent => 4, autoconv=>0, skipinvalid=>1});
                close($FILE);
        } else {
                carp "Can't write to config file ".$self->getFilename;
        }
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Config::JSON - A JSON based config file system.


=head1 VERSION

This document describes Config::JSON version 1.0.0


=head1 SYNOPSIS

 use Config::JSON;

 my $config = Config::JSON->create($pathToFile);
 my $config = Config::JSON->new($pathToFile);

 my $element = $config->get($param);

 $config->set($param,$value);

 $config->delete($param);
 $config->deleteFromHash($name, $key);
 $config->deleteFromArray($name, $value);

 $config->addToHash($name, $key, $value);
 $config->addToArray($name, $value);

 my $path = $config->getFilename;

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
        }
 } 

Note that you can put comments in the config file as long as # is the first non-space character on the line. However, if you use this API to write to the config file, your comments will be eliminated.


=head1 DESCRIPTION

This package parses the config files written in JSON. It also does some non-JSON stuff, like allowing for comments in the files. 

If you want to see it in action, it is used as the config file system in WebGUI L<http://www.webgui.org/>.

=head2 Why?

Why build yet another config file system? Well there are a number of reasons: We used to use other config file parsers, but we kept running into limitations. We already use JSON in our app, so using JSON to store config files means using less memory because we already have the JSON parser in memory. In addition, with JSON we can have any number of hierarchcal data structures represented in the config file, whereas most config files will give you only one level of hierarchy, if any at all. JSON parses faster than XML and YAML. JSON is easier to read and edit than XML. Many other config file systems allow you to read a config file, but they don't provide any mechanism or utilities to write back to it. JSON is taint safe. JSON is easily parsed by languages other than Perl when we need to do that.


=head1 INTERFACE 

=head2 addToArray ( property, value )

Adds a value to an array property in the config file.

=head3 property

The name of the array.

=head3 value

The value to add.


=head2 addToHash ( property, key, value )

Adds a value to a hash property in the config file.

=head3 property

The name of the hash.

=head3 key

The key to add.

=head3 value

The value to add.


=head2 create ( pathToFile )

Constructor. Creates a new empty config file.

=head3 pathToFile

The path and filename of the file to create.



=head2 delete ( param ) 

Deletes a key from the config file.

=head3 param

The name of the parameter to delete.


=head2 deleteFromArray ( property, value )

Deletes a value from an array property in the config file.

=head3 property

The name of the array.

=head3 value

The value to delete.



=head2 deleteFromHash ( property, key )

Delete a key from a hash property in the config file.

=head3 property

The name of the hash.

=head3 key

The key to delete.

=cut




=head2 DESTROY ( )

Deconstructor.



=head2 get ( param ) 

Returns the value of a particular parameter from the config file.

=head3 param

The name of the parameter to return.



=head2 getFilename ( )

Returns the filename and path for this config.



=head2 new ( pathToFile )

Constructor. Builds an object around a config file.

=head3 pathToFile

A string representing a path such as "/etc/my-cool-config.conf".



=head2 set ( param, value ) 

Creates a new or updates an existing parameter in the config file.

=head3 param

A parameter name.

=head3 value

The value to set the paraemter to. Can be a scalar, hash reference, or array reference.





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

=item JSON

=item List::Util

=item Test::More

=item version

=item Test::Deep

=item Test::Perl::Critic

=item Test::Pod::Coverage

=item Test::Pod

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

Copyright (c) 2006-2007, Plain Black Corporation L<http://www.plainblack.com/>. All rights reserved.

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
