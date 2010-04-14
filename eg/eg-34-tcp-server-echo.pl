# A TCP echo server.
# Strawman use cases for Reflex::Stream and Reflex::Listener.

use lib qw(../lib);

{
	package TcpEchoSession;
	use Moose;
	extends 'Reflex::Stream';

	sub on_stream_data {
		my ($self, $args) = @_;
		$self->put($args->{data});
	}

	sub on_stream_fail {
		my ($self, $args) = @_;
		warn "$args->{errfun} error $args->{errnum}: $args->{errstr}\n";
		$self->emit( event => "shutdown", args => {} );
	}

	sub on_stream_close {
		my ($self, $args) = @_;
		$self->emit( event => "shutdown", args => {} );
	}
}

{
	package TcpEchoServer;

	use Moose;
	extends 'Reflex::Listener';
	use Reflex::Callbacks qw(cb_method);

	has clients => (
		is      => 'rw',
		isa     => 'HashRef[Reflex::Stream]',
		default => sub { {} },
	);

	sub on_listener_accepted {
		my ($self, $args) = @_;

		# TODO - We're developing a pattern here:
		# 1. Create a managed object,
		# 2. The new managed object will contain a weak manager reference.
		# 3. The manager enters the object into a hash, keyed on object.
		# 4. Later, the object will tell the manager when it shuts down.

		my $client = TcpEchoSession->new(
			handle => $args->{socket},
			rd     => 1,
		);

		$self->observe(
			$client,
			shutdown => cb_method($self, "on_client_shutdown")
		);

		$self->clients()->{$client} = $client;
	}

	sub on_listener_fail {
		my ($self, $args) = @_;
		warn "$args->{errfun} error $args->{errnum}: $args->{errstr}\n";
	}

	sub on_client_shutdown {
		my ($self, $args) = @_;
		delete $self->clients()->{$args->{_sender}};
	}
}

my $port = 12345;
print "Setting up TCP echo server on localhost:$port...\n";
TcpEchoServer->new(
	handle => IO::Socket::INET->new(
		LocalAddr => '127.0.0.1',
		LocalPort => $port,
		Listen    => 5,
		Reuse     => 1,
	),
)->run_all();