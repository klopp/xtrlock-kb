#!/usr/bin/perl

# ------------------------------------------------------------------------------
use Modern::Perl;
use Const::Fast;
use English qw/-no_match_vars/;
use File::Which;
use IPC::Run       qw/run/;
use Proc::Find     qw/find_proc/;
use Sys::SigAction qw/set_sig_handler/;

# ------------------------------------------------------------------------------
my $timeout = $ARGV[0];
_usage() if ( !defined $timeout || $timeout !~ /^\d+$/ || $timeout < 1 );

const my $XPRINTIDLE_BIN => 'xprintidle';
const my $XTRLOCK_BIN    => 'xtrlock';
my $xprintidle = which($XPRINTIDLE_BIN);
$xprintidle or _no_bin($XPRINTIDLE_BIN);
my $xtrlock = which($XTRLOCK_BIN);
$xtrlock or _no_bin($XTRLOCK_BIN);

# ------------------------------------------------------------------------------
$timeout *= ( 60 * 1000 );

set_sig_handler 'ALRM', sub {

    my $found;
    my $x = find_proc( name => $XTRLOCK_BIN );
    if ( !@{$x} ) {
        my $idle;
        run [$xprintidle], \&_do_nothing, \$idle, \&_do_nothing;
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
alarm 0;

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
    my $x = find_proc( name => $XTRLOCK_BIN );
    kill 'TERM', $_ for @{$x};
    return exit 0;
}

# ------------------------------------------------------------------------------
sub _no_bin
{
    my ($bin) = @_;
    printf "Error: executable '%s' not found.\n", $bin;
    return exit 1;
}

# ------------------------------------------------------------------------------
sub _usage
{
    printf "Usage: %s timeout ( >= 1 minute )\n", $PROGRAM_NAME;
    return exit 1;
}

# ------------------------------------------------------------------------------
