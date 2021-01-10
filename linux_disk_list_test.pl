#!/usr/bin/perl -w
# modify the above for TrueNAS CORE to /usr/local/bin/perl
use strict;
use warnings;

my $debug = 1;

main();

################################################ MAIN

sub main {
    my @hd_list;
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
    my @cmd = ('sfdisk', '-l');
    my @vals;
    my @lines;
    my @desc;
    my @result;
    @result = run_command(@cmd);
        my $pattern = qr/(Disk.*)\n(Disk model.*)\n\n/;
        @lines = join("\n", @result) =~ m/$pattern/g;
        @desc = split(/ /, @lines[2]);
        # $ocl_current_fan_speeds[ $ocl_zones[$zone]->{$fan} ] = $speed[1];
        # next if (/SSD|Verbatim|Kingston|Elements|Enclosure|Virtual|KINGSTON/);
        # if (/\((?:pass\d+,(a?da\d+)|(a?da\d+),pass\d+)\)/) {
        #    dprint(2, $1);
        push(@vals, @lines[1]);
    dprint(3, "@vals");
    return @vals;
}

