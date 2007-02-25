#! /usr/bin/perl -w

# mass-bug: mass-file a bug report against a list of packages
# For options, see the usage message below.
#
# Copyright 2006 by Joey Hess <joeyh@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=head1 NAME

mass-bug - mass-file a bug report against a list of packages

=head1 SYNOPSIS

mass-bug [options] --subject="bug subject" template package-list

=head1 DESCRIPTION

mass-bug assists in filing a mass bug report in the Debian BTS on a set of
packages. For each package in the package-list file (which should list one
package per line), it fills out the template, adds BTS pseudo-headers, and
either displays or sends the bug report.

Warning: Some care has been taken to avoid unpleasant and common mistakes,
but this is still a power tool that can generate massive amounts of bug
report mails. Use it with care, and read the documentation in the
Developer's Reference about mass filing of bug reports first.

=head1 TEMPLATE

The template file is the body of the message that will be sent for each bug
report, excluding the BTS pseudo-headers. In the template, #PACKAGE# is
replaced with the name of the package.

Note that text in the template will be automatically word-wrapped to
70 columns, up to the start of a signature (indicated by S<'-- '> at
the start of a line on its own).

=head1 OPTIONS

B<mass-bug> examines the B<devscripts> configuration files as described
below.  Command line options override the configuration file settings,
though.

=over 4

=item --severity=(wishlist|minor|normal|important|serious|grave|critical)

Specify the severity with which bugs should be filed. Default
is 'normal'.

=item --display

Fill out the templates for each package and display them all for
verification. This is the default behavior.

=item --send

Actually send the bug reports.

=item --subject="bug subject"

Specify the subject of the bug report. The subject will be automatically
prefixed with the name of the package that the bug is filed against.

=item --sendmail=SENDMAILCMD

Specify the sendmail command.  The command will be split on white
space and will not be passed to a shell.  Default is '/usr/sbin/sendmail'.

=item --no-conf, --noconf

Do not read any configuration files.  This can only be used as the
first option given on the command-line.

=item --help

Provide a usage message.

=item --version

Display version information.

=over 4

=back

=head1 ENVIRONMENT

DEBEMAIL and EMAIL can be set in the environment to control the email
address that the bugs are sent from.

=head1 CONFIGURATION VARIABLES

The two configuration files F</etc/devscripts.conf> and
F<~/.devscripts> are sourced by a shell in that order to set
configuration variables.  Command line options can be used to override
configuration file settings.  Environment variable settings are
ignored for this purpose.  The currently recognised variables are:

=over 4

=item BTS_SENDMAIL_COMMAND

If this is set, specifies a sendmail command to use instead of
/usr/sbin/sendmail.  Same as the --sendmail command line option.

=back

=cut

use strict;
use Getopt::Long;
use Text::Wrap;
use File::Basename;

my $progname = basename($0);
$Text::Wrap::columns=70;
my $submission_email="maintonly\@bugs.debian.org";
my $sendmailcmd='/usr/sbin/sendmail';
my $modified_conf_msg;

sub usageerror {
    die "Usage: $progname [options] --subject=\"bug subject\" <template> <package-list>\n";
}

sub usage {
    print <<"EOT";
Usage:
  $progname [options] --subject="bug subject" <template> <package-list>

Valid options are:
   --display              Display the messages but don\'t send them
   --send                 Actually send the mass bug reports to the BTS
   --subject="bug subject"
                          Text for email subject line (will be prefixed
                          with "package: ")
   --severity=(wishlist|minor|normal|important|serious|grave|critical)
                          Specify the severity of the bugs to be filed
                          (default "normal")
   --sendmail=cmd         Sendmail command to use (default /usr/sbin/sendmail)
   --no-conf, --noconf    Don\'t read devscripts config files;
                          must be the first option given
   --help                 Display this message
   --version              Display version and copyright info

   <template>             File containing email template; #PACKAGE# will
                          be replaced by the package name
   <package-list>         File containing list of packages, one per line

  Ensure that you read the Developer\'s Reference on mass-filing bugs before
  using this script!

Default settings modified by devscripts configuration files:
$modified_conf_msg
EOT
}

sub version () {
    print <<"EOF";
This is $progname, from the Debian devscripts package, version ###VERSION###
This code is copyright 2006 by Joey Hess, all rights reserved.
This program comes with ABSOLUTELY NO WARRANTY.
You are free to redistribute this code under the terms of the
GNU General Public License, version 2 or later.
EOF
}


# Next, read read configuration files and then command line
# The next stuff is boilerplate

if (@ARGV and $ARGV[0] =~ /^--no-?conf$/) {
    $modified_conf_msg = "  (no configuration files read)";
    shift;
} else {
    my @config_files = ('/etc/devscripts.conf', '~/.devscripts');
    my %config_vars = (
		       'BTS_SENDMAIL_COMMAND' => '/usr/sbin/sendmail',
		       );
    my %config_default = %config_vars;
    
    my $shell_cmd;
    # Set defaults
    foreach my $var (keys %config_vars) {
	$shell_cmd .= qq[$var="$config_vars{$var}";\n];
    }
    $shell_cmd .= 'for file in ' . join(" ",@config_files) . "; do\n";
    $shell_cmd .= '[ -f $file ] && . $file; done;' . "\n";
    # Read back values
    foreach my $var (keys %config_vars) { $shell_cmd .= "echo \$$var;\n" }
    my $shell_out = `/bin/bash -c '$shell_cmd'`;
    @config_vars{keys %config_vars} = split /\n/, $shell_out, -1;

    # Check validity
    $config_vars{'BTS_SENDMAIL_COMMAND'} =~ /./
	or $config_vars{'BTS_SENDMAIL_COMMAND'}='/usr/sbin/sendmail';

    if ($config_vars{'BTS_SENDMAIL_COMMAND'} ne '/usr/sbin/sendmail') {
	my $cmd = (split ' ', $config_vars{'BTS_SENDMAIL_COMMAND'})[0];
	unless ($cmd =~ /^[A-Za-z0-9_\-\+\.\/]*$/) {
	    warn "BTS_SENDMAIL_COMMAND contained funny characters: $cmd\nReverting to default value /usr/sbin/sendmail\n";
	    $config_vars{'BTS_SENDMAIL_COMMAND'}='/usr/sbin/sendmail';
	} elsif (system("command -v $cmd >/dev/null 2>&1") != 0) {
	    warn "BTS_SENDMAIL_COMMAND $cmd could not be executed.\nReverting to default value /usr/sbin/sendmail\n";
	    $config_vars{'BTS_SENDMAIL_COMMAND'}='/usr/sbin/sendmail';
	}
    }

    foreach my $var (sort keys %config_vars) {
	if ($config_vars{$var} ne $config_default{$var}) {
	    $modified_conf_msg .= "  $var=$config_vars{$var}\n";
	}
    }
    $modified_conf_msg ||= "  (none)\n";
    chomp $modified_conf_msg;

    $sendmailcmd = $config_vars{'BTS_SENDMAIL_COMMAND'};
}


sub gen_subject {
    my $subject=shift;
    my $package=shift;

    return "$package\: $subject";
}

sub gen_bug {
    my $template_text=shift;
    my $package=shift;
    my $severity=shift;

    $template_text=~s/#PACKAGE#/$package/g;
    if ($template_text =~ /\A(.*?)(^-- $.*)/m) { # there's a sig involved
	my ($presig, $sig) = ($1, $2);
	$template_text=fill("", "", $presig) . $sig;
    } else {
	$template_text=fill("", "", $template_text);
    }
    return "Package: $package\nSeverity: $severity\n\n$template_text";
}
		
sub div {
    print +("-" x 79)."\n";
}

sub mailbts {
    my ($subject, $body, $to, $from) = @_;

    if (defined $from) {
	my $date = `822-date`;
	chomp $date;
	
	my $pid = open(MAIL, "|-");
	if (! defined $pid) {
	    die "$progname: Couldn't fork: $!\n";
	}
	$SIG{'PIPE'} = sub { die "bts: pipe for $sendmailcmd broke\n"; };
	if ($pid) {
	    # parent
	    print MAIL <<"EOM";
From: $from
To: $to
Subject: $subject
Date: $date
X-Generator: mass-bug from devscripts ###VERSION###

$body
EOM
	    close MAIL or die "$progname: sendmail error: $!\n";
	}
	else {
	    # child
	    exec(split(' ', $sendmailcmd), "-t")
		or die "$progname: error running sendmail: $!\n";
	}
    }
    else { # No $from
	unless (system("command -v mail >/dev/null 2>&1") == 0) {
	    die "$progname: You need to either specify an email address (say using DEBEMAIL)\n or have the mailx/mailutils package installed to send mail!\n";
	}
	my $pid = open(MAIL, "|-");
	if (! defined $pid) {
	    die "bts: Couldn't fork: $!\n";
	}
	$SIG{'PIPE'} = sub { die "bts: pipe for mail broke\n"; };
	if ($pid) {
	    # parent
	    print MAIL $body;
	    close MAIL or die "$progname: error running mail: $!\n";
	}
	else {
	    # child
	    exec("mail", "-s", $subject, $to)
		or die "$progname: error running mail: $!\n";
	}
    }
}

my $mode="display";
my $subject;
my $severity="normal";
my $opt_sendmail;
if (! GetOptions(
		 "display" => sub { $mode="display" },
		 "send" => sub { $mode="send" },
		 "subject=s" => \$subject,
		 "severity=s" => \$severity,
		 "sendmail=s" => \$opt_sendmail,
		 "help" => sub { usage(); exit 0; },
		 "version" => sub { version(); exit 0; },
		 )) {
    usageerror();
}

if (! defined $subject || ! length $subject) {
    print STDERR "$progname: You must specify a subject for the bug reports.\n";
    usageerror();
}

unless ($severity =~ /^(wishlist|minor|normal|important|serious|grave|critical)$/) {
    print STDERR "$progname: Severity must be one of wishlist, minor, normal, important, serious, grave or critical.\n";
    usageerror();
}

if (@ARGV != 2) {
    usageerror();
}

if ($opt_sendmail) {
    if ($opt_sendmail ne '/usr/sbin/sendmail'
	and $opt_sendmail ne $sendmailcmd) {
	my $cmd = (split ' ', $opt_sendmail)[0];
	unless ($cmd =~ /^[A-Za-z0-9_\-\+\.\/]*$/) {
	    warn "--sendmail command contained funny characters: $cmd\nReverting to default value $sendmailcmd\n";
	    unset $opt_sendmail;
	} elsif (system("command -v $cmd >/dev/null 2>&1") != 0) {
	    warn "--sendmail command $cmd could not be executed.\nReverting to default value $sendmailcmd\n";
	    unset $opt_sendmail;
	}
    }
}
$sendmailcmd = $opt_sendmail if $opt_sendmail;


my $template=shift;
my $package_list=shift;

my $template_text;
open (T, "$template") || die "$progname: error reading $template: $!\n";
{
    local $/=undef;
    $template_text=<T>;
}
close T;
if (! length $template_text) {
    die "$progname: empty template\n";
}

my @packages;
open (L, "$package_list") || die "$progname: error reading $package_list: $!\n";
while (<L>) {
    chomp;
    if (! /^[-+\.a-z0-9]+$/) {
	die "\"$_\" does not look like the name of a Debian package\n";
    }
    push @packages, $_;
}
close L;

# Uses variables from above.
sub showsample {
    my $package=shift;

    print "To: $submission_email\n";
    print "Subject: ".gen_subject($subject, $package)."\n";
    print "\n";
    print gen_bug($template_text, $package, $severity)."\n";
}

if ($mode eq 'display') {
    print "Displaying all ".scalar(@packages)." bug reports..\n";
    print "Run again with --send switch to send the bug reports.\n";
    div();
    foreach my $package (@packages) {
	showsample($package);
	div();
    }
}
elsif ($mode eq 'send') {
    my $from;
    $from ||= $ENV{'DEBEMAIL'};
    $from ||= $ENV{'EMAIL'};
    
    print "Preparing to send ".scalar(@packages)." bug reports like this one:\n";
    div();
    showsample($packages[0]);
    div();
    $|=1;
    print "Are you sure that you have read the Developer's Reference on mass-filing\nbug reports, have checked this case out on debian-devel, and really want to\nsend out these ".scalar(@packages)." bug reports? [yes/no] ";
    my $ans = <STDIN>;
    unless ($ans =~ /^yes$/i) {
	print "OK, aborting.\n";
	exit 0;
    }
    print "OK, going ahead then...\n";
    foreach my $package (@packages) {
	print "Sending bug for $package ...\n";
	mailbts(gen_subject($subject, $package),
		gen_bug($template_text, $package, $severity),
		$submission_email, $from);
    }
    print "All bugs sent.\n";
}

=head1 COPYRIGHT

This program is Copyright (C) 2006 by Joey Hess <joeyh@debian.org>.

It is licensed under the terms of the GPL, either version 2 of the
License, or (at your option) any later version.

=head1 AUTHOR

Joey Hess <joeyh@debian.org>

=cut