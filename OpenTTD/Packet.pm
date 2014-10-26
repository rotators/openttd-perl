package OpenTTD::Packet;

use strict;
use warnings;

BEGIN
{
	use Exporter 'import';
	our( @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION );

	$VERSION = '0.1';

	@ISA = qw( Exporter );
}

use OpenTTD::Constants ':packets';

sub new($;$)
{
	my $self = shift;

	my $type = shift;
	my $buf  = shift || undef;

	my $packet =
	{
		'buffer' => [ 0, 0, $type ]
	};

	$packet = bless( $packet, $self );
	
	if( defined($buf) )
	{
		foreach my $byte( unpack( 'C*', $buf ))
		{
			push( $packet->{buffer}, $byte );
		}
		$packet->{pos} = 3;
	}

	$packet->update;
	
	return( $packet );
}

sub dump()
{
	my $packet = shift;

	my $null = shift || 0;


	my( $name, $source ) = $packet->info;
	my $header = sprintf( "packet name<%s> id<%d> source<%s> length<%d>",
		$name, $packet->id, $source, $packet->length );

	my( @hex, @raw );

	foreach my $byte( @{$packet->{buffer}} )
	{
		push( @hex, sprintf( "0x%02X", $byte ));
		push( @raw, sprintf( "%3d",   $byte ));
	}

	if( $null )
	{
		push( @hex, undef );
		push( @raw, undef );
	}

	return( $header, @hex, @raw );
}

sub info()
{
	my $packet = shift;

	my( $name, $source ) = ( 'unknown', 'unknown' );
	foreach my $key ( keys( %ADMIN_PACKET ), keys( %SERVER_PACKET ))
	{
		if( defined($ADMIN_PACKET{$key}) && $ADMIN_PACKET{$key} == $packet->id )
		{
			$name = $key;
			$source = 'client';
			last;
		}
		elsif( defined($SERVER_PACKET{$key}) && $SERVER_PACKET{$key} == $packet->id )
		{
			$name = $key;
			$source = 'server';
			last;
		}
	}

	return( $name, $source );
}

sub id()
{
	my $packet = shift;

	return( $packet->{buffer}[2] );
}

sub name()
{
	my $packet = shift;

	my( $name, undef ) = $packet->info;

	return( $name );
}

sub source()
{
	my $packet = shift;

	my( undef, $source ) = $packet->info;

	return( $source );
}

sub length()
{
	my $packet = shift;

	return( scalar( @{$packet->{buffer}} ));
}

sub readBool()
{
	my $packet = shift;

	return( $packet->readUint8() > 0 );
}

sub readUint8()
{
	my $packet = shift;

	return( @{$packet->{buffer}}[$packet->{pos}++] & 0xFF);
}

sub readUint16()
{
	my $packet = shift;

	my $uint16 = $packet->readUint8();
	$uint16 += $packet->readUint8() << 8;

	return( $uint16 );
}

sub readUint32()
{
	my $packet = shift;

	my $uint32 = $packet->readUint8();
	foreach my $s ( 8, 16, 24 )
	{
		$uint32 += $packet->readUint8() << $s;
	}
=for old
	$uint32 += $packet->readUint8() << 8;
	$uint32 += $packet->readUint8() << 16;
	$uint32 += $packet->readUint8() << 24;
=cut
	return( $uint32 );
}

sub readUint64()
{
	my $packet = shift;

	my $uint64 = $packet->readUint8();
	foreach my $s ( 8, 16, 24, 32, 40, 48, 56 )
	{
		$uint64 += $packet->readUint8() << $s;
	}
=for old
	$uint64 += $packet->readUint8() << 8;
	$uint64 += $packet->readUint8() << 16;
	$uint64 += $packet->readUint8() << 24;
	$uint64 += $packet->readUint8() << 32;
	$uint64 += $packet->readUint8() << 40;
	$uint64 += $packet->readUint8() << 48;
	$uint64 += $packet->readUint8() << 56;
=cut
	return( $uint64 );
}

sub readString()
{
	my $packet = shift;

	my @string;
	while( my $byte = $packet->readUint8() )
	{
		push( @string, $byte );
	}

	return( pack( 'C*', @string ));
}

sub writeUint8($)
{
	my $packet = shift;

	my $uint8 = shift;

	push( $packet->{buffer}, $uint8 & 0xFF );

	$packet->update;
}

sub writeUint16($)
{
	my $packet = shift;

	my $uint16 = shift;

	$packet->writeUint8( $uint16 );
	$packet->writeUint8( $uint16 >> 8);

	$packet->update;
}

sub writeUint32()
{
	my $packet = shift;

	my $uint32 = shift;

	$packet->writeUint8( $uint32 );
	$packet->writeUint8( $uint32 >>  8 );
	$packet->writeUint8( $uint32 >> 16 );
	$packet->writeUint8( $uint32 >> 24 );

	$packet->update;
}

sub writeUint64()
{
	my $packet = shift;

	my $uint64 = shift;

	$packet->writeUint8( $uint64 );
	$packet->writeUint8( $uint64 >>  8 );
	$packet->writeUint8( $uint64 >> 16 );
	$packet->writeUint8( $uint64 >> 24 );
	$packet->writeUint8( $uint64 >> 32 );
	$packet->writeUint8( $uint64 >> 40 );
	$packet->writeUint8( $uint64 >> 48 );
	$packet->writeUint8( $uint64 >> 56 );

	$packet->update;
}

sub writeString($)
{
	my $packet = shift;

	my $string = shift;

	foreach my $byte ( unpack( 'C*', $string ))
	{
		push( $packet->{buffer}, $byte );
	}

	push( $packet->{buffer}, 0 );

	$packet->update;
}

sub update()
{
	my $packet = shift;

	my $len = $packet->length;

	$packet->{buffer}[0] = ($len)      & 0xFF;
	$packet->{buffer}[1] = ($len >> 8) & 0xFF;
}

1;
