package OpenTTD::Constants;

use strict;
use warnings;

BEGIN
{
	use Exporter 'import';
	our( @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION );

	$VERSION = '0.1';

	@ISA = qw( Exporter );

	@EXPORT_OK = qw
	(
		%ADMIN_PACKET
		%SERVER_PACKET
		%UPDATE
		%FREQUENCY
		%DESTINATION
		%NETWORK
	);

	%EXPORT_TAGS =
	(
		all => [qw(
			%ADMIN_PACKET
			%SERVER_PACKET
			%UPDATE
			%FREQUENCY
			%DESTINATION
			%NETWORK
		)],

		packets => [qw(
			%ADMIN_PACKET
			%SERVER_PACKET
		)],
	);
}

# enum PacketAdminType, src/network/core/tcp_admin.h
our %ADMIN_PACKET = #new Tie::IxHash
(
	
	'JOIN'             => 0,
	'QUIT'             => 1,
	'UPDATE_FREQUENCY' => 2,
	'POLL'             => 3,
	'CHAT'             => 4,
	'RCON'             => 5,
	'GAMESCRIPT'       => 6,
	'PING'             => 7
);

# enum PacketAdminType, src/network/core/tcp_admin.h
our %SERVER_PACKET = #new Tie::IxHash
(
	'FULL'            => 100,
	'BANNED'          => 101,
	'ERROR'           => 102,
	'PROTOCOL'        => 103,
	'WELCOME'         => 104,
	'NEWGAME'         => 105,
	'SHUTDOWN'        => 106,

	'DATE'            => 107,
	'CLIENT_JOIN'     => 108,
	'CLIENT_INFO'     => 109,
	'CLIENT_UPDATE'   => 110,
	'CLIENT_QUIT'     => 111,
	'CLIENT_ERROR'    => 112,

	'COMPANY_NEW'     => 113,
	'COMPANY_INFO'    => 114,
	'COMPANY_UPDATE'  => 115,
	'COMPANY_REMOVE'  => 116,
	'COMPANY_ECONOMY' => 117,
	'COMPANY_STATS'   => 118,

	'CHAT'            => 119,
	'RCON'            => 120,
	'CONSOLE'         => 121,
	'CMD_NAMES'       => 122,
	'CMD_LOGGING'     => 123,
	'GAMESCRIPT'      => 124,
	'RCON_END'        => 125,
	'PONG'            => 126
);

use constant INVALID_PACKET_TYPE    => 0xFF;

our %UPDATE = #new Tie::IxHash
(
#enum AdminUpdateType, src/network/core/tcp_admin.h
	'DATE'            => 0,
	'CLIENT_INFO'     => 1,
	'COMPANY_INFO'    => 2,
	'COMPANY_ECONOMY' => 3,
	'COMPANY_STATS'   => 4,
	'CHAT'            => 5,
	'CONSOLE'         => 6,
	'CMD_NAMES'       => 7,
	'CMD_LOGGING'     => 8,
	'GAMESCRIPT'      => 9,
	'END'             => 10,
);

#enum AdminUpdateFrequency, src/network/core/tcp_admin.h
our %FREQUENCY =
(
	'POLL'      => 0x01,
	'DAILY'     => 0x02,
	'WEEKLY'    => 0x04,
	'MONTHLY'   => 0x08,
	'QUARTERLY' => 0x10,
	'ANUALLY'   => 0x20,
	'AUTOMATIC' => 0x40,
);

# enum DestType, src/network/network_type.h
our %DESTINATION = #new Tie::IxHash
(
	DESTTYPE_BROADCAST => 0,
	DESTTYPE_TEAM      => 1,
	DESTTYPE_CLIENT    => 2
);

# enum NetworkAction, src/network/network_type.h
our %NETWORK = #new Tie::IxHash
(
	NETWORK_JOIN              => 0,
	NETWORK_LEAVE             => 1,
	NETWORK_SERVER_MESSAGE    => 2,
	NETWORK_CHAT              => 3,
	NETWORK_CHAT_COMPANY      => 4,
	NETWORK_GIVE_MONEY        => 5,
	NETWORK_NAME_CHANGE       => 6,
	NETWORK_COMPANY_SPECTATOR => 7,
	NETWORK_COMPANY_JOIN      => 8,
	NETWORK_COMPANY_NEW       => 9
);

1;
