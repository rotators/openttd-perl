package OpenTTD::Utils;

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
		&FLAG
	);
}

sub FLAG($$)
{
	my $var  = shift;
	my $flag = shift;

	return( ($var & $flag) != 0 );
}

1;
