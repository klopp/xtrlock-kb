#!/usr/bin/perl

# ------------------------------------------------------------------------------
use Modern::Perl;
use Const::Fast;
use English qw/-no_match_vars/;
use File::Which;
use IPC::Run       qw/run/;
use Proc::Find     qw/find_proc/;
use Sys::SigAction qw/set_sig_handler/;

our $VERSION = 'v1.0';

# ------------------------------------------------------------------------------
my $timeout = $ARGV[0];
_usage() if ( !defined $timeout || $timeout !~ /^\d+$/sm || $timeout < 1 );

const my $XPRINTIDLE_EXE => 'xprintidle';
const my $XTRLOCK_EXE    => 'xtrlock';
my $xprintidle = which($XPRINTIDLE_EXE);
$xprintidle or _no_exe($XPRINTIDLE_EXE);
my $xtrlock = which($XTRLOCK_EXE);
$xtrlock or _no_exe($XTRLOCK_EXE);

# ------------------------------------------------------------------------------
$timeout *= ( 60 * 1000 );

set_sig_handler 'ALRM', sub {

    my $x = find_proc( name => $XTRLOCK_EXE );
    if ( @{$x} == 0 ) {
        my $idle;
        run [$xprintidle], \&_do_nothing, \$idle, \&_do_nothing;
        $idle =~ s/^\s+|\s+$//gsm;
        if ( $idle >= $timeout ) {
            run [ $xtrlock, '-f' ], \&_do_nothing, \&_do_nothing, \&_do_nothing;
        }
    }
    return alarm 60;
};
set_sig_handler 'INT',  \&_unlock;
set_sig_handler 'HUP',  \&_unlock;
set_sig_handler 'TERM', \&_unlock;
set_sig_handler 'QUIT', \&_unlock;
set_sig_handler 'USR1', \&_unlock;
set_sig_handler 'USR2', \&_unlock;
alarm 1;

while (1) {
    sleep 60;
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
    printf "Usage: %s timeout ( >= 1 minute )\n", $PROGRAM_NAME;
    return exit 1;
}

# ------------------------------------------------------------------------------
