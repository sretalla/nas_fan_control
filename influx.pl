#!/usr/local/bin/perl

fanspeeds();
sensors();

sub fanspeeds
{
    my $errorcode = 0;
    my $fan_name = "";
    my $command = "";
    my $influxdb_db="freenas";
    my $influxdb_host="192.168.2.234";
    my $influxdb_port="8086";
    my $influxdb_protocol="http";
    my $influxdb_hostname="medianas";
    my $opencorsairlink = "/mnt/vol6/scripts/OpenCorsairLink.elf.new";
    my $influxdb_url="$influxdb_protocol://$influxdb_host:$influxdb_port/write?db=$influxdb_db";



    my @hd_fan_list = ("Fan 1", "Fan 2", "Fan 3");
    $command = "$opencorsairlink --device 0 --fan channel=0,mode=0";
    print "$command\n";
    my $output = `$command`;
    #print "$output\n";
    my @lines = split /^/, $output;
    $command = "$opencorsairlink --device 0 --fan channel=0,mode=0 | grep 'Fan' | cut -f 1 -d :";
    $output = `$command`;
    #print "$output\n";
    my @fanlist = split /^/, $output;
    foreach my $fan (@fanlist)
        {
            chomp($fan);
            for my $idx (0..$#lines) {
                    #print "$lines[$idx]", chomp($fan);
                    if ($lines[$idx] =~ m/$fan/) {
                            my @tmp = split(" ", $lines[$idx + 2]);
                            (my $fan_nospaces = $fan) =~ s/\s//g;
                            my $data = "FanSpeed,component=$influxdb_hostname$fan_nospaces value=$tmp[1]";
                            $command = "curl -i -XPOST $influxdb_url -d \"$data\"";
                            #print "$command\n";
                            $output = `$command`



                            #print $lines[$idx + 2];


                    }
            }
        }

    return $errorcode;
}

sub sensors
{
    my $errorcode = 0;
    my $fan_name = "";
    my $command = "";
    my $influxdb_db="freenas";
    my $influxdb_host="192.168.2.234";
    my $influxdb_port="8086";
    my $influxdb_protocol="http";
    my $influxdb_hostname="medianas";
    my $opencorsairlink = "/mnt/vol6/scripts/OpenCorsairLink.elf.new";
    my $influxdb_url="$influxdb_protocol://$influxdb_host:$influxdb_port/write?db=$influxdb_db";
    $command = "$opencorsairlink --device 0 --fan channel=0,mode=0";
    #print "$command\n";
    my $output = `$command`;
    #print "$output\n";
    my @lines = split /^/, $output;
    $command = "$opencorsairlink --device 0 --fan channel=0,mode=0 | grep 'Temperature' | cut -f 1 -d :";
    $output = `$command`;
    #print "$output\n";

    #my @templist = grep(/^Temperature/, @lines);
    my @templist = split /^/, $output;
    foreach my $temp (@templist)
        {
            chomp($temp);
            for my $idx (0..$#lines) {
                    #print "$lines[$idx]", chomp($temp);
                    if ($lines[$idx] =~ m/$temp/) {
                            my @tmp = split(" ", $lines[$idx]);
                            (my $temp_nospaces = $temp) =~ s/\s//g;
                            my $data = "SensorTemp,component=$influxdb_hostname$temp_nospaces value=$tmp[2]";
                            $command = "curl -i -XPOST $influxdb_url -d \"$data\"";
                            #print "$command\n";
                            $output = `$command`



                            #print $lines[$idx + 2];


                    }
            }
        }

    return $errorcode;
}
