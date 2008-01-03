package Finance::Bank::Schwab;

###########################################################################
# Finance::Bank::Schwab
# Mark Grimes
# $Id: Schwab.pm,v 1.7 2007/05/23 20:11:07 mgrimes Exp $
#
# Check you account blances at Charles Schwab.
# Copyright (c) 2005 Mark Grimes (mgrimes@cpan.org).
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the same terms as Perl itself.
#
# Formatted with tabstops at 4
#
# Parts of this package were inspired by:
#   Simon Cozens - Finance::Bank::Lloyds module
# Thanks!
#
###########################################################################
use strict;
use warnings;

use Carp;
use WWW::Mechanize;

our $VERSION = '1.12';

our $ua = WWW::Mechanize->new(
    env_proxy => 1, 
    keep_alive => 1, 
    timeout => 30,
); 


sub check_balance {
    my ($class, %opts) = @_;
    croak "Must provide a password" unless exists $opts{password};
    croak "Must provide a username" unless exists $opts{username};

    my $self = bless { %opts }, $class;

    $ua->get("https://investing.schwab.com/trading/start") or die "couldn't load inital page";
    $ua->submit_form(
    	form_name 	=> 'SignonForm',
    	fields		=> {
    			'SignonAccountNumber'	=> $opts{username},
    			'SignonPassword'		=> $opts{password},
    		},
    ) or die "couldn't sign on to account";
    
	
	# 7/13/05 - no longer works... the "At a Glance" link comes from javascript,
	# but it appears that we can just just to 
	# https://investing.schwab.com/secure/schwab/overview?lvl1=overview

	# Open the top part of the frame
	# $ua->follow_link( name => 'CCBodyi' ) or die "couldn't find the main page frame"

	# Open the At a Glance page
	# $ua->follow_link( text => 'At a Glance' );

	# now the site spits out the links with javascript src'ed at the top of the page
	# my ($javascript_url) = $ua->content =~ m!<script language="JavaScript" src="([^"])!;
	# die "couldn't file the javascript url\n" unless $javascript_url;
	# $ua->get( $javascript_url ) or die "couln't load the javascript url";
	# my ($overview_url) = $ua->content =~ m!"(.*)\\">At a Glance!;
	# https://investing.schwab.com/secure/schwab/overview?cmsid=P-140110&lvl1=overview\">At a Glance
	# but is doesn't look like we need the 
	
	my (@accounts, %balance_info);
	my (%invest_accnts, %bank_accnts);
	
	if( $ua->get( "https://investing.schwab.com/secure/schwab/overview?lvl1=overview" ) ){
		%invest_accnts = $ua->content =~
			m!
				<tr[^>]*>\s*
					<td\ class="asColBrdr[^"]*">
						<a[^>]*>
							([\d-]+)		# account number (name?)
						</a>
					</td>
					<td\ class="nbr\ asColBrdr[^"]*">
						(-?\$[\d,\.]+)		# account balance
					</td>

			!sxig;
	} else {
		warn "Couldn't load the overview page, no investment accounts?";
	}

	if( $ua->get( "https://investing.schwab.com/service?request=BankingHome&lvl1=banking" ) ){
		%bank_accnts = $ua->content =~ 
			m!
				Account \s* ([\d-]+) \s*	# account number (name?)
				.*?
				Total \s+ Balance</font></td> \s*
				<td[^>]*><font[^>]*> \s*
				(-?\$[\d,\.]+)		# account balance
			!sxig;
		
	} else {
		warn "Couldn't load the banking page, no bank accounts?";
	}

	%balance_info = ( %invest_accnts, %bank_accnts );

	# use Data::Dumper;
	# print Dumper \%balance_info;
	# exit();

	#print "Account: $account_no\n";
	#print "Balance: $balance\n";
	#open(F,">tmp.log");
	#print F $ua->content;
	#close F;

	for (keys %balance_info){
		$balance_info{$_} =~ s/[\$,]//g;

		push @accounts, (bless {
			balance		=> $balance_info{$_},
			name		=> $_,
			sort_code	=> $_,
			account_no	=> $_,
			# parent		=> $self,
			statement	=> undef,
		}, "Finance::Bank::Schwab::Account");
	}
    return @accounts;
}

package Finance::Bank::Schwab::Account;
# Basic OO smoke-and-mirrors Thingy
no strict;
sub AUTOLOAD { my $self=shift; $AUTOLOAD =~ s/.*:://; $self->{$AUTOLOAD} }

1;

__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Finance::Bank::Schwab - Check your Charles Schwab accounts from Perl

=head1 SYNOPSIS

  use Finance::Bank::Schwab;
  my @accounts = Finance::Bank::Schwab->check_balance(
	  username => "xxxxxxxxxxxx",
	  password => "12345",
  );

  foreach (@accounts) {
	  printf "%20s : %8s / %8s : USD %9.2f\n",
	  $_->name, $_->sort_code, $_->account_no, $_->balance;
  }
  
=head1 DESCRIPTION

This module provides a rudimentary interface to the Charles Schwab site
at C<https://investing.schwab.com/trading/start>. 
You will need either C<Crypt::SSLeay> or C<IO::Socket::SSL> installed 
for HTTPS support to work. C<WWW::Mechanize> is required.

=head1 CLASS METHODS

=head2 check_balance()

  check_balance( usename => $u, password => $p )

Return an array of account objects, one for each of your bank accounts.

=head1 OBJECT METHODS

  $ac->name
  $ac->sort_code
  $ac->account_no

Return the account name, sort code and the account number. The sort code is
just the name in this case, but it has been included for consistency with 
other Finance::Bank::* modules.

  $ac->balance

Return the account balance as a signed floating point value.

=head1 WARNING

This warning is verbatim from Simon Cozens' C<Finance::Bank::LloydsTSB>,
and certainly applies to this module as well.

This is code for B<online banking>, and that means B<your money>, and
that means B<BE CAREFUL>. You are encouraged, nay, expected, to audit
the source of this module yourself to reassure yourself that I am not
doing anything untoward with your banking data. This software is useful
to me, but is provided under B<NO GUARANTEE>, explicit or implied.

=head1 THANKS

Simon Cozens for C<Finance::Bank::LloydsTSB>. The interface to this module,
some code and the pod were all taken from Simon's module.

=head1 AUTHOR

Mark Grimes <mgrimes@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-7 by mgrimes

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
