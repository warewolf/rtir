package RT::Action::RTIR_MergeIPs;

use strict;
use warnings;

use base 'RT::Action::RTIR';

=head2 Prepare

Always run this.

=cut

sub Prepare { return 1 }

=head2 Commit

Change the ownership of children.

=cut

sub Commit {
    my $self = shift;

    my $txn = $self->TransactionObj;
    my $uri = $txn->NewValue;

    my $uri_obj = RT::URI->new( $self->CurrentUser );
    my ($status) = $uri_obj->FromURI( $uri );
    unless ( $status && $uri_obj->Resolver && $uri_obj->Scheme ) {
        $RT::Logger->error( "Couldn't resolve '$uri' into a URI." );
        return 1;
    }

    my $target = $uri_obj->Object;
    return 1 if $target->id eq $txn->ObjectId;

    my $source = RT::Ticket->new( $self->CurrentUser );
    $source->LoadById( $txn->ObjectId );
    my $values = $source->CustomFieldValues( '_RTIR_IP' );
    while ( my $value = $values->Next ) {
        my ($status, $msg) = $target->AddCustomFieldValue(
            Value => $value->Content,
            Field => '_RTIR_IP',
        );
        $RT::Logger->error("Couldn't add IP address: $msg")
            unless $status;
    }

    return 1;
}

eval "require RT::Action::RTIR_MergeIPs_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RTIR_MergeIPs_Vendor.pm});
eval "require RT::Action::RTIR_MergeIPs_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RTIR_MergeIPs_Local.pm});

1;
