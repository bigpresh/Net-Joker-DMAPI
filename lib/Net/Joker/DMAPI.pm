package Net::Joker::DMAPI;

our $VERSION = '0.01';
use strict;
use 5.010;
use LWP::UserAgent;
use Moose;
use URI;

=head1 NAME

Net::Joker::DMAPI - interface to Joker's Domain Management API

=head1 DESCRIPTION

An attempt at a sane wrapper around Joker's DMAPI (domain management API).

Automatically logs in, and parses responses into somethign a bit more usable as
much as possible.

=head1 SYNOPSIS

    my $dmapi = Joker::DMAPI->new(
        username => 'bob@example.com',
        password => 'hunter2',
    );

    my $whois_details = $dmapi->query_whois($domain);

=head1 ATTRIBUTES

=over

=item username

Your Joker account username.

=cut

has username => (
    is => 'rw',
    isa => 'Str',
);

=item password

Your Joker account password

=cut

has password => (
    is => 'rw',
    isa => 'Str',
);

=item debug

Whether to omit debug messages; disabled by default, set to a true value to
enable.

=cut

has debug => (
    is => 'rw',
    isa => 'Str',
    default => 0,
);

=item ua

An LWP::UserAgent object to use.  One is constructed by default, so you don't
need to supply this unless you have a specific need to do so.

=cut

has ua => (
    is => 'rw',
    isa => 'LWP::UserAgent',
    lazy_build => 1,
);
sub _build_ua {
    my $ua = LWP::UserAgent->new;
    $ua->agent(__PACKAGE__ . "/$VERSION");
    return $ua;
}

=item dmapi_url

The URL to Joker's DMAPI.  You won't need to provide this unless you for some
reason need to have requests go elsewhere; it defaults to Joker's live DMAPI
URL.

=cut

has dmapi_url => (
    is => 'rw',
    isa => 'Str',
    default => 'https://dmapi.joker.com/request',
);

has auth_sid => (
    is => 'rw',
    isa => 'Str',
    default => '',
    predicate => 'has_auth_sid',
);

=back

=head1 METHODS

=over

=item login

Logs in to the Joker DMAPI, retrieves the C<Auth-Sid> from the response, and
stores it in the C<auth_sid> attribute for future requests.  You won't usually
need to call this, as it will happen automatically if you use the convenience
methods, but if you want to poke at C<do_request> yourself, you'll need it.

=cut

sub login {
    my $self = shift;
    
    # If we've already logged in, we're fine
    # TODO: do we need to test the auth-sid is still valid?
    if (!$self->has_auth_sid) {
        $self->debug_output("Already have auth_sid, no need to log in");
        return 1;
    }

    my $login_result = $self->do_request(
        'login',
        { username => $self->username, password => $self->password }
    );
    my ($auth_sid) = $login_result =~ /^Auth-Sid: \s+ (\S+) /mx;

    if ($auth_sid) {
        $self->auth_sid($auth_sid);
        return 1;
    } else {
        die "Login request did not return an Auth-Sid";
    }
}


=item do_request

Takes the method name you want to call, and a hashref of arguments, calls the
method, and returns the response.

For instance:

  my $response = $dmapi->do_request('query-whois', { domain => $domain });

The response returned is as given by Joker's (inconsistent) API, though; so
you'll probably want to look for a suitable method in this class which takes
care of parsing the response and returning something useful.  If a method for
the DMAPI method you wish to use doesn't yet exist, contact me or submit a patch
:)  In particular, some requests don't return the result, just an ID which
you'll then need to use to poll for the result.

=cut

# Given a method name and some params, perform the request, check for success,
# and return the result
sub do_request {
    my ($self, $method, $params) = @_;

    my $url = $self->form_request_url($method, $params);
    $self->debug_output("Calling $method - URL: $url");
    my $response = $self->ua->get($url);

    if (!$response->is_success) {
        die sprintf "$method request failed with status %d (%s) ",
            $response->status, $response->status_line;
    } else {
        $self->debug_output("Response status " . $response->status_line);
        $self->debug_output("Response body: " . $response->decoded_content);
    }

    return $response->decoded_content;
}


# Given a method name and parameters, return the appropriate URL for the request
sub form_request_url {
    my ($self, $method, $args) = @_;
    my $uri = URI->new($self->dmapi_url . "/$method");
    $uri->query_form({ 'auth-sid' => $self->auth_sid, %$args });
    return $uri->canonical;
}

# Emit debug info, if $self
sub debug_output {
    my ($self, $message) = @_;
    say "DEBUG: $message" if $self->debug;
}


"Joker, your API smells of wee.";
