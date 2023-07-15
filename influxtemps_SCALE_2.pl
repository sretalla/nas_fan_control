#!/usr/bin/env -S perl -w

use strict;
use warnings;

my $operating_system = "linux";
my $use_influx = 0;
my $influx_version = 1;
my $influx_disks = 1;
#my $influx_token needed only if you use influx version 2 or later = "some token ... ends with ==";
my $influx_token = "btptrgKkYm9B8Ehxe_J00_4UTkd_xxxxxxxxxxxxxxxxxxxxxxx_yRJ53FqsNZGvaUsm0bpvaChNPlbeMuoifOg==";
my $influx_org = "home"; #not required for version 1
my $influxdb_db="freenas"; # now called bucket in the new API
my $influxdb_host="192.168.1.1";
my $influxdb_port="8086";
my $influxdb_protocol="http";
my $influxdb_hostname="fantest_";
my $influxdb_url;
if ( $influx_version == 1) {
    $influxdb_url="$influxdb_protocol://$influxdb_host:$influxdb_port/write?db=$influxdb_db";
}
else {
    $influxdb_url="$influxdb_protocol://$influxdb_host:$influxdb_port/api/v2/write?org=$influx_org\&bucket=$influxdb_db";
}

# NVME drive filters: Each type of drive to be included needs to be added to this array, drives to specifically avoid can also be added with ! as the first character.
# What you want to see here is a string or a regular expression that matches the text you see in the output of 'sfdisk -l' (Linux) or 'nvmecontrol devlist' (freebsd)
# Example (Linux):
# Disk /dev/nvme0n1: 931.51 GiB, 1000204886016 bytes, 1953525168 sectors
# Disk model: Samsung SSD 970 EVO Plus 1TB
#             ^ Text starting here is what you need to match
#
# Example (freebsd):
#  nvme0: Samsung SSD 970 EVO Plus 1TB
#         ^ Text starting here is what you need to match
#
# Add as many of these as you want/need
my @nvmeFilter  = (
    'INTEL',
    'Samsung',
    'KINGSTON'
);

# HDD/SSD filters: Each type of drive to be included needs to be added to this array, drives to specifically avoid can also be added with ! as the first character.
# What you want to see here is a string or a regular expression that matches the text you see in the output of 'sfdisk -l' (Linux) or 'camcontrol devlist' (freebsd)
# Example (Linux):
# Disk /dev/sda: 931.51 GiB, 1000204886016 bytes, 1953525168 sectors
# Disk model: Samsung SSD 860 
#             ^ Text starting here is what you need to match
#
# Example (freebsd):
# <Samsung SSD 850 EVO 500GB XXXXXXX>  at scbus1 target 0 lun 0 (ada0,pass24)
#  ^ Text starting here is what you need to match
#
# Add as many of these as you want/need
my @diskFilter  = (
    '!PSSD T7',
    'X\d+_TPM',
    'SanDisk',
    'ST\d+',
    'TOSHIBA',
    'HUSM',
    'INTEL',
    'Samsung',
    '.+WDC',
    'WDC',
    'Kingston'
);

my $megadiskPattern;
my $smartctlCmd;
if ( $operating_system eq 'linux' ) {
    $smartctlCmd = '/usr/sbin/smartctl';
    $megadiskPattern = join("", '(?|Disk\s+\/dev\/(s.+):.*\sDisk model: (?|',join("\|", @diskFilter),')|Disk\s+\/dev\/(nvme\d)n\d:.*\sDisk model: (?|',join("\|", @nvmeFilter),'))');
}
elsif ( $operating_system eq 'freebsd' ) {
    $smartctlCmd = '/usr/local/sbin/smartctl';
    #$megadiskPattern = '(?|<(?|.*WDC.*pass\d+,(a?da\d+)\)\s|.*WDC.*\((a?da\d+),.*\)\s|.*(?|Samsung|KINGSTON).*\((a?da\d+),.*\)\s)|.*(nvme\d+):.*(?|Samsung|KINGSTON).*)'; #OLD
    #$megadiskPattern = '(?|<(?|.+WDC|WDC|Kingston|Samsung).+(?|pass\d+,(a?da\d+)|\((a?da\d+),pass\d+.+)|.(nvme\d+):.(?|Samsung|KINGSTON).+)'; #NEW
    $megadiskPattern = join("", '(?|<(?|',join("\|", @diskFilter),').+(?|pass\d+,(a?da\d+)|\((a?da\d+),pass\d+.+)|.(nvme\d+):.(?|',join("\|", @nvmeFilter),').+)');
}

# disk name substitutions: for each serial number add a record here in the format of 'SerialXYZ#FriendlyReplacement' Serial number followed directly by # followed directly by the replacement string... no spaces anywhere please
# Add as many of these as you want/need, changing the name used to log the temp into the influx DB from serial number to whatever friendly name you want 
my @substitutions  = (
    '1234567#disk1',
    '2345678#disk2',
    '3456789#disk3'
);

# (Carefully) Edit things above this line only to match your needs.

my @hd_list;

main();

sub main {
  @hd_list = get_hd_list();
  #print join (" ", @hd_list);
  foreach my $disk (@hd_list) {
    my $disktemp = get_one_drive_temp($disk);
  }
}

sub run_command {
    my @cmd = @_;
    my ($out, $err);
    #dprint(3, 'run_command: '.join(' ', @cmd));
    my $command = join(' ', @cmd);
    $out = `$command`;
    print $out;
    chomp($out);
    #dprint(2, $out);
    return split(/\n/, $out);
}

sub log_to_influx
{
    # $type should be SensorTemp, FanSpeed, FanDuty or DiskTemp, $name should identify the item (da0, Fan 1, Temp...)
    my ( $type, $name, $value) = @_;
        if ($name) {
            (my $name_nospaces = $name) =~ s/\s//g;
            my @substitution = join("\n", @substitutions) =~ m/$name_nospaces\#(.+)/g;
            if (@substitution) { $name_nospaces = $substitution[0]; }
            my $data = "$type,component=$influxdb_hostname$name_nospaces value=$value";
            my $payload;
            my $auth;
            if ( $influx_version == 1) {
                $payload = "-XPOST \"$influxdb_url\" -d \"$data\"";
            }
            else {
                $auth = "Authorization: Token $influx_token";
                $payload = "-XPOST \"$influxdb_url\" -d \"$data\" --header \"$auth\"";
            }
            my @influxcommand = ('curl', '-i', $payload);
            #print join (/ /, @influxcommand), "\n";
            my @output = run_command(@influxcommand);
        }
}

sub get_hd_list {
    my @vals;
    my @drive;
    if ($operating_system eq 'freebsd' ) {
      my @freebsdcmd = ('camcontrol', 'devlist');
      my @NVMEcmd = ('nvmecontrol', 'devlist');
      @drive = join("\n", (run_command(@freebsdcmd), run_command(@NVMEcmd))) =~ m/$megadiskPattern/gm;
    }
    elsif ($operating_system eq 'linux' ) {
      my @linuxcmd = ('sfdisk', '-l', '/dev/sd* /dev/nvm*');
      @drive = join("\n", run_command(@linuxcmd)) =~ m/$megadiskPattern/gm;
    }  
    @vals = @drive;
    #print join (" ", @vals), "\n";
    return @vals;
}

sub get_one_drive_temp
{
    my $disk_dev = shift;
    my @diskcommand = ($smartctlCmd, '-a', "/dev/$disk_dev");
    my $temp;
    my $serial;
    my $megapattern = qr/[Ss]erial [Nn]umber\:\s*(\S*)\s[\s|\S]*(?|Temperature_Celsius[\s|\S]{64}(\d*)\s|Airflow_Temperature_Cel[\s|\S]{60}(\d*)\s|Temperature\:\s*(\d*)\sCelsius|Temperature_Internal[\s|\S]{63}(\d*)\s|Current Drive Temperature\:\s*(\d*)\s)/;
    my @result = join("\n", run_command(@diskcommand)) =~ m/$megapattern/g;
    if ($result[1]) {
        $temp = $result[1];     
        print "Temperature is $temp\n";
    }
    if ($result[0]) {
        $serial = $result[0];     
        print "Serial Number is $serial\n";
    }
    if ($use_influx == 1 && $influx_disks == 1) { 
    log_to_influx("DiskTemp", $serial, $temp);}
    return $temp;
}
