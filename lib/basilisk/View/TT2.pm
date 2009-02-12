package basilisk::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config({
   TEMPLATE_EXTENSION => '.tt',
   INCLUDE_PATH => [
                basilisk->path_to( 'templates' ),
            ],

});

=head1 NAME

basilisk::View::TT - TT View for basilisk

=head1 DESCRIPTION

TT View for basilisk. 

=head1 AUTHOR

=head1 SEE ALSO

L<basilisk>

Zach Morgan,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
