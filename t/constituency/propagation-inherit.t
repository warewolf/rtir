#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

require "t/rtir-test.pl";

# XXX: we should use new RT::Test features and start server with
# option we want.
if ( RT->Config->Get('_RTIR_Constituency_Propagation') eq 'inherit' ) {
    plan tests => 152;
} else {
    plan skip_all => 'constituency propagation algorithm is not "inherit"';
}

use_ok('RT::IR');

my $cf;
diag "load the field" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = RT::CustomFields->new( $RT::SystemUser );
    $cfs->Limit( FIELD => 'Name', VALUE => '_RTIR_Constituency' );
    $cf = $cfs->First;
    ok $cf, 'have a field';
    ok $cf->id, 'with some ID';
}

my $agent = default_agent();
my $rtir_user = rtir_user();

diag "create an IR with GOVNET constituency and create a new "
    . "incident for the IR, we want it to inherit by default"
        if $ENV{'TEST_VERBOSE'};
{
    my $ir_id = create_ir(
        $agent, { Subject => "test" }, { Constituency => 'GOVNET' }
    );
    ok $ir_id, "created IR #$ir_id";
    display_ticket($agent, $ir_id);

    my $inc_id = create_incident_for_ir(
        $agent, $ir_id, { Subject => "test" },
    );

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $inc_id );
    ok $ticket->id, 'loaded ticket';
    is uc $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
        'GOVNET', 'correct value';
}

diag "create an IR and check that we couldn't change constituency"
    ." value during creation of new linked incident" if $ENV{'TEST_VERBOSE'};
{
    # create an IR
    my $ir_id = create_ir(
        $agent, { Subject => "test" }, { Constituency => 'GOVNET' }
    );
    ok $ir_id, "created ticket #$ir_id";
    display_ticket($agent, $ir_id);
    $agent->content_like( qr/GOVNET/, "value on the page" );
    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $ir_id );
    ok $ticket->id, 'loaded ticket';
    is $ticket->QueueObj->Name, 'Incident Reports', 'correct value';
    is $ticket->FirstCustomFieldValue('_RTIR_Constituency'), 'GOVNET', 'correct value';

    # click [new] near 'incident', set another constituency and create
    $agent->follow_link_ok({text => '[New]'}, "go to 'New Incident' page");
    $agent->form_number(3);
    my $form = $agent->form_number(3);
    ok $form->find_input( $form->value('Constituency'), 'hidden'), 'constituency field is hidden';
    $agent->click('CreateIncident');
    is $agent->status, 200, "Attempted to create the ticket";

    DBIx::SearchBuilder::Record::Cachable::FlushCache();

    # Incident has the same value 
    my $inc_id = get_ticket_id( $agent );
    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $inc_id );
    ok $ticket->id, 'loaded ticket';
    is $ticket->QueueObj->Name, 'Incidents', 'correct value';
    is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
        'GOVNET', 'correct value';

    # And the report too
    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $ir_id );
    ok $ticket->id, 'loaded ticket';
    is $ticket->QueueObj->Name, 'Incident Reports', 'correct value';
    is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
        'GOVNET', 'correct value';
}

diag "create an incident with EDUNET, then create children using Incident input field."
    . " incident's constituency is prefered even if another value's been selected"
        if $ENV{'TEST_VERBOSE'};
{
    my $incident_id = create_rtir_ticket_ok(
        $agent, 'Incidents',
        { Subject => "test" },
        { Constituency => 'EDUNET' },
    );
    {
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $incident_id );
        ok $ticket->id, 'loaded ticket';
        is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
            'EDUNET', 'correct value';
    }

    foreach my $queue( 'Incident Reports', 'Investigations', 'Blocks' ) {
        diag "create a ticket in the '$queue' queue" if $ENV{'TEST_VERBOSE'};

        my $id = create_rtir_ticket_ok(
            $agent, $queue,
            {
                Subject => "test ip",
                Incident => $incident_id,
            },
            { Constituency => 'GOVNET' },
        );

        display_ticket($agent, $id);
        DBIx::SearchBuilder::Record::Cachable::FlushCache();
        
        {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $id );
            ok $ticket->id, 'loaded ticket';
            is uc $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'EDUNET', 'value has been changed';
        } {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $incident_id );
            ok $ticket->id, 'loaded ticket';
            is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'EDUNET', 'incident still has the same value';
        }
    }
}

diag "check that constituency propagates from a child to a parent after 'Edit', and back"
    if $ENV{'TEST_VERBOSE'};
{
    foreach my $queue( 'Incident Reports', 'Investigations', 'Blocks' ) {
        diag "create an incident for linking" if $ENV{'TEST_VERBOSE'};

        my $incident_id = create_rtir_ticket_ok(
            $agent, 'Incidents', { Subject => "test" }, { Constituency => 'GOVNET' },
        );
        diag "create a ticket in the '$queue' queue" if $ENV{'TEST_VERBOSE'};
        my $child_id = create_rtir_ticket_ok(
            $agent, $queue,
            {
                Subject => "test ip",
                Incident => $incident_id,
            },
            { Constituency => 'GOVNET' },
        );
        DBIx::SearchBuilder::Record::Cachable::FlushCache();

        diag "check that both have the same correct constituency" if $ENV{'TEST_VERBOSE'};
        {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $incident_id );
            ok $ticket->id, 'loaded ticket';
            is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'GOVNET', 'correct value';
        } {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $child_id );
            ok $ticket->id, 'loaded ticket';
            is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'GOVNET', 'correct value';
        }
        
        diag "edit constituency on the child" if $ENV{'TEST_VERBOSE'};
        display_ticket($agent, $child_id);
        $agent->follow_link( text => 'Edit' );
        $agent->form_number(3);
        $agent->select("Object-RT::Ticket-$child_id-CustomField-". $cf->id ."-Values" => 'EDUNET' );
        $agent->click('SaveChanges');
        $agent->content_like(qr/Constituency .* changed to EDUNET/mi, 'field is changed');
        DBIx::SearchBuilder::Record::Cachable::FlushCache();

        diag "check that constituency propagates from the child to the parent" if $ENV{'TEST_VERBOSE'};
        {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $child_id );
            ok $ticket->id, 'loaded ticket';
            is uc $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'EDUNET', 'correct value';
        } {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $incident_id );
            ok $ticket->id, 'loaded ticket';
            is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'EDUNET', "incident's constituency has been changed";
        }

        diag "edit constituency on the incident" if $ENV{'TEST_VERBOSE'};
        display_ticket($agent, $incident_id);
        $agent->follow_link( text => 'Edit' );
        $agent->form_number(3);
        $agent->select("Object-RT::Ticket-$incident_id-CustomField-". $cf->id ."-Values" => 'GOVNET' );
        $agent->click('SaveChanges');
        $agent->content_like(qr/Constituency .* changed to GOVNET/mi, 'field is changed');
        DBIx::SearchBuilder::Record::Cachable::FlushCache();

        diag "check that constituency propagatesi from the parent to the child" if $ENV{'TEST_VERBOSE'};
        {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $child_id );
            ok $ticket->id, 'loaded ticket';
            is uc $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'GOVNET', 'correct value';
        } {
            my $ticket = RT::Ticket->new( $RT::SystemUser );
            $ticket->Load( $incident_id );
            ok $ticket->id, 'loaded ticket';
            is $ticket->FirstCustomFieldValue('_RTIR_Constituency'),
                'GOVNET', "incident's constituency has been changed";
        }
    }
}

