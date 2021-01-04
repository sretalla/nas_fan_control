#!/usr/local/bin/perl -w

use strict;
use warnings;

main();

################################################ MAIN

sub main {
    @hd_list = get_hd_list();
    print @hd_list;
}

sub dprint {
    my ( $level, $output ) = @_;

#    print( "dprintf: debug = $debug, level = $level, output = \"$output\"\n" );

    if ( $debug > $level ) {
        my $datestring = build_date_time_string();
        print DEBUG_LOG "$datestring: $output\n";
    }

    return;
}

sub dprint_list {
    my ( $level, $name, @output ) = @_;

    if ( $debug > $level ) {
        dprint( $level, "$name:" );

        foreach my $item (@output) {
            dprint( $level, " $item" );
        }
    }

    return;
}

sub run_command {
    my @cmd = @_;
    my ($out, $err);
    dprint(3, 'run_command: '.join(' ', @cmd));
    my $command = join(' ', @cmd);
    $out = `$command`;
    print $out;
    # if (!run \@cmd, \undef, \$out, \$err) {
    #     chomp($err);
    #     dprint(0, "command [@cmd] failed: $err");
    #     die "command [@cmd] failed: $err";
    # }
    chomp($out);
    dprint(2, $out);
    return split(/\n/, $out);
}

sub get_hd_list {
    my @cmd = ('smdisk', '-l');
    my @vals;
   
    my @result = run_command(@cmd)) 
        $pattern = qr/(Disk.*)\n(Disk model.*)\n\n/;
        @lines = join("\n", @result) =~ m/$pattern/g;
        @speed = split(/ /, @lines[2]);
        $ocl_current_fan_speeds[ $ocl_zones[$zone]->{$fan} ] = $speed[1];
        next if (/SSD|Verbatim|Kingston|Elements|Enclosure|Virtual|KINGSTON/);
        if (/\((?:pass\d+,(a?da\d+)|(a?da\d+),pass\d+)\)/) {
            dprint(2, $1);
            push(@vals, $1);
        
    }
    dprint(3, "@vals");
    return @vals;
}
