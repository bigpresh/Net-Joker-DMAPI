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


=cut

has username => (
    is => 'rw',
    isa => 'Str',
);
has password => (
    is => 'rw',
    isa => 'Str',
);
has debug => (
    is => 'rw',
    isa => 'Str',
    default => 0,
);
has ua => (
    is => 'rw',
    isa => 'LWP::UserAgent',
    lazy_build => 1,
);
has dmapi_url => (
    is => 'rw',
    isa => 'Str',
    default => 'https://dmapi.joker.com/request',
);
sub _build_ua {
    my $ua = LWP::UserAgent->new;
    $ua->agent(__PACKAGE__ . "/$VERSION");
    return $ua;
}

has auth_sid => (
    is => 'rw',
    isa => 'Str',
    default => '',
    predicate => 'has_auth_sid',
);

sub login {
    my $self = shift;
    
    # If we've already logged in, we're fine
    # TODO: do we need to test the auth-sid is still valid?
    return 1 if $self->has_auth_sid;

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
