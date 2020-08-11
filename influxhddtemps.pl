#!/usr/local/bin/perl -w

use strict;
use warnings;

my $use_influx = 1;
my $influx_fan_speed = 1;
my $influx_fan_duty = 1;
my $influx_disks = 1;
my $influx_sensors = 1;
my $influxdb_db="freenas";
my $influxdb_host="192.168.2.234";
my $influxdb_port="8086";
my $influxdb_protocol="http";
my $influxdb_hostname="medianas";
my $influxdb_url="$influxdb_protocol://$influxdb_host:$influxdb_port/write?db=$influxdb_db";

# smartctl path
my $smartctlCmd = '/usr/local/sbin/smartctl';

my @hd_list;
my @nvme_list;

main();

sub main {

  @hd_list = get_hd_list();
  #print @hd_list;

  foreach my $disk (@hd_list) {
    my $disktemp = get_one_hd_temp($disk);
  }
  @nvme_list = get_nvme_list();
  #print @nvme_list;

  foreach my $disk (@nvme_list) {
    my $disktemp = get_one_nvme_temp($disk);
  }


}


sub run_command {
    my @cmd = @_;
    my ($out, $err);
    #dprint(3, 'run_command: '.join(' ', @cmd));
    my $command = join(' ', @cmd);
    $out = `$command`;
    print $out;
    # if (!run \@cmd, \undef, \$out, \$err) {
    #     chomp($err);
    #     dprint(0, "command [@cmd] failed: $err");
    #     die "command [@cmd] failed: $err";
    # }
    chomp($out);
    #dprint(2, $out);
    return split(/\n/, $out);
}



sub log_to_influx
{
    # $type should be SensorTemp, FanSpeed, FanDuty or DiskTemp, $name should identify the item (da0, Fan 1, Temp...)
    my ( $type, $name, $value) = @_;
        (my $name_nospaces = $name) =~ s/\s//g;
        my $data = "$type,component=$influxdb_hostname$name_nospaces value=$value";
        my @command = ('curl', '-i', "-XPOST $influxdb_url -d \"$data\"");
        #print join (/ /, @command), "\n";
        my @output = run_command(@command);

}
sub get_hd_list {
    my @cmd = ('camcontrol', 'devlist');
    my @vals;
    foreach (run_command(@cmd)) {
        next if (/WDC|Enclosure|Virtual/);
        if (/\((?:pass\d+,(a?da\d+)|(a?da\d+),pass\d+)\)/) {
            #dprint(2, $1);
            push(@vals, $1);
        }
    }
    #print @vals;
    return @vals;
}

sub get_nvme_list {
    my @cmd = ('nvmecontrol', 'devlist');
    my @vals;
    foreach (run_command(@cmd)) {
        next if (/WDC|Enclosure|Virtual/);
        if (/(nvme[\d])\:/) {
            #print $1;
            push(@vals, $1);
        }
    }
    #print @vals;
    return @vals;
}

sub get_one_hd_temp
{
    my $disk_dev = shift;
    my @command = ($smartctlCmd, '-A', "/dev/$disk_dev");
    my $temp;

    foreach (run_command(@command)) {
        chomp;
        #print $_;
        if (/Temperature_Celcius|Airflow_Temperature_Cel/) { $temp = (split)[9]; }
    }
        #print $temp;
        if ($use_influx == 1 && $influx_disks == 1) { log_to_influx("DiskTemp", $disk_dev, $temp);}
    return $temp;
}

sub get_one_nvme_temp
{
    my $disk_dev = shift;
    my @command = ($smartctlCmd, '-A', "/dev/$disk_dev");
    my $temp;
    my @result;
    my $pattern = qr/Temperature\:\s*(\d+)\sCelsius/;
    @result = join("\n", run_command(@command)) =~ m/$pattern/g;
    if (@result) { 
        $temp = $result[0];     
        #print $temp;
	if ($use_influx == 1 && $influx_disks == 1) { log_to_influx("DiskTemp", $disk_dev, $temp);}
    }
    return $temp;
}
