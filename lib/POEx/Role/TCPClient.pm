package POEx::Role::TCPClient;

#ABSTRACT: A Moose Role that provides TCPClient behavior

use MooseX::Declare;

role POEx::Role::TCPClient with POEx::Role::SessionInstantiation
{
    use MooseX::AttributeHelpers;
    use POEx::Types(':all');
    use MooseX::Types::Moose(':all');
    use POE::Wheel::ReadWrite;
    use POE::Wheel::SocketFactory;
    use POE::Filter::Line;
    
    use aliased 'POEx::Role::Event';

=head1 REQUIRES

=head2 METHODS

=head3 handle_inbound_data($data, WheelID $id) is Event

This required method will be passed the data received, and from which wheel 
it came. 

=cut

    requires 'handle_inbound_data';

=attr socket_factory is: rw, isa: Object, predicate: has_socket_factory, clearer: clear_socket_factory

The POE::Wheel::SocketFactory created in connect is stored here.

=cut

    has socket_factory =>
    (
        is          => 'rw',
        isa         => Object,
        predicate   => 'has_socket_factory',
        clearer     => 'clear_socket_factory',
    );

=attr wheels metaclass: Collection::Hash, is: rw, isa: HashRef, clearer: clear_wheels

When connections are finished, a POE::Wheel::ReadWrite object is created and 
stored in this attribute, keyed by WheelID. Wheels may be accessed via the
following provided methods. See MooseX::AttributeHelpers::Collection::Hash
for more details.

    provides    =>
    {
        get     => 'get_wheel',
        set     => 'set_wheel',
        delete  => 'delete_wheel',
        count   => 'has_wheels',
    }

=cut

    has wheels =>
    (
        metaclass   => 'MooseX::AttributeHelpers::Collection::Hash',
        is          => 'rw',
        isa         => HashRef,
        lazy        => 1,
        default     => sub { {} },
        clearer     => 'clear_wheels',
        provides    =>
        {
            get     => 'get_wheel',
            set     => 'set_wheel',
            delete  => 'delete_wheel',
            count   => 'has_wheels',
        }
    );

=attr filter is: rw, isa: Filter

This stores the filter that is used when constructing wheels. It will be cloned
for each connection completed.

=cut

    has filter =>
    (
        is          => 'rw',
        isa         => Filter,
        default     => sub { POE::Filter::Line->new() }
    );

=method connect(Str :$remote_address, Int :$remote_port) is Event

connect is used to initiate a connection to a remote source. It accepts two 
named arguments that both required, remote_address and remote_port. They are 
passed directly to SocketFactory.

=cut

    method connect(Str :$remote_address, Int :$remote_port) is Event
    {
        $self->socket_factory
        (
            POE::Wheel::SocketFactory->new
            (
                RemoteAddress       => $remote_address,
                RemotePort          => $remote_port,
                SuccessEvent        => 'handle_on_connect',
                FailureEvent        => 'handle_connect_error',
                Reuse               => 1,
            )
        );
    }

=method handle_on_connect(GlobRef $socket, Str $address, Int $port, WheelID $id) is Event

handle_on_connect is the SuccessEvent of the SocketFactory instantiated in _start. 

=cut

    method handle_on_connect (GlobRef $socket, Str $address, Int $port, WheelID $id) is Event
    {
        my $wheel = POE::Wheel::ReadWrite->new
        (
            Handle      => $socket,
            Filter      => $self->filter->clone(),
            InputEvent  => 'handle_inbound_data',
            ErrorEvent  => 'handle_socket_error',
        );
        
        $self->set_wheel($wheel->ID, $wheel);
        $self->clear_socket_factory
    }

=method handle_connect_error(Str $action, Int $code, Str $message) is Event

handle_connect_error is the FailureEvent of the SocketFactory

=cut

    method handle_connect_error(Str $action, Int $code, Str $message) is Event
    {
        warn "Received connect error: Action $action, Code $code, Message $message"
            if $self->options->{'debug'};
    }

=method handle_socket_error(Str $action, Int $code, Str $message, WheelID $id) is Event

handle_socket_error is the ErrorEvent of each POE::Wheel::ReadWrite instantiated.

=cut

    method handle_socket_error(Str $action, Int $code, Str $message, WheelID $id) is Event
    {
        warn "Received socket error: Action $action, Code $code, Message $message"
            if $self->options->{'debug'};
    }
}

1;
__END__
=head1 DESCRIPTION

POEx::Role::TCPClient bundles up the lower level SocketFactory/ReadWrite
combination of wheels into a simple Moose::Role. It builds upon other POEx
modules such as POEx::Role::SessionInstantiation and POEx::Types. 

The events for SocketFactory and for each ReadWrite instantiated are
methods that can be advised in any way deemed fit. Advising these methods
is actually encouraged and can simplify code for the consumer. 

The only method that must be provided by the consuming class is 
handle_inbound_data.

The connect event must be invoked to initiate a connection.

