#!/usr/bin/perl

# ------------------------------------------------------------------------------
use Modern::Perl;
use Const::Fast;
use English qw/-no_match_vars/;
use File::Which;
use IPC::Run       qw/run/;
use Proc::Find     qw/find_proc/;
use Sys::SigAction qw/set_sig_handler/;
our $VERSION = 'v1.3';

# ------------------------------------------------------------------------------
my @xargs = ('-f');
my $timeout;

for (@ARGV) {
    if (/^-t=(\d+)$/sm) {
        $timeout = $1;
    }
    elsif ( $_ eq '-b' ) {
        push @xargs, '-b';
    }
    else {
        _usage();
    }
}
$timeout or _usage();

const my $SEC_IN_MIN     => 60;
const my $MILLISEC       => 1_000;
const my @TERMSIG        => qw/INT HUP TERM QUIT USR1 USR2 PIPE ABRT BUS FPE ILL SEGV SYS TRAP/;
const my $XPRINTIDLE_EXE => 'xprintidle';
const my $XTRLOCK_EXE    => 'xtrlock';
my $xprintidle = which($XPRINTIDLE_EXE);
$xprintidle or _no_exe($XPRINTIDLE_EXE);
my $xtrlock = which($XTRLOCK_EXE);
$xtrlock or _no_exe($XTRLOCK_EXE);

# ------------------------------------------------------------------------------
$timeout *= ( $SEC_IN_MIN * $MILLISEC );

set_sig_handler 'ALRM', sub {

    my $x = find_proc( name => $XTRLOCK_EXE );
    if ( @{$x} == 0 ) {
        my $idle;
        run [$xprintidle], \&_do_nothing, \$idle, \&_do_nothing;
        $idle =~ s/^\s+|\s+$//gsm;
        if ( $idle >= $timeout ) {
            run [ $xtrlock, @xargs ], \&_do_nothing, \&_do_nothing, \&_do_nothing;
        }
    }

    return alarm $SEC_IN_MIN;
};
set_sig_handler $_, \&_unlock for @TERMSIG;
alarm 1;

while (1) {
    sleep $SEC_IN_MIN;
}
_unlock();

# ------------------------------------------------------------------------------
sub _do_nothing
{
    return;
}

# ------------------------------------------------------------------------------
sub _unlock
{
    my $x = find_proc( name => $XTRLOCK_EXE );
    kill 'TERM', $_ for @{$x};
    return exit 0;
}

# ------------------------------------------------------------------------------
sub _no_exe
{
    my ($exe) = @_;
    printf "Error: executable '%s' not found.\n", $exe;
    return exit 1;
}

# ------------------------------------------------------------------------------
sub _usage
{
    printf "Usage: %s options:\n  -t=minutes (timeout)\n  -b (blank screen after lock)\n", $PROGRAM_NAME;
    return exit 1;
}

# ------------------------------------------------------------------------------
