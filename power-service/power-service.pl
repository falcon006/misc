#!/usr/bin/perl

use warnings;

#use strict;
use Getopt::Long;
use POSIX;

my $host = 'http://172.16.1.252/';
my $status;
my $total_cycles = 0;
my $intervals;
my $stop;
my $device;
my $poweroff_delay = 7;

GetOptions(
    "status"           => \$status,
    "total-cycles=i"   => \$total_cycles,
    "intervals=i"      => \$intervals,
    "poweroff-delay=i" => $poweroff_delay,
    "stop"             => \$stop,
    "device=s"         => \$device
) or die("Error in command args");

sub status {
    my $stop = shift;
    open( my $file, "</var/lock/power-service.lock" ) or exit(1);
    my $pid = <$file>;
    close($file);
    chomp($pid);
    if ( -e "/proc/$pid" ) {
        open( my $cmdline, "</proc/$pid/cmdline" );
        my $proccmd = <$cmdline>;
        close($cmdline);
        if ( $proccmd =~ /power-service/ ) {
            system("kill -9 $pid") if $stop;
            print "Enabled power-service\n";
            print "Disabling $pid\n" if $stop;
            exit(0);
        }
    }
    print "Disabled power-service\n";
    exit(1);

}

sub stop {
    status(1);
    exit(0);
}
stop() if ($stop);

if ($status) {
    status(0);
    return 0;
}
daemon();
chomp($device);

sub daemon {
    fork and exit;
    POSIX::setsid();
    fork and exit;
    umask 0;
    open( my $file, ">/var/lock/power-service.lock" );
    print $file $$;
    close($file);
}

sub ibootg2_enable_power {

    system( '/usr/bin/curl', $host . "?s=1&u=admin&p=admin" );

}

sub ibootg2_disable_power {

    system( '/usr/bin/curl', $host . "?s=0&u=admin&p=admin" );

}

sub main {
    print "setting alarm to $intervals\n";
    for ( my $i = 0; $i < $total_cycles; $i++ ) {
        print "executing..\n";
        my $call_function = "$device" . "_disable_power";
        eval { &$call_function(); };
        sleep($poweroff_delay);
        $call_function = "$device" . "_enable_power";
        eval { &$call_function(); };
        sleep($intervals);
    }
    print "Run complete\n";
}

main();

