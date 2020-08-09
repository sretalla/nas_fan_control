MASTER_PID_fan_control
collection of scripts to control fan speed on NAS boxes

This is a fork of Kevin Horton's repository with updates from https://github.com/roburban/nas_fan_control by Rob Urban for the Asrock code (and inspiration for the ways to do some of my bits (many thanks):

https://github.com/khorton/nas_fan_control
I made extensive changes to PID_fan_control.pl into a new file - MASTER_PID_fan_control:


These, from Rob's version were included:
added global $script_mode variable which controls whether the script is controlling fans attached to a SuperMicro motherboard with its fan "zones", or to an ASRock-Rack motherboard, which has no zones and similarly for an OpenCorsairLink fan controller.

declaring global and local variables explicitly
reformatting comments and some code to get it to fit on a screen less than 219 characters wide
getting rid of all the calls to superfluous external programs such as [e]grep, awk, sed and using pure Perl
simplifying where possible (for example removing all the newlines from the calls to dprint() and adding one in the dprint() function)
in general, getting it to pass a basic syntax check with "use strict; use warnings;"
a few bug fixes
I removed dependencies on two Perl packages that Rob had added (or effectively didn't add them to Kevin's version):

IPC::RUN
Proc::Daemon

Because it would mean these Perl packages must be installed directly on the FreeNAS OS (if you are running the script there), which is not supported.

I have asked Rob to remove those from his version too.

Snip from Rob's Asrock version:
If $script_mode is set to "asrock", then the "zones" are defined by @asrock_zones, and ipmi command to set the duty-cycle is:

ipmitool raw 0x3a 0x01 <FAN1-duty-cycle> .. <FAN6-duty-cycle> <filler> <filler>
for example, to set all six fans to 50% duty-cycle:

ipmitool raw 0x3a 0x01 0x32 0x32 0x32 0x32 0x32 0x32 0x0 0x0
@asrock_zones is a data-structure with the following format:

my @asrock_zones = (
	{ <FAN-NAME> => { <FAN-ENTRY> }, ..., [<FAN-NAME> => { <FAN-ENTRY> } }, # zone-0
	{ <FAN-NAME> => { <FAN-ENTRY> }, ..., [<FAN-NAME> => { <FAN-ENTRY> } }, # zone-1
);
where:

<FAN-NAME> is arbitrary. I used "FAN1" .. "FAN6"
<FAN-ENTRY> is a hashref with two keys, "index" and optionally "factor"
index points to the fan position in the ipmitool command
factor is a floating value that modifies the duty-cycle value of the PID controller (will be limited to 100%)
This data-structure should ideally find its way into a config file.

My case has a "fan wall" between the front section, where the HDs reside, and the rear section, where the mobo and PSU reside. The fan wall has three identical fans (120mm Corsair Maglevs). These are connected to FAN2, FAN3 and FAN4. The rear of the case has two 80mm Be Quiet! fans connected to FAN5 and FAN6. Because I think the case fans should spin faster than the ones in the fan wall, I used factor 1.1 (10% faster) on them.
---------------------------

Now for the new stuff from me:

OpenCorsairLink is a reverse engineered version of the official software provided for the Windows Platform only by Corsair for their Fan (and LED) controller devices.
The original project can be found here: https://github.com/audiohacked/OpenCorsairLink and is not in development by it's original owner. I have forked it to cover against the removal of the working version that's there now, but have made no specific updates to the project at this point, so am not specifically linking my fork here.

If the $script_mode is set to "ocl" (OpenCorsairLink mode), the following variables need to be set:
my @ocl_zones = (
    { 'Fan 0' => 0 },  # CPU, Zone index 0
    { 'Fan 1'=> 1, 'Fan 2' => 2,}, # HD, Zone index 1
);

Fans can be added in either of the zones up to the last fan supported by the attached controller, in my case of a Commander Pro, that would be from "Fan 0" to "Fan 5", they don't need to be in any particular order

If you will be logging temperatures from the onboard sensors on a Commander Pro, you need to have this variable populated:
my @ocl_sensors = ("Temperature 0", "Temperature 1", "Temperature 2", "Temperature 3");
You don't need to have all of the sensors in the list if you aren't interested in the values or didn't connect some, just edit the list down to those of use.


The following two variables are polulated, but not really used... they mirror the Asrock equivalent (and an additional one for fan speed), but are not actually needed in the script at present... they could potentially be used to save a few calls to the fan controller to get the last speeds or duty, but would potentially be putdated, so I haven't used them at this stage:
@ocl_current_fan_duty_cycle_values
@ocl_current_fan_speeds




I have also added the possibility to log fan and temperature values to an influxdb (I use this for graphing with Grafana to assist with tuning the parameters and just to keep an eye on how things are running):
if $use_influx is set to 1, then all of the other influx values following will be considered... this one is a master switch for influxdb logging 0 will log nothing to influx
if $influx_fan_speed is set to 1, fan speeds will be logged to influx whenever they are read by the script
if $influx_fan_duty is set to 1, the fan duty levels will be logged to influx at the time they are set
if $influx_disks is set to 1, disk temperatures will be logged to influx when read by the script
if $influx_sensors is set to 1, sensor values from the 4 temperature sensors on a Corsair Commander Pro (maybe some other corsair devices) will be logged to influx: maybe later I could get to also logging CPU temps at this point in the script. If you're not using "ocl" mode, set this to 0
set $influxdb_db to the database name that you already created on the influxdb server: ( curl -XPOST 'http://localhost:8086/query' --data-urlencode 'q=CREATE DATABASE "mydb"' )
set $influxdb_host to the IP address or reliably resolvable name of the influxdb server
set $influxdb_port to the influxdb port number    (default 8086)
set $influxdb_protocol to the desired protocol (default http... https not tested by me, but probably involves making sure your certificates are OK)
set $influxdb_hostname to the server name (identifier to appear as part of the item name in influx, you may want to finish this with a dash if you don't like things concatenated directly)
don't mess with  $influxdb_url . leave it as default:  "$influxdb_protocol://$influxdb_host:$influxdb_port/write?db=$influxdb_db"

I did not touch any of the PID controller logic.

sretalla:

MASTER_PID_fan_control.pl - Perl fan control script based on the hybrid fan control script from Kevin Horton, based on the script created by @Stux and the PID logic script from Glorious1, and posted at: https://forums.freenas.org/index.php?threads/script-hybrid-cpu-hd-fan-zone-controller.46159/ . @Stux's script was modified by replacing his fan control loop with a PID controller. This version of the script was settings and gains used by the author on a Norco RPC-4224, with the following fans:

3 x Noctua NF-F12 PWM 120mm fans: hard drive wall fans replaced with .
2 x Noctua NF-A8 PWM 80mm fans: chassis exit fans.
2 x Noctua NH-U9DX I4: CPU cooler.
The hard drive fans are connected to fan headers on a Corsair Commander Pro assigned to the hard drive temperature control portion of the script. The chassis exit fans and the CPU cooler are connected to fan headers assigned to the CPU temperature control portion of the script.

See the scripts for more info and commentary.

Discussion on the FreeNAS forums: https://forums.freenas.org/index.php?threads/pid-fan-controller-perl-script.50908/ and https://www.ixsystems.com/community/threads/opencorsairlink-in-a-jail-to-control-fans.71873/
