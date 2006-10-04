package Finance::Bank::AllianceAndLeicester;
use strict;
use Carp;
our $VERSION = '1.01';

use WWW::Mechanize;
use HTML::TokeParser;

sub check_balance {
    my ($class, %opts) = @_;
    my @accounts;
    croak 'Must provide a Customer ID'	       unless exists $opts{customerid};
    croak 'Must provide Memorable information' unless exists $opts{memorable};
    croak 'Must provide a Unique Phrase'       unless exists $opts{phrase};
    croak 'Must provide a PIN Code'            unless exists $opts{pin};
    croak 'Customer ID should be 12 digits'    unless $opts{customerid} =~ /^\d{12}$/;
    croak 'PIN Code should be 5 digits'        unless $opts{pin} =~ /^\d{5}$/;

    my $self = bless { %opts }, $class;
    
    # Submit Customer ID
    my $agent = WWW::Mechanize->new();
    $agent->get("https://www.mybank.alliance-leicester.co.uk/login/checkLogin.asp?txtCustomerID=$opts{customerid}");

    # Submit the memorable information
    $agent->get("https://www.mybank.alliance-leicester.co.uk/login/checkPM5.asp?txtMemDetail=$opts{memorable}");

    # Check we have got the correct Unique Phrase
    my $content = $agent->content;
    my $stream = HTML::TokeParser->new(\$content) or die "$!";
    for (my $a=0; $a<5; $a++) {
        $stream->get_tag("span");
    }
    my $phrase = $stream->get_trimmed_text('/span');
   
    croak "Unique Phrase Mismatch." unless(lc($phrase) eq lc($opts{phrase}));
    
    # Submit the PIN Number
    $agent->get("https://www.mybank.alliance-leicester.co.uk/login/checkPM4point1.asp?txtCustomerPIN=$opts{pin}");

    # Check for login errors
    $content = $agent->content;
    $stream = HTML::TokeParser->new(\$content) or die "$!";
    while(my $token = $stream->get_tag('div')) {
        if($token->[1]{'id'} eq 'error') {
	    my $error = $stream->get_trimmed_text('/div');
            croak "Error During Login: $error\n";
            last;
        }
    }

    # save this data to parse later
    $content = $agent->{content};

    # We have the data we need, so lets logout
    $agent->get("https://www.mybank.alliance-leicester.co.uk/login/calls/logout.asp");

    # Begin parsing the HTML
    $stream = HTML::TokeParser->new(\$content) or die "$!";
    $stream->get_tag("tr");

    while (my $token = $stream->get_tag('tr')) {

        my($accountbalance, $accountname, 
            $accountoverdraft, $accountnumber, $accountavailable);

	# Get the Account Name and number
	$token = $stream->get_tag('td');
	$accountname = $stream->get_trimmed_text('/td');
	$accountname =~ s/\s(\d+)$//;
	$accountnumber = $1;

	# Get the balance
	$stream->get_tag('td');
	$accountbalance = $stream->get_trimmed_text('/td');

        # Get overdraft
	$stream->get_tag('td');
	$accountoverdraft = $stream->get_trimmed_text('/td');

	# Get Available Balance
	$stream->get_tag('td');
        $accountavailable = $stream->get_trimmed_text('/td');

	# Strip pounds signs from balances
	$accountbalance   =~ s/^\x{00A3}//;
	$accountoverdraft =~ s/^\x{00A3}//;
        $accountavailable =~ s/^\x{00A3}//;

	# Strip Comma ',' from balances
	$accountbalance   =~ s/\,//g;
        $accountoverdraft =~ s/\,//g;
        $accountavailable =~ s/\,//g;
                   
        # Add to list of accounts to return
        push @accounts, {
            balance           => $accountbalance,
            name              => $accountname,
            overdraft         => $accountoverdraft,
	    account           => $accountnumber,
            available_balance => $accountavailable
        };
    }

    # Return the list of accounts
    return @accounts;
}

1;
__END__
# Documentation is below here

=head1 NAME

Finance::Bank::AllianceAndLeicester - Check your Alliance & Leicester bank accounts from Perl

=head1 SYNOPSIS

  use Finance::Bank::AllianceAndLeicester;
  my @accounts = Finance::Bank::AllianceAndLeicester->check_balance(
      customerid  => '012345678912',
      pin         => '12345',
      memorable   => 'mybirthplace',
      phrase      => 'my unique phrase'
  );

  foreach (@accounts) {
      printf "%12s(%20s):  GBP %8.2f (Overdraft: GBP %8.2f Available: GBP %8.2f)\n",
        $_->{account}, $_->{name}, $_->{balance}, $_->{overdraft}, $_->{available_balance} ;
  }

=head1 DESCRIPTION

This module provides a rudimentary interface to the Alliance & Leicester
online banking system at C<https://www.mybank.alliance-leicester.co.uk/>. 

=head1 DEPENDENCIES

You will need either C<Crypt::SSLeay> or C<IO::Socket::SSL> installed 
for HTTPS support to work with LWP.  This module also depends on 
C<WWW::Mechanize> and C<HTML::TokeParser> for screen-scraping.

=head1 CLASS METHODS

=over

=item B<check_balance>

    check_balance ( customerid => $c, 
                    pin        => $p, 
                    memorable  => $m, 
                    phrase     => $s 
    )

Return an array of account hashes, one for each of your bank accounts.

=item customerid

The Customer ID is 12 Digit number supplied with your account

=item pin

Your 5 Digit PIN Number

=item memorable

This is your memorable information. Such as your birth place. 
This is asked for when you first login to your bank account.

=item phrase

Your unique phrase. This is used to make sure we are connecting to
the Alliance & Leicester website and that the connection has not been hijacked.

This is created when you fisrt sign up your account, and can be changed on the 
Alliance & Leicester internet banking website.

=back

=head1 ACCOUNT HASH KEYS 

    $ac->account
    $ac->name
    $ac->balance
    $ac->overdraft
    $ac->available_balance
 
Return the account number, account name (eg. 'PlusSaver'), account
balance, account overdraft limit and available balance as a signed floating point value.

=head1 WARNING

This warning is from Simon Cozens' C<Finance::Bank::LloydsTSB>, and seems
just as apt here.

This is code for B<online banking>, and that means B<your money>, and
that means B<BE CAREFUL>. You are encouraged, nay, expected, to audit
the source of this module yourself to reassure yourself that I am not
doing anything untoward with your banking data. This software is useful
to me, but is provided under B<NO GUARANTEE>, explicit or implied.

=head1 THANKS

Simon Cozens for C<Finance::Bank::LloydsTSB> and Chris Ball for Finance::Bank::HSBC, 
upon which most of this code is based. 
Andy Lester (and Skud, by continuation) for WWW::Mechanize, Gisle Aas for HTML::TokeParser.

=head1 CHANGELOG

=over

=item Version 1.01 - 04/10/2006 - Ian Bissett <ian@tekuiti.co.uk>

* Strip commas (',') from balances.

=back

=head1 AUTHOR

Ian Bissett C<ian.bissett@tekuiti.co.uk>

=cut
