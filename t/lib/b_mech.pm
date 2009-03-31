use strict;
use warnings;

#assume same passwd as username
sub login_as{ #this sub doesn't test
   my ($mech,$name) = @_;
   $mech->get ("/logout");
   $mech->get ("/login");
   $mech->form_with_fields( qw/username passwd/ );
   $mech->submit_form(
        fields => {
            username => $name,
            passwd => $name,
        });
   #diag $mech->content;
}
1
