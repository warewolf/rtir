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
package RT::Action::RTIR_SetIncidentReportState;

use strict;
use warnings;

use base 'RT::Action::RTIR_SetState';

=head2 GetState

Returns state of the C<Incident Report>.

=cut

sub GetState {
    my $self = shift;

    my $status = $self->TicketObj->Status;
    return $status if $status eq 'resolved' || $status eq 'rejected';

    if ( $status =~ /^(?:new|open|stalled)$/ ) {
        # TODO: check how do we set (control) Status of the IR
        # may be we don't need to check this conditions and
        # just use status value as in other RTIR_Set*State actions

        my $parents = RT::Tickets->new( $self->TransactionObj->CurrentUser );
        $parents->LimitHasMember( $self->TicketObj->id );
        $parents->LimitQueue( VALUE => 'Incidents' );
        return 'open' if $parents->Count;
        return 'new';
    }

    return '';
}

eval "require RT::Action::RTIR_SetIncidentReportState_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RTIR_SetIncidentReportState_Vendor.pm});
eval "require RT::Action::RTIR_SetIncidentReportState_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RTIR_SetIncidentReportState_Local.pm});

1;
