package OpenTTD::Admin;

use strict;
use warnings;

BEGIN
{
	use Exporter 'import';
	our( @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION );

	$VERSION = '0.2';

	@ISA = qw( Exporter );
}

use IO::Socket;
use IO::Socket::INET;

use OpenTTD::Constants ':all';
use OpenTTD::Packet;
use OpenTTD::Utils '&FLAG';

use constant
{
	PROTOCOL_MIN => 1,
	PROTOCOL_MAX => 1
};

sub new($;$)
{
	my $self = shift;

	my $host = shift;
	my $port = shift || 3977;

	my $openttd =
	{
		'_host'         => $host,
		'_port'         => $port,
		'_socket'       => undef,
		'_select'       => undef,
		'_packets'      =>
		{
			'in'    => [],
			'out'   => []
		},

		'_debug'        =>
		{
			'send'  => 0,
			'recv'  => 0,
			'queue' => 0
		},

		'_version'      => 0,
		'_freq'         => {}
	};

	$openttd = bless( $openttd, $self );

	# set all server packets as events
	foreach my $key ( keys( %SERVER_PACKET ))
	{
		my $sub = lc($key);
		$openttd->{_event}{$sub} = undef;
	}

	# own events
	$openttd->{_event}{debug} = undef;

	return( $openttd );
}

sub host
{
	my $openttd = shift;

	return( $openttd->{_host} );
}

sub port
{
	my $openttd = shift;

	return( $openttd->{_port} );
}

sub address
{
	my $openttd = shift;

	return( sprintf( "%s:%d", $openttd->{_host}, $openttd->{_port} ));
}

sub event($$)
{
	my $openttd = shift;

	my $name = shift;
	my $sub = shift;

	return( 0 ) if( !defined($name) || !length($name) );

	$name = lc($name);

	return( 0 ) if( !exists($openttd->{_event}{$name}) );

	$openttd->{_event}{$name} = $sub;

	return( 1 );
}

sub run_event($;@)
{
	my( $openttd, $name, @args ) = @_;

	return if( !defined($name) || !length($name) );
	$name = lc($name);

	return if( !exists($openttd->{_event}{$name}) || !defined($openttd->{_event}{$name}) );

	my $sub = $openttd->{_event}{$name};
	&$sub( $openttd, @args );
}

sub debug($;@)
{
	my( $openttd, $prefix, $format, @args ) = @_;

	$format = '' if( !defined($format) );

	my $text = sprintf( $format, @args );
	my @lines = split( /\n/, $text );

	foreach my $line ( @lines )
	{
		next if( !length($line) );

		$openttd->run_event( 'debug', $prefix, $line );
	}
}

sub connect()
{
	my $openttd = shift;

	if( $openttd->connected )
	{
		$openttd->debug( 'connect', "already connected: %s", $openttd->address );
		return( 0 );
	}

	$openttd->debug( 'connect', "%s", $openttd->address );

	$openttd->{_socket} = new IO::Socket::INET
	(
		PeerHost => $openttd->{_host},
		PeerPort => $openttd->{_port},
		Proto    => 'tcp',
		Blocking => 0,
		Timeout  => 5
	);

	if( !$openttd->{_socket} )
	{
		$openttd->debug( 'connect', "can't connect: %s", $openttd->address );
		return( 0 );
	}
	
	$openttd->{_select} = new IO::Select;

	return( 1 );
}

sub connected()
{
	my $openttd = shift;

	return( undef ) if( !defined($openttd->{_socket}) );

	return $openttd->{_socket}->connected();
}

sub disconnect(;$)
{
	my $openttd = shift;

	return if( !$openttd->connected() );

	my $fast = shift || 0;

	$openttd->debug( 'disconnect', $fast ? "fast" : "slow" );

	$openttd->{_packets}{in} = [];
	$openttd->{_packets}{out} = [];

	if( !$fast )
	{
		# automatically send QUIT packet
		$openttd->quit;
		$openttd->send;
	}

	$openttd->{_socket}->close() if( defined($openttd->{_socket}) );

	$openttd->{_socket} = undef;
	$openttd->{_select} = undef;
}

sub recv()
{
	my $openttd = shift;

	$openttd->disconnect if( $openttd->{_quit} );
	return if( !$openttd->connected() );

	$openttd->{_select}->add( $openttd->{_socket} );

	while( $openttd->{_select}->can_read(0.25) )
	{
		my( $len0, $len1 );

		if( !sysread( $openttd->{_socket}, $len0, 1 ) || !sysread( $openttd->{_socket}, $len1, 1 ))
		{
			$openttd->debug( 'recv', "cannot read packet length" );
			last;
		}

		my $len = ord($len0) + (ord($len1) << 8);
		$len -= 2;

		my $type;
		if( !sysread( $openttd->{_socket}, $type, 1 ))
		{
			$openttd->debug( 'recv', "cannot read packet type" );
			next;
		}
		$type = ord($type);
		$len--;

		my $packet;
		if( $len > 0 )
		{
			my $buf;
			my $bytes = sysread( $openttd->{_socket}, $buf, $len );
			$packet = new OpenTTD::Packet( $type, $buf );
		}
		else
		{
			$packet = new OpenTTD::Packet( $type );
		}

		$openttd->dump_packet( $packet, "recv" ) if( $openttd->{_debug}{recv} );

		push( $openttd->{_packets}{in}, $packet );
	}

	$openttd->{_select}->remove( $openttd->{_socket} );
}

sub send()
{
	my $openttd = shift;

	return if( !$openttd->connected() );

	$openttd->{_select}->add( $openttd->{_socket} );
	if( !$openttd->{_select}->can_write(0.25) )
	{
		$openttd->debug( 'send', "cannot write" );
		$openttd->{_select}->remove( $openttd->{_socket} );

		$openttd->disconnect( 1 );
		return;
	}

	my( $count, $quit ) = ( 0, 0 );

	while( defined( my $packet = shift(@{ $openttd->{_packets}{out} })))
	{
		$openttd->dump_packet( $packet, "send" ) if( $openttd->{_debug}{send} );

		$openttd->{_socket}->write( pack( 'C*', @{$packet->{buffer}} ));

		$count++;

		# disconnect as soon QUIT packet is seen
		if( $packet->id == $ADMIN_PACKET{QUIT} )
		{
			$quit = 1;
			last;
		}
	}

	$openttd->{_select}->remove( $openttd->{_socket} );

	$openttd->disconnect( 1 ) if( $quit );

	return( $count );
}

sub queue($)
{
	my $openttd = shift;

	my $packet = shift;

	$openttd->debug( 'queue', $packet->dump ) if( $openttd->{_debug}{queue} );

	push( $openttd->{_packets}{out}, $packet );

	return( scalar(@{ $openttd->{_packets}{out} }));
}

sub process()
{
	my $openttd = shift;

	return if( !$openttd->connected() );

	my $count = 0;

	while( defined( my $packet = shift(@{ $openttd->{_packets}{in} })))
	{
		my $name = lc( $packet->name );
		my $sub = $openttd->can( sprintf( "process_%s", $name ));
		my @args;
		
		if( defined($sub) )
		{
			@args = &$sub( $openttd, $packet );
		}
		else
		{
			$openttd->debug( 'process', "%s::process_%s() not found", __PACKAGE__, $name );
		}

		if( scalar(@args) && $packet->id == $SERVER_PACKET{PROTOCOL} )
		{
			my( $ver, %freq ) = ( @args );
			if( $ver < PROTOCOL_MIN || $ver > PROTOCOL_MAX )
			{
				$openttd->debug( 'process', "UNSUPPORTED PROTOCOL VERSION<%d>\n", $ver );
				$openttd->disconnect;
				last;
			}

			$openttd->{_version} = $ver;
			$openttd->{_freq} = %freq;

		}
		elsif( $packet->id == $SERVER_PACKET{SHUTDOWN} )
		{
			$openttd->disconnect();
			$count++;

			last;
		}

		$openttd->run_event( $name, @args );

		$count++;
	}

	return( $count );
}

sub process_protocol($) # 103
{
	my $openttd = shift;

	my $packet  = shift;

	my $version = $packet->readUint8();
	my %frequency;

	while( $packet->readBool() )
	{
		my $idx = $packet->readUint16();
		my $val = $packet->readUint16();

		$frequency{$idx} = $val;
	}

	return( $version, %frequency );
}

sub process_welcome($) # 104
{
	my $openttd = shift;

	my $packet = shift;

	my $server     = $packet->readString();
	my $rev        = $packet->readString();
	my $dedicated  = $packet->readBool();
	my $map        = $packet->readString();
	my $seed       = $packet->readUint32();
	my $landscape  = $packet->readUint8();
	my $year       = $packet->readUint32();
	my $mx         = $packet->readUint16();
	my $my         = $packet->readUint16();

	return( $server, $rev, $dedicated, $map, $seed, $landscape, $year, $mx, $my );
}

sub process_chat($) # 119
{
	my $openttd = shift;

	my $packet = shift;

	my $action   = $packet->readUint8();
	my $destType = $packet->readUint8();
	my $clientId = $packet->readUint32();
	my $message  = $packet->readString();
	my $data     = $packet->readUint64();

	return( $action, $destType, $clientId, $message, $data );
}

sub process_console($) # 121
{
	my $openttd = shift;

	my $packet = shift;

	my $origin = $packet->readString();
	my $string = $packet->readString();

	return( $origin, $string );
}

sub dump_packet($;$)
{
	my $openttd = shift;

	my $packet = shift;
	my $prefix = shift || 'dump_packet';

	my( $header, @hex, @raw ) = $packet->dump( 1 );
	$openttd->debug( $prefix, $header );

	my( $count, $line ) = ( 0, '' );
	foreach my $var ( @hex, @raw )
	{
		if( !defined($var) )
		{
			$openttd->debug( $prefix, $line );
			$line = '';
			$count = 0;
			next;
		}

		if( $count >= 10 )
		{
			$openttd->debug( $prefix, $line );
			$line = '';
			$count = 0;
		}

		$line .= sprintf( "%5s", $var );
		$count++;
	}

	$openttd->debug( $prefix, $line ) if( length($line) );
}

sub join($$$)
{
	my $openttd = shift;

	if( !$openttd->connected )
	{
		$openttd->debug( 'join', "not connected" );
		return( 0 );
	}

	my $pass = shift;
	my $name = shift;
	my $ver  = shift;

	my $packet = new OpenTTD::Packet( $ADMIN_PACKET{JOIN} );
	$packet->writeString( $pass );
	$packet->writeString( $name );
	$packet->writeString( $ver );

	return( $openttd->queue( $packet ));
}

sub quit()
{
	my $openttd = shift;

	if( !$openttd->connected )
	{
		$openttd->debug( 'quit', "not connected" );
		return( 0 );
	}

	my $packet = new OpenTTD::Packet( $ADMIN_PACKET{QUIT} );

	return( $openttd->queue( $packet ));
}

sub poll($)
{
	my $openttd = shift;

	if( !$openttd->connected )
	{
		$openttd->debug( 'poll', "not connected" );
		return( 0 );
	}

	my $type = shift;

	if( !exists($openttd->{_freq}{$type}) )
	{
		$openttd->debug( 'poll', "unknown type<%d>", $type );
		return( 0 );
	}
	elsif( !FLAG( $openttd->{_freq}{$type}, $FREQUENCY{POLL} ))
	{
		$openttd->debug( 'poll', "polling not allowed for type<%d>", $type );
		return( 0 );
	}

	my $arg  = shift || 0;

	my $packet = new OpenTTD::Packet( $ADMIN_PACKET{POLL} );
	$packet->writeUint8( $type );
	$packet->writeUint32( $arg );

	return( $openttd->queue( $packet ));
}

sub chat_all($)
{
	my $openttd = shift;

	return( $openttd->chat(0,0,0,0,0) );
}

sub chat($$$$$)
{
	my $openttd = shift;

	if( !$openttd->connected )
	{
		$openttd->debug( 'chat', "not connected" );
		return( 0 );
	}

	my $action = shift;
	my $type   = shift;
	my $dest   = shift;
	my $msg    = shift;
	my $data   = shift;

	my $packet = new OpenTTD::Packet( $ADMIN_PACKET{CHAT} );

	$packet->writeUint8( $action );
	$packet->writeUint8( $type );
	$packet->writeUint32( $dest );
	$packet->writeString( $msg );
	$packet->writeUint64( $data );

	return( $openttd->queue( $packet ));
}

sub update_frequency($$)
{
	my $openttd = shift;

	if( !$openttd->connected )
	{
		$openttd->debug( 'update_frequency', "not connected" );
		return( 0 );
	}

	my $type = shift;
	my $freq = shift;

	if( !exists($openttd->{_freq}{$type}) )
	{
		$openttd->debug( 'update_frequency', "unknown type<%d>", $type );
		return( 0 );
	}

	if( !FLAG( $openttd->{_freq}{$type}, $freq ))
	{
		$openttd->debug( 'update_frequency', "update frequency<%d> not allowed for type<%d>", $freq, $type );
		return( 0 );
	}

	my $packet = new OpenTTD::Packet( $ADMIN_PACKET{UPDATE_FREQUENCY} );
	$packet->writeUint16($type);
	$packet->writeUint16($freq);

	return( $openttd->queue( $packet ));
}

1;
