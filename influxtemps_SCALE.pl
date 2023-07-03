#!/usr/bin/env -S perl -w

use strict;
use warnings;

my $operating_system = "linux";

my $use_influx = 1;
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
    my $influxdb_url="$influxdb_protocol://$influxdb_host:$influxdb_port/api/v2/write?org=$influx_org\&bucket=$influxdb_db";
    }

# smartctl path
my $smartctlCmd;
if ( $operating_system eq 'linux' ) {
    $smartctlCmd = '/usr/sbin/smartctl';
}
else {
    $smartctlCmd = '/usr/local/sbin/smartctl';
}


my @hd_list;
my @nvme_list;

main();

sub main {

  @hd_list = get_hd_list();
  #print @hd_list;

  foreach my $disk (@hd_list) {
    my $disktemp = get_one_drive_temp($disk);
  }
  @nvme_list = get_nvme_list();
  #print @nvme_list;

  foreach my $disk (@nvme_list) {
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
        if ($name) {
            (my $name_nospaces = $name) =~ s/\s//g;
        
            #Add as many of these as you want/need, changing the name used to log the temp into the influx DB from serial number to whatever friendly name you want 
            if ($name_nospaces eq "12345678") { $name_nospaces = "BootPoolSSD1"; }

            my $data = "$type,component=$influxdb_hostname$name_nospaces value=$value";
            my $payload;
            my $auth;
            if ( $influx_version == 1) {
                my $payload = "-XPOST \"$influxdb_url\" -d \"$data\"";
            }
            else {
                my $auth = "Authorization: Token $influx_token";
                my $payload = "-XPOST \"$influxdb_url\" -d \"$data\" --header \"$auth\"";
            }
            my @influxcommand = ('curl', '-i', $payload);
            #print join (/ /, @influxcommand), "\n";
            my @output = run_command(@influxcommand);
        }
}

sub get_hd_list {
    my @vals;
    if ($operating_system eq 'freebsd' ) {
      my @freebsdcmd = ('camcontrol', 'devlist');
      foreach (run_command(@freebsdcmd)) {
        next if (/SSD|Verbatim|Kingston|Elements|Enclosure|Virtual|KINGSTON/);
        if (/\(((a?da\d+),pass\d+)\)/) {
            #dprint(2, $2);
            push(@vals, $2);
        }
      }
      #dprint_list(3, "@vals");
    }
    elsif ($operating_system eq 'linux' ) {
      my @linuxcmd = ('sfdisk', '-l');
      my $joinedcmd = join("\n", run_command(@linuxcmd));
      my @drivechunks = split(/\n{3}/, $joinedcmd);
      foreach (@drivechunks) {
          next if (/Verbatim|Kingston|Elements|Enclosure|Virtual|KINGSTON|mapper/);
          if (/^Disk\s+\/dev\/(s.+):/) {
              #print $1;
              push(@vals, $1);
          }
      }
      #dprint_list(3, "@vals");
      #print join (/ /, @vals), "\n";
    }
    return @vals;
}


sub get_nvme_list {
    my @vals;
  if ($operating_system eq 'freebsd' ) {
    my @freebsdcmd = ('nvmecontrol', 'devlist');
 
    foreach (run_command(@freebsdcmd)) {
      next if (/WDC|Enclosure|Virtual/);
      if (/(nvme[\d])\:/) {
            #print $1;
            push(@vals, $1);
        }
      }
      #dprint_list(3, "@vals");
    }
  elsif ($operating_system eq 'linux' ) {
    my @linuxcmd = ('nvme', 'list');
 
    foreach (run_command(@linuxcmd)) {
      next if (/WDC|Enclosure|Virtual/);
      if (/\/dev\/(nvme\d)n\d/) {
          #print $1;
          push(@vals, $1);
      }
    }
    #dprint_list(3, "@vals");
    #print join (/ /, @vals), "\n";
  }
  
  return @vals;
}

sub get_one_drive_temp
{
    my $disk_dev = shift;
    my @diskcommand = ($smartctlCmd, '-a', "/dev/$disk_dev");
    my $temp;
    my $serial;
    my $megapattern = qr/[Ss]erial [Nn]umber\:\s*(\S*)\s[\s|\S]*(?|Temperature_Celsius[\s|\S]{64}(\d*)\s|Airflow_Temperature_Cel[\s|\S]{60}(\d*)\s|Temperature\:\s*(\d*)\sCelsius|Temperature_Internal[\s|\S]{63}(\d*)\s|Current Drive Temperature\:[\s|\S]*(\d*)\s)/;
    
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

