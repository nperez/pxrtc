use Test::More('tests', 1);

use POE;
use MooseX::Declare;

class Client with POEx::Role::TCPClient
{
    use MooseX::Types::Moose(':all');
    use POEx::Types(':all');
    use POE::Wheel::SocketFactory;
    use Test::More;
    
    use aliased 'POEx::Role::Event';
    has server => ( is => 'rw', isa => Object, clearer => 'clear_server' );

    method handle_inbound_data($data, WheelID $id) is Event
    {
        is($data, 'TEST', 'Got inbound data');
        $self->clear_wheels;
        $self->clear_socket_factory;
    }

    before connect(Str :$remote_address, Int :$remote_port) is Event
    {
        $self->server
        (
            POE::Wheel::SocketFactory->new
            (
                BindAddress     => $remote_address,
                BindPort        => $remote_port,
                Proto           => 'tcp',
                SuccessEvent    => 'accept_socket',
                FailureEvent    => 'fail_listen',
            )
        );
    }

    method accept_socket(GlobRef $socket, Str $address, Int $port, WheelID $id) is Event
    {
        print $socket "TEST\n";
        $self->clear_server;
    }

    method fail_listen(Str $action, Int $err, Str $msg, WheelID $id) is Event
    {
        diag("Failed to $action: $err -> $msg");
        BAIL_OUT(q|Can't listen for client connection|);
    }
}

Client->new(alias => 'foo');
POE::Kernel->post('foo', 'connect', remote_address => '127.0.0.1', remote_port => 54444);

POE::Kernel->run();
