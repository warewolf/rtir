# {{{ BEGIN BPS TAGGED BLOCK
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2004 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# }}} END BPS TAGGED BLOCK
#
package RT::Action::RTIR_ResolveChildren;
use strict;
use base 'RT::Action::RTIR';

use RT::IR::Ticket;

=head2 Prepare

Check if the Incident is being closed.

=cut


sub Prepare {
    my $self = shift;
    my @inactive = $self->TicketObj->QueueObj->InactiveStatusArray;
    my $new_status = $self->TransactionObj->NewValue;

    return 0 unless grep $_ eq $new_status, @inactive;
    return 1;
}

# {{{ sub Commit

=head2 Commit

Resolve all children.

=cut

sub Commit {
    my $self = shift;
    my $id = $self->TicketObj->Id;

    my $query =  "(Queue = 'Incident Reports'"
                ." OR Queue = 'Investigations'"
                ." OR Queue = 'Blocks'"
                .") AND MemberOf = " . $id
                ." AND ("
                # TODO: move to per queue statuses lists
                . join(" AND ", map "Status != '$_'", RT->Config->Get('InactiveStatus') )
                .")";

    my $members = new RT::Tickets( $self->TransactionObj->CurrentUser );
    $members->FromSQL( $query );
    while ( my $member = $members->Next ) {
        if ( RT::IR::Ticket::IsLinkedToActiveIncidents( $member, $self->TicketObj ) ) {
            $member->Comment(Content => <<END);

Linked Incident \#$id was resolved, but ticket still has unresolved linked Incidents.

END
            next;
        }
        my ($res, $msg) = $member->Resolve;
        $RT::Logger->info( "Couldn't resolve ticket: $msg" ) unless $res;
    }
    return 1;
}

# }}}

eval "require RT::Action::RTIR_ResolveChildren_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RTIR_ResolveChildren_Vendor.pm});
eval "require RT::Action::RTIR_ResolveChildren_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RTIR_ResolveChildren_Local.pm});

1;
