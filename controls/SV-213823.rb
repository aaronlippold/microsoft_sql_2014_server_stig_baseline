control 'SV-213823' do
  title 'Audit tools used in, or in conjunction with, SQL Server must be protected from unauthorized access.'
  desc 'Protecting audit data also includes identifying and protecting the tools used to view and manipulate log data.

Depending upon the log format and application, system and application log tools may provide the only means to manipulate and manage application and system log data. It is, therefore, imperative that access to audit tools be controlled and protected from unauthorized access.

Applications providing tools to interface with audit data will leverage user permissions and roles identifying the user accessing the tools and the corresponding rights the user has in order to make access decisions regarding access to the audit tools. SQL Server is an application that does provide access to audit data.

Audit tools include, but are not limited to, OS-provided audit tools, vendor-provided audit tools, and open source audit tools needed to successfully view and manipulate audit information system activity and records.

If an attacker were to gain access to audit tools, he could analyze audit logs for system weaknesses or weaknesses in the auditing itself. An attacker could also manipulate logs to hide evidence of malicious activity.'
  desc 'check', %q(Check the server documentation for a list of approved users with access to SQL Server Audits.

To create, alter, or drop a server audit, principals require the "ALTER ANY SERVER AUDIT" or the "CONTROL SERVER" permission. To view an Audit log requires the "CONTROL SERVER" permission. To use Profiler, "ALTER TRACE" is required.

Review the SQL Server permissions granted to principals. Look for permissions "ALTER ANY SERVER AUDIT", "ALTER ANY DATABASE AUDIT", "CONTROL SERVER", and "ALTER TRACE":

SELECT login.name, perm.permission_name, perm.state_desc
FROM sys.server_permissions perm     -- or STIG.server_permissions
JOIN sys.server_principals login
ON perm.grantee_principal_id = login.principal_id
WHERE permission_name in ('CONTROL SERVER', 'ALTER ANY DATABASE AUDIT', 'ALTER ANY SERVER AUDIT','ALTER TRACE')
and login.name not like '##MS_%';

If unauthorized accounts have these privileges, this is a finding.)
  desc 'fix', 'Remove audit-related permissions from individuals and roles not authorized to have them.'
  impact 0.5
  ref 'DPMS Target MS SQL Server 2014 Instance'
  tag check_id: 'C-15042r312820_chk'
  tag severity: 'medium'
  tag gid: 'V-213823'
  tag rid: 'SV-213823r960939_rule'
  tag stig_id: 'SQL4-00-013900'
  tag gtitle: 'SRG-APP-000121-DB-000202'
  tag fix_id: 'F-15040r312821_fix'
  tag 'documentable'
  tag legacy: ['SV-82285', 'V-67795']
  tag cci: ['CCI-001493']
  tag nist: ['AU-9 a']

  sql = mssql_session(user: input('user'),
                      password: input('password'),
                      host: input('host'),
                      instance: input('instance'),
                      port: input('port'))
  permissions = sql.query("SELECT login.name as 'result' FROM sys.server_permissions perm JOIN sys.server_principals login ON perm.grantee_principal_id = login.principal_id WHERE permission_name in ('CONTROL SERVER', 'ALTER ANY DATABASE AUDIT', 'ALTER ANY SERVER AUDIT','ALTER TRACE') and login.name not like '##MS_%';").column('result')

  if  permissions.empty?
    impact 0.0
    desc 'There are no sql audit permissions alter any server audit granted control not applicable'

    describe 'There are no sql audit permissions alter any server audit granted, control not applicable' do
      skip 'There are no sql audit permissions  alter any server audit granted, control not applicable'
    end
  else
    permissions.each do |grantee|
      a = grantee.strip
      describe "sql audit permissions alter any server audit: #{a}" do
        subject { a }
        it { should be_in input('approved_users_sql_audits') }
      end
    end
  end
end
