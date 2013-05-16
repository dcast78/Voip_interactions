#!/usr/bin/perl 

use Sys::Syslog; # all except setlogsock()
use Sys::Syslog qw(:standard :macros); # standard functions & macros

$SIG{'INT'} = 'USCITA';
$SIG{'TERM'} = 'USCITA';
  
$GPIO_pin=23;                                     # Raspberry Pi pin connected to fire alarm
$descrizione_zona="Computer Room";                # Sensor location description
$numero_emergenza="123456789\@sip.messagenet.it"; # Insert a telephon number to call in case of alarm

$filename = '/sys/class/gpio/gpio' . $GPIO_pin;
unless (-e $filename) {
  open (GPIO_SETUP, '>>/sys/class/gpio/export');
	print GPIO_SETUP $GPIO_pin;
} 
close (GPIO_SETUP);
open (GPIO_SETUP, '>>/sys/class/gpio/gpio'. $GPIO_pin . '/direction');
print GPIO_SETUP "in";
close (GPIO_SETUP);
open (GPIO_SETUP, '>>/sys/class/gpio/gpio'. $GPIO_pin . '/edge');
print GPIO_SETUP "rising";
close (GPIO_SETUP);

openlog($program, 'cons,pid', 'user');
syslog('mail|warning', 'Start Fire Monitor on pin %s: %s', $GPIO_pin, $descrizione_zona);

open PIN, "/sys/class/gpio/gpio23/value"; 
$start = time();
while(sysread (PIN, $instring, 1024) > 0) {
#syswrite STDOUT, "evento: $instring\n";
	syswrite STDOUT, "evento: " . localtime . "\n";
	$end = time();
	$timer= $end - $start; 
	printf "Elapsed time: %.0f seconds!\n", $timer;
	if ($timer < 30) { $defcon++; }
	elsif ( $timer >=30 && $timer <= 35) { $defcon=0; } 
	elsif ( $timer > 35) { $defcon="Timeout"; }
	else {$defcon="Condizione imprevista!!";}
	printf "Stato attuale %s\n", $defcon;
	$filename = "/var/spool/asterisk/outgoing/autodial";
	unless (-e $filename) {
	 if ($defcon>=5) {
		open (DATI_CHIAMATA, '>>/tmp/autodial'); 
		print DATI_CHIAMATA "Channel: SIP/" . $numero_emergenza . "\n
Callerid: MENU\n
MaxRetries: 5\n
RetryTime: 300\n
WaitTime: 45\n
Context: noncorso\n
Extension: 1234\n
Priority: 1\n";
		close (DATI_CHIAMATA);
		chmod 0777, "/tmp/autodial"; 
		rename "/tmp/autodial", "/var/spool/asterisk/outgoing/autodial";
		syslog('mail|warning', 'Fire Alarm on Pin: %s Zone: %s', $GPIO_pin, $descrizione_zona);
	 }
	}
	$start = time();
	$pinset = ""; 
	vec ($pinset, fileno(PIN), 1) = 1; 
	$val=select(undef(),undef(),$pinset,45); 
	if ($val==0) {
		printf "Timeout\n"; 
		$defcon="Timeout"; 
		syslog('mail|warning', 'Timeout Fire Monitor pin: %s: %s, problem with battery or disconnected sensor. Pin:', $GPIO_pin, $descrizione_zona);
	};
	seek PIN, 0, 0; 
	select(undef(),undef(),undef(),0.000005)
}

sub USCITA {
	syslog('mail|warning', 'Stop Fire Monitor on pin %s: %s', $GPIO_pin, $descrizione_zona);
	closelog();
	print "\nUscita\n";
	exit(1);
}
