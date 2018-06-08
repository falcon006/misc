#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;
use File::Glob ':globally';
use File::Basename;
use LWP;
use JSON;
use Data::Dumper;

my $browser = LWP::UserAgent->new;
$browser->agent("PlatformTeamSync/1.0 ");
my $apikey;
my $server;
my $repo;
my $location="";


GetOptions( "apikey=s" => \$apikey,
            "server=s" => \$server,
            "repo=s"  => \$repo,
            "location=s" => \$location) or usage();

sub usage {
    print "Usage for sync-files.pl\n";
    print "--apikey \t\t access key\n";
    print "--server \t\t server ip address\n";
    print "--repo   \t\t artifactory repo name\n";
    print "--location \t\t location of rpms you wnat to push\n\n";
    print "Example: sync-files.pl --apikey=asdf123 --server=https://packages.aws.com --repo=myRPMrepo --location=/my/fold/of/rpms\n\n";
    exit 1;
}

sub get_file_sha1 {
    my $file = shift;
    my ( $sha1, $filename ) = split( " ", `/usr/bin/sha1sum $file` );
    die("sha1sum failed") if ($? != 0);
    chomp($sha1);
    return $sha1;
}

sub push_file {
    my $ua    = shift;
    my $file  = shift;
    my $bfile = basename($file);

# Not liking lwp PUT method :(
#    my $req = $ua->put("https://packages.us-west-2.bco.aws.cudaops.com/platform5/",
#        'X-JFrog-Art-Api' => $apikey,
#        'Content_Type' => 'multipart/form-data',
#        'Content' => [
#        $bfile => [ $file ],
#     ],
#    );
    system("curl -s -H 'X-JFrog-Art-Api:$apikey' -XPUT https://$server/$repo/ -T $file");
    if ( $? != 0 ) {
        print "Push file $file failed\n";
    }
    return 0;
}

if( !defined($apikey) || !defined($server) || !defined($repo) ) {
    usage();
}

my $jdecode;
my @rpms = <$location/*.{rpm}>;
foreach (@rpms) {
    my $rpmname  = basename($_);
    my $response = $browser->get(
        "https://$server/api/storage/$repo/$rpmname",
        'X-JFrog-Art-Api' => "$apikey",
    );
    if ( $response->content ) {
        $jdecode = decode_json( $response->content );
    }

    if( $response->status_line =~ /^403/ ) {
       die("403 error with $server");
    }
    if ( defined $jdecode->{errors} ) {
        print "Could not find rpm details\n";
        push_file( $browser, $_ );
        next;
    }
    my $filesha1 = get_file_sha1($_);
    if ( $filesha1 ne $jdecode->{checksums}->{sha1} ) {
        print "$filesha1 and " . $jdecode->{checksums}->{sha1} . "\n";
        print "checksum not the same. Uploading \n";
        push_file( $browser, $_ );
    }
    else {
        print "checksum okay for $_\n";
    }
}

