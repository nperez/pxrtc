use Test::More;

use POE;
use MooseX::Declare;

class Client 
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
        $self->yield('shutdown');
    }

    with 'POEx::Role::TCPClient';
    
    after shutdown is Event
    {
        pass('shutdown called');
    }

    before connect(Str :$remote_address, Int :$remote_port, Ref :$tag?) is Event
    {
        pass('before connect called');

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

        pass('Server socket created');
    }

    after handle_on_connect(GlobRef $socket, Str $address, Int $port, WheelID $id) is Event
    {
        if($self->has_connection_tag($id))
        {
            pass('Got tag');

            my $tag = $self->delete_connection_tag($id);

            is_deeply($tag, {one => 1, two => [2]}, 'connection tag is unmunged');
        }
    }

    method accept_socket(GlobRef $socket, Str $address, Int $port, WheelID $id) is Event
    {
        pass('Socket accept called');
        print $socket "TEST\n";
        $self->clear_server;
    }

    method fail_listen(Str $action, Int $err, Str $msg, WheelID $id) is Event
    {
        diag("Failed to $action: $err -> $msg");
        BAIL_OUT(q|Can't listen for client connection|);
    }
}

Client->new(alias => 'foo', options => { debug => 1, trace => 1});
POE::Kernel->post('foo', 'connect', remote_address => '127.0.0.1', remote_port => 54444, tag => {one => 1, two => [2]});

POE::Kernel->run();
done_testing();
