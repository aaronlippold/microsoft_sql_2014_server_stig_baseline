control 'SV-213881' do
  title 'SQL Server must produce Trace or Audit records when security objects are accessed.'
  desc "Changes to the security configuration must be tracked.

This requirement applies to situations where security data is retrieved or modified via data manipulation operations, as opposed to via SQL Server's built-in security functionality (GRANT, REVOKE, DENY, ALTER [SERVER] ROLE ... ADD/DROP MEMBER ..., etc.).

In SQL Server, types of access include, but are not necessarily limited to:
SELECT
INSERT
UPDATE
DELETE
EXECUTE

Since the system views are read-only, and the underlying tables are kept hidden by SQL Server, the Insert, Update and Delete cases are relevant only where the database includes user-defined tables to support additional security functionality.

Use of SQL Server Audit is recommended.  All features of SQL Server Audit are available in the Enterprise and Developer editions of SQL Server 2014.  It is not available at the database level in other editions.  For this or legacy reasons, the instance may be using SQL Server Trace for auditing, which remains an acceptable solution for the time being.  Note, however, that Microsoft intends to remove most aspects of Trace at some point after SQL Server 2016.  Note also that Trace does not support auditing of SELECT statements, whereas Audit does."
  desc 'check', %q(If there are no locally-defined security tables, functions, or procedures, this is not applicable.

If neither SQL Server Audit nor SQL Server Trace is in use for audit purposes, this is a finding.

Obtain the list of locally-defined security tables that require tracking of Insert-Update-Delete operations.

If SQL Server Trace is in use for audit purposes, review these tables for the existence of triggers to raise a custom event on each Insert-Update-Delete operation.

If such triggers are not present, this is a finding.

Check to see that all required event classes are being audited.  From the query prompt:
SELECT * FROM sys.traces;

All currently defined traces for the SQL server instance will be listed.

If no traces are returned, this is a finding.

Determine the trace(s) being used for the auditing requirement.

In the following, replace # with a trace ID being used for the auditing requirements.
From the query prompt:
SELECT DISTINCT(eventid) FROM sys.fn_trace_geteventinfo(#);

The following required event IDs should be among those listed; if not, this is a finding:

42  -- SP:Starting
43  -- SP:Completed
82-91  -- User-defined Event (at least one of these; 90 is used in the supplied script)
162 -- User error message


If SQL Server Audit is in use, proceed as follows.

The basic SQL Server Audit configuration provided in the supplemental file Audit.sql uses the broad, server-level audit action group SCHEMA_OBJECT_ACCESS_GROUP for this purpose.  SQL Server Audit's flexibility makes other techniques possible.  If an alternative technique is in use and demonstrated effective, this is not a finding.

Determine the name(s) of the server audit specification(s) in use.

To look at audits and audit specifications, in Management Studio's object explorer, expand
<server name> >> Security >> Audits
and
<server name> >> Security >> Server Audit Specifications.
Also,
<server name> >> Databases >> <database name> >> Security >> Database Audit Specifications.

Alternatively, review the contents of the system views with "audit" in their names.

Run the following to verify that all SELECT, INSERT, UPDATE, and DELETE actions on locally-defined permissions tables, and EXECUTE actions on locally-defined permissions functions and procedures, are being audited:

USE [master];
GO
SELECT * FROM sys.server_audit_specification_details WHERE server_specification_id =
(SELECT server_specification_id FROM sys.server_audit_specifications WHERE [name] = '<server_audit_specification_name>')
AND audit_action_name = 'SCHEMA_OBJECT_ACCESS_GROUP';

If no row is returned, this is a finding.

If the audited_result column is not "SUCCESS" or "SUCCESS AND FAILURE", this is a finding.)
  desc 'fix', 'Where SQL Server Trace is in use, create triggers to raise a custom event on each table that requires tracking of Insert-Update-Delete operations.  The examples provided in the supplemental file CustomTraceEvents.sql can serve as the basis for these.

Add a block of code to the supplemental file Trace.sql for each custom event class (integers in the range 82-91; the same event class may be used for all such triggers) used in these triggers.  Execute Trace.sql.

If SQL Server Audit is in use, design and deploy an Audit that captures all auditable events and data items.  The script provided in the supplemental file Audit.sql can be used as the basis for this.  Supplement the standard audit data as necessary, using Extended Events and/or triggers.

Alternatively, to add the necessary data capture to an existing server audit specification, run the script:
USE [master];
GO
ALTER SERVER AUDIT SPECIFICATION <server_audit_specification_name> WITH (STATE = OFF);
GO
ALTER SERVER AUDIT SPECIFICATION <server_audit_specification_name> ADD (SCHEMA_OBJECT_ACCESS_GROUP);
GO
ALTER SERVER AUDIT SPECIFICATION <server_audit_specification_name> WITH (STATE = ON);
GO'
  impact 0.5
  ref 'DPMS Target MS SQL Server 2014 Instance'
  tag check_id: 'C-15100r312994_chk'
  tag severity: 'medium'
  tag gid: 'V-213881'
  tag rid: 'SV-213881r961791_rule'
  tag stig_id: 'SQL4-00-035600'
  tag gtitle: 'SRG-APP-000492-DB-000332'
  tag fix_id: 'F-15098r312995_fix'
  tag 'documentable'
  tag legacy: ['SV-82407', 'V-67917']
  tag cci: ['CCI-000172']
  tag nist: ['AU-12 c']

  server_trace_implemented = input('server_trace_implemented')
  server_audit_implemented = input('server_audit_implemented')

  sql_session = mssql_session(user: input('user'),
                              password: input('password'),
                              host: input('host'),
                              instance: input('instance'),
                              port: input('port'),
                              db_name: input('db_name'))

  query_traces = %(
    SELECT * FROM sys.traces
  )
  query_trace_eventinfo = %(
    SELECT DISTINCT(eventid) FROM sys.fn_trace_geteventinfo(%<trace_id>s);
  )

  query_audits = %(
    SELECT audited_result
    FROM   sys.server_audit_specification_details
    WHERE  audit_action_name = 'SCHEMA_OBJECT_ACCESS_GROUP';
  )

  describe.one do
    describe 'SQL Server Trace is in use for audit purposes' do
      subject { server_trace_implemented }
      it { should be true }
    end

    describe 'SQL Server Audit is in use for audit purposes' do
      subject { server_audit_implemented }
      it { should be true }
    end
  end

  if server_trace_implemented
    describe 'List defined traces for the SQL server instance' do
      subject { sql_session.query(query_traces) }
      it { should_not be_empty }
    end

    trace_ids = sql_session.query(query_traces).column('id')
    describe.one do
      trace_ids.each do |trace_id|
        found_events = sql_session.query(format(query_trace_eventinfo, trace_id: trace_id)).column('eventid')
        describe "EventsIDs in Trace ID:#{trace_id}" do
          subject { found_events }
          it { should include '42' }
          it { should include '43' }
          it { should include '90' }
          it { should include '162' }
        end
      end
    end
  end

  if server_audit_implemented
    describe 'SQL Server Audit:' do
      describe 'Defined Audits with Audit Action SCHEMA_OBJECT_ACCESS_GROUP' do
        subject { sql_session.query(query_audits) }
        it { should_not be_empty }
      end
      describe 'Audited Result for Defined Audit Actions' do
        subject { sql_session.query(query_audits).column('audited_result').uniq.to_s }
        it { should match(/SUCCESS AND FAILURE|SUCCESS/) }
      end
    end
  end
end
