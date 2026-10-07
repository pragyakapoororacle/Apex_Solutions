create or replace package body EAT_pkg as
/** Exceptional Approval Template
Created: 2017.06.14
Developer: andras.a.toth@oracle.com
Modifications:
2017.06.14 - 1.0 - András Tóth - create initial package.
2017.06.16 - 1.1 - András Tóth - adding Attachment, Save Request, Submit Request.
2017.06.19 - 1.2 - András Tóth - adding link to Requests, approve, reject, Re-Submit a Request.
2017.06.20 - 1.3 - András Tóth - small changes in emails, requirements list reduced :-) , is_* functions and some security; inserting to audit log also
2017.07.10 - 1.4 - András Tóth - adding the HC field.
2017.07.14 - 1.5 - András Tóth - adding the Operations and M&A OIM roles.
2019.01.29 - 1.6 - András Tóth - approve via email; more details in the email communications. update get_m_level and get from HR
2019.02.28 - 1.7 - András Tóth - correction issue: approval email lost context when job approves...
2020.02.04 - 1.8 - András Tóth - approval workflow change for M6: we are not escalating above Adrian (M6) anymore. Adding request ID to email subjects, adding more notification emails on actions. Correcting Escalation to be more testable, configurable.
2020.03.17 - 1.9 - András Tóth - SR#20805 - adding new field and changing approval workflow.
2020.05.12 - 2.0 - András Tóth - M level changing to 2 instead of 3. SR-23847
2020.09.01 - 2.1 - András Tóth - SR-24048 & SR-23851 -  Employee Payments Type should be a mandatory field only if you select “Approval Category = Employee Payment”; Payroll Analyst should be able to submit Requests too.
2021.06.30 - 2.2 - András Tóth - moving from Beehive to Exchange email server.
2022.04.08 - 2.3 - András Tóth - enhancing logs for the read_mail procedure.
2022.20.10 - 2.4 - Bhuvnesh Chauhan - removing andras email from sendmail procedure and SR 60769 changes in approve_requests procedure.
2023.24.01 - 2.5 - Bhuvnesh Chauhan - SR #69407.
2023.28.06 - 2.6 - Bhuvnesh Chauhan - SR #80723 - Request of certain type (EMP payment - Legal Rqu) was stopping after one approval it should stop after M2 approval. 
2023.27.09 - 2.7 - Bhuvnesh Chauhan - SR #83348 - EAT mandatory fields for the added for Approval Category = Employee Payment, four new fields added in save_request procedure and the corresponding table columns are added accordingly.
2024.08.05 - 2.8 - Bhuvnesh Chauhan - SR #110110 and SR #108010 - This ADP add on category will send the mail to generic mailbox only after adrian approves it, that means till it reaches M6, so now it won't bother any other categories workflow. 
2024.18.06 - 2.9 - Bhuvnesh Chauhan - Used PAAS in pcg.get_hr_job_level, so this function get_m_level need to be adjusted accordingly.
2024.08.02 - 3.0 - Bhuvnesh Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
2025.02.25 - 3.1 - Rohit kumar - SR 136240 : Approve request if approval level >= c_max_spec_mgr_level
2025.11.05 - 3.2 - Rohit kumar - SR 158776 : (approve_request) 'KAREN.LIM@ORACLE.COM' added as an exception for M level approval , request will go to +1 Adrian too for final Approval
2025.12.23 - 3.3 - Bhuvi Chauhan - Replaced Bhuvi's mail with Marek's mail (Bhuvi Leaving Oracle)
2026.10.07 - 3.4 - Pragya Kapoor - read_mail procedure: If duplicate emails are triggered by the same person for the same request, the subsequent emails remain unread. Updated the code to mark those duplicate emails as read.

*/
 
c_version constant varchar2(5 char) := '3.4';
 
--== SUBROUTINES ==--
 
 
-- TODO: clean up attachmnets, attachment_history where request_id < 0
 
procedure delete_attachment(p_id number) is
/** Delete an attachment of a request
2017.06.15 - 1.0 - András Tóth - create
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'delete_attachment';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_request_id number;
begin
  -- security check:
  if p_id is null or p_id < 1 then raise pcg.invalid_input_value; end if;
  select request_id into v_request_id from EAT_Attachments where id = p_id;
  if is_editable(v_request_id) = 'N' then raise pcg.not_authorized; end if;
 
  -- Delete
  delete from EAT_Attachments where id = p_id;
 
 insert into audit_log values (v('APP_USER'),v('SESSION'),'Exceptional Approval Attachments','DELETE','MANAGER',systimestamp,c_application_id);
 
  commit;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end delete_attachment;
 
procedure test_request_openable(p_user in varchar2 default v('APP_USER'), p_request_id in number default null) is
/** raises exception if request is not openable by the given user.
2020.09.01 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_request_openable';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_id number;
begin
  -- any access at all allowed?
  test_Page_Access(p_user);
  -- allow access to new, negative request.
  if p_request_id < 0 then return; end if;
  -- has user global access?
  if get_region(p_user) = 'GLOBAL' then return; end if;
  -- access to own request:
  select max(id) into v_id from eat_requests_v where REQUESTER = p_user and id = p_request_id;
  if v_id is not null then return; end if;
  -- manager access to request to approve
  select max(id) into v_id from eat_requests_v v where
    v.id = p_request_id and
    is_Manager(p_user) = 'Y' and (
    p_user = v.approver or
    p_user in (
      select replaced_by from EAT_Replacements r
        where r.replaced_user = trim(upper(v.approver)) and
          r.replacement_from_utc < sysdate and
          r.replacement_to_utc > sysdate
      )
    );
  if v_id is not null then return; end if;
  -- default:
  raise pcg.not_authorized;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_request_openable;
 
procedure add_attachment(p_request_id number) is
/** Add an attachment to a request
2017.06.15 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'add_attachment';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  -- security check:
  if p_request_id is null then raise pcg.invalid_input_value; end if;
  if is_editable(p_request_id) = 'N' then raise pcg.not_authorized; end if;
 
  -- Inserting
  insert into EAT_Attachments (request_id, filename, mime_type, blob_content)
  select p_request_id, FILENAME, MIME_TYPE, BLOB_CONTENT
  from apex_application_temp_files;
 
 insert into audit_log values (v('APP_USER'),v('SESSION'),'Exceptional Approval Attachments','SAVE','MANAGER',systimestamp,c_application_id);
 
  commit;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end add_attachment;
 
procedure save_request(
 p_id in out number,
 p_requester varchar2,
 p_request_date date,
 p_category_id number,
 p_documentid varchar2,
 p_country_id number,
 p_amount number,
 p_amount_type_id number,
 p_approval_due_date date,
 p_business_justification varchar2,
 p_new_comments varchar2,
 p_hc number,
 p_employee_payments_type_id number,
 p_chk_pay_dtls varchar2,
 p_chk_interim varchar2,
 p_add_on_req char,
 p_chk_date date
) is
/** Save a request
2017.06.16 - 1.0 - András Tóth - create
2019.02.13 - 1.1 - András Tóth - adding wwv_flow_api.set_security_group_id; and error-proof audit log.
2020.03.17 - 1.2 - András Tóth - adding the Emplyee Payments Type field
2023.26.09 - 1.3 - Bhuvi Chauhan - SR 83348
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'save_request';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_id number;
  v_found number := 0;
  v_comments varchar2(4000 char);
begin
  wwv_flow_api.set_security_group_id;
  -- security check:
  if p_id is null or p_id = 0 then raise pcg.invalid_input_value; end if;
  if is_editable(p_id) = 'N' then raise pcg.not_authorized; end if;
 
  -- Updating case:
  if p_id > 0 then
    select nvl(count(id),0) into v_found from EAT_Requests where id = p_id;
    if v_found > 0 then
      select comments into v_comments from EAT_Requests where id = p_id;
      v_id := p_id;
      update EAT_Requests
         set requester = p_requester,
             request_date = p_request_date,
             category_id = p_category_id,
             documentid = p_documentid,
             country_id = p_country_id,
             amount = p_amount,
             amount_type_id = p_amount_type_id,
             approval_due_date = p_approval_due_date,
             business_justification = p_business_justification,
             employee_payments_type_id = p_employee_payments_type_id,
             comments = substr(v_comments || case when trim(p_new_comments) is not null then '<span style="font-weight: normal;"><b>' ||pcg.email2name(v('APP_USER')) || ' (</b><i style="color: #808080;font-weight: lighter;"><small>'||pcg.to_iso8601_datetime(systimestamp)||'</small></i><b>): </b><br><span style="font-weight: lighter;">'|| p_new_comments||'</span></span>'||CHR(10)||CHR(13) end,1,4000),
             hc = p_hc,
             PAYMENT_DETAILS = p_chk_pay_dtls,
             INTERIM_JUSTIFICATION = p_chk_interim,
             ADD_ON_REQ = p_add_on_req,
             PAYROLL_PRTNR_DATE = p_chk_date
       where id = p_id;
    end if;
  end if;
 
  -- Inserting case
  if p_id < 0 then
    insert into EAT_Requests (
        requester,request_date,category_id,documentid,country_id,amount,amount_type_id,approval_due_date,business_justification,comments,hc,employee_payments_type_id,PAYMENT_DETAILS,INTERIM_JUSTIFICATION,ADD_ON_REQ,PAYROLL_PRTNR_DATE
      ) values (
        p_requester,p_request_date,p_category_id,p_documentid,p_country_id,p_amount,p_amount_type_id,p_approval_due_date,p_business_justification,
        case when trim(p_new_comments) is not null then substr('<span style="font-weight: normal;"><b>' ||pcg.email2name(v('APP_USER')) || ' (</b><i style="color: #808080;font-weight: lighter;"><small>'||pcg.to_iso8601_datetime(systimestamp)||'</small></i><b>): </b><br><span style="font-weight: lighter;">'|| p_new_comments||'</span></span>'||CHR(10)||CHR(13),1,4000) end
        ,p_hc,p_employee_payments_type_id,p_chk_pay_dtls,p_chk_interim,p_add_on_req,p_chk_date
      )
    returning id into v_id;
 
    -- Attachments update:
    update EAT_Attachments set request_id = v_id where request_id = p_id;
 
  end if;
 
  -- Write Back Request ID:
  p_id := v_id;
 
 insert into audit_log values (nvl(v('APP_USER'),p_requester),v('SESSION'),'Exceptional Approvals','SAVE','MANAGER',systimestamp,c_application_id);
 
  commit;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end save_request;
 
function get_manager_email(p_employee_email varchar2) return varchar2 deterministic is
/** Manager email address from LDAP services
2017.06.19 - 1.0 - András Tóth - create
2017.07.14 - 1.1 - András Tóth - removing test environment cases.
2019.02.12 - 1.2 - András Tóth - adding test environment case temporary.
2020.03.17 - 1.3 - András Tóth - removing testing loop.
2024.08.02 - 1.4 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_manager_email';
  c_proc_version constant varchar2(5 char) := '1.2';
 
  v_manager varchar2(256 char);
begin
 
    SELECT upper(MANAGER_EMAIL_ADDRESS) into v_manager
    FROM md_employees where upper(EMP_EMAIL_ADDRESS) = p_employee_email;
    
    -- table(apex_ldap.search ( p_host => 'ldap.oracle.com',
    --                               p_search_base => 'dc=oracle,dc=com',
    --                               p_search_filter =>
    --                                 (
    --                                   SELECT substr(val,1,instr(val,',')-1)
    --                                   FROM TABLE(apex_ldap.search(p_host=>'ldap.oracle.com',
    --                                                               p_search_base=>'dc=oracle,dc=com',
    --                                                               p_search_filter=>'mail='||apex_escape.ldap_search_filter(p_employee_email),
    --                                                               p_attribute_names=>'manager')
    --                                             )
    --                                 ),
    --                               p_attribute_names => 'mail' )
    --           );
 
    return v_manager;
 
exception
when DBMS_LDAP.general_error then return null; /* null when not found */
when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_manager_email;
 
 
procedure submit_request(p_id number, p_requester in varchar2 default v('APP_USER')) is
/** Submit a request
2017.06.16 - 1.0 - András Tóth - create
2019.02.11 - 1.1 - András Tóth - adding p_requester with default.
2020.02.04 - 1.2 - András Tóth - notifying the replacements also.
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'submit_request';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_manager varchar2(256 char);
  v_employee varchar2(256 char) := trim(upper(p_requester));
  v_previous_approval_id number;
begin
  -- security check:
  if p_id is null then raise pcg.invalid_input_value; end if;
  if is_editable(p_id, p_requester) = 'N' then raise pcg.not_authorized; end if;
 
  -- Approval Manager Selection from LDAP:
  v_manager := get_manager_email(v_employee);
 
  -- Save state:
  -- check, if already open state:
  select max(id) into v_previous_approval_id from EAT_Approvals where request_id = p_id and approval_date is null;
  if v_previous_approval_id is not null then
    -- Resubmit:
    update EAT_Approvals set request_id = p_id, approver = v_manager where id = v_previous_approval_id;
  else
    -- New Submit
    insert into EAT_Approvals(request_id,approver) values (p_id, v_manager);
  end if;
  -- Sending Email to approval Manager:
  sendmail(lower(v_manager), null, c_app_name,
    'Request ('||to_char(p_id)||') - Action Required',c_msg_for_review_act||request_2_html(p_id)||buttons(p_id,v_manager)
  );
  -- notify replacement of the next approver if any:
  for r in (
  select replaced_by from EAT_Replacements
    where replaced_user = trim(upper(v_manager)) and
      replacement_from_utc < sysdate and
      replacement_to_utc > sysdate
  ) loop
    sendmail(lower(r.replaced_by), null, c_app_name,
      'Request ('||to_char(p_id)||') - Action Required',c_msg_for_review_act||request_2_html(p_id)||buttons(p_id,r.replaced_by)
    );
  end loop;
  -- Sending mail to Requester:
  sendmail(lower(v_employee), null, c_app_name,
    'Request ('||to_char(p_id)||') - Submission note',c_msg_submitted_note||request_2_html(p_id)
  );
 
  insert into audit_log values (v('APP_USER'),v('SESSION'),'Exceptional Approvals','UPDATE','MANAGER',systimestamp,c_application_id);
 
  commit;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end submit_request;
 
function link2request(p_id number) return varchar2 deterministic is
/** returns a link HTML tag to the Request.
2017.06.19 - 1.0 - András Tóth - create
2019.02.13 - 1.1 - András Tóth - adding the test URL also...
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'link2request';
  c_proc_version constant varchar2(5 char) := '1.1';
begin
  if p_id is not null then
    if c_Prod_WS_NAME = nvl(c_WS_NAME,'-1') then
      return '<a style="COLOR: #ff0000; TEXT-DECORATION: underline;" target="_blank" href="'|| APEX_UTIL.PREPARE_URL('https://apex.oraclecorp.com/pls/apex/f?p='||c_application_id||':2:::NO:RP,2:P2_OPEN_REQUEST_ID:'||p_id) ||'">'||p_id||'</a>';
    else
      return '<a style="COLOR: #ff0000; TEXT-DECORATION: underline;" target="_blank" href="'|| APEX_UTIL.PREPARE_URL('https://apex-stage.oraclecorp.com/pls/apex/f?p='||c_application_id||':2:::NO:RP,2:P2_OPEN_REQUEST_ID:'||p_id) ||'">'||p_id||'</a>';
    end if;
  else
    return null;
  end if;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end link2request;
 
function get_m_level(p_email varchar2) return number deterministic is
/** returns the Mx Level of the manager.
2017.06.19 - 1.0 - András Tóth - create
2020.03.17 - 1.1 - András Tóth - handle correct numbers.
2024.06.18 - 1.2 - Bhuvi Chauhan - Used PAAS in pcg.get_hr_job_level, so this need to be adjusted accordingly
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_m_level';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_level number;
  v_job_level varchar2(50 char);
begin
  v_job_level := pcg.get_hr_job_level(p_email);
  v_level := nvl(case when trim(substr(v_job_level,0,1)) = 'M' then to_number(trim(substr(v_job_level,2,1))) else 0 end, 0);
  --v_level := nvl(case when trim(substr(v_job_level,1,2)) = 'MG' then to_number(trim(substr(v_job_level,3,2))) else 0 end, 0);
  return v_level;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, 'p_email='||p_email||', v_job_level='||v_job_level||' - '|| case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  return 0;
end get_m_level;
 
procedure approve_request(p_id number, p_approver in varchar2 default v('APP_USER')) is
/** Approve a request
2017.06.19 - 1.0 - András Tóth - create
2019.01.29 - 1.1 - András Tóth - adding approver user as parameter.
2020.02.04 - 1.2 - András Tóth - approver can be a replacement...
2020.09.01 - 1.3 - András Tóth - adding extra logs; handling v_employee_payments_type_id might be null.
2021.07.05 - 1.4 - András Tóth - adding some more log text.
2025.02.25 - 1.5 - Rohit kumar - SR 136240 : Approve request if approval level >= c_max_spec_mgr_level
2025.11.05 - 1.6 - Rohit kumar - SR 158776 : 'KAREN.LIM@ORACLE.COM' added as an exception for M level approval , request will go to +1 Adrian too for final Approval
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'approve_request';
  c_proc_version constant varchar2(5 char) := '1.5';
  v_approve_record_id number;
  v_approver varchar2(256 char) := trim(upper(p_approver));
  v_original_approver varchar2(256 char);
  v_employee_payments_type_id number;
  v_employee_payments_type varchar2(4000);
  v_next_approver_manager varchar2(256 char);
  v_employee varchar2(256 char);
  v_country varchar2(300 char);
  v_category varchar2(300 char);
  v_m_level number;
  v_log_line varchar2(4000);
begin
  v_log_line := 0;
  wwv_flow_api.set_security_group_id;
  v_log_line := 1;
  -- security check:
  if p_id is null then raise pcg.invalid_input_value; end if;
  v_log_line := 2;
  if is_approvable(p_id,v_approver) = 'N' then raise pcg.not_authorized; end if;
  v_log_line := 3;
 
 bhu_logs(1,'v_m_level '||v_m_level||' c_max_mgr_level '||c_max_mgr_level,'clob1');
  -- getting basic request data
  select r.requester, coalesce(c.country||case when c.branch is not null then ' - '||c.branch end, c.sub_region, c.hub, c.region, c.company)
    , v as category_text,
    employee_payments_type_id
    into v_employee, v_country, v_category, v_employee_payments_type_id from EAT_Requests r, md_countries c, md_kv kv where r.id = p_id and c.id=r.country_id and kv.id = r.category_id ;
 
 bhu_logs(12,'v_m_level '||v_m_level||' c_max_mgr_level '||c_max_mgr_level,'clob12'); 
  v_log_line := 4;
  select id, approver into v_approve_record_id, v_original_approver from EAT_Approvals where request_id = p_id and approval_date is null;
  v_log_line := 5;
 
  bhu_logs(13,'v_m_level '||v_m_level||' c_max_mgr_level '||c_max_mgr_level,'clob13'); 
  v_m_level := get_m_level(v_original_approver);
  v_log_line := 6||' v_employee_payments_type_id='||to_char(v_employee_payments_type_id);
  select max(v) into v_employee_payments_type from md_kv where id = v_employee_payments_type_id;
  v_log_line := 7;
 
  -- set status approved
  update EAT_Approvals set
    approval_date = systimestamp,
    approver = v_approver,
    approver_level = v_m_level,
    approved_sign = 'Y'
  where id = v_approve_record_id;
  v_log_line := 8;
 bhu_logs(14,'v_m_level '||v_m_level||' c_max_mgr_level '||c_max_mgr_level,'clob14');   
 
-- mail requ from mariko
    if (v_category = 'Employees payment' and v_employee_payments_type = 'Legal Requirement') then
        if v_m_level <= c_max_spec_mgr_level then
       -- Notify Employee
		sendmail(lower(v_employee), null, c_app_name,
		'Request ('||to_char(p_id)||') - Approved', c_msg_approved_note||request_2_html(p_id)
		        	);
        end if;
    else
  -- SR 69407, Notify employee each time the request is approved
        if v_m_level <= c_max_mgr_level then
       -- Notify Employee
		    sendmail(lower(v_employee), null, c_app_name,
		    'Request ('||to_char(p_id)||') - Approved', c_msg_approved_note||request_2_html(p_id)
		        	);  
-- SR #110110 and SR #108010
            if (v_m_level = c_max_mgr_level and v_category = 'ADP Add On') then
            bhu_logs(2,'v_m_level '||v_m_level||' c_max_mgr_level '||c_max_mgr_level,'clob2');
			    sendmail(lower(c_ADP_Global_Addon_email), null, c_app_name,
			    'Request ('||to_char(p_id)||') - Approved', c_msg_approved_note||request_2_html(p_id)
			    );
            end if;  

        end if;

    end if;
 
 -- SR 60769 changes in if conditions as per the expectation stated by ciprian.
 -- SR 136240 for category  'Employees payment' and v_employee_payments_type = 'Legal Requirement'  , if v_m_level >= c_max_spec_mgr_level then approved .
   -- set next approver, if manager was not M6
  	if (v_m_level < c_max_mgr_level or v_m_level <= c_max_spec_mgr_level or upper(v_original_approver) = 'KAREN.LIM@ORACLE.COM')  --- adde karen.lim as exception sr - 158776
	then
		if (v_category = 'Employees payment' and v_employee_payments_type = 'Legal Requirement' and v_m_level >= c_max_spec_mgr_level) -- added this and condition for SR 80723  -- update v_m_level = c_max_spec_mgr_level to v_m_level >= c_max_spec_mgr_level for SR 136240
		then
			v_log_line := 9;
			-- Notify Employee
			sendmail(lower(v_employee), null, c_app_name,
			'Request ('||to_char(p_id)||') - Approved', c_msg_approved_note||request_2_html(p_id)
			);
			v_log_line := 10;
		
			-- notify approver manager
			sendmail(lower(p_approver), null, c_app_name,
			'Request ('||to_char(p_id)||') - Approved', c_msg_approved_note
			);
			v_log_line := 11;
		
			-- notify original manager:
			if lower(p_approver) != lower(v_original_approver) then
			sendmail(lower(v_original_approver), null, c_app_name,
				'Request ('||to_char(p_id)||') - Approved', c_msg_approved_note
			);
			end if;
			v_log_line := 12;
		
        elsif (v_category = 'Employees payment' and v_employee_payments_type = 'Legal Requirement' and v_m_level < c_max_spec_mgr_level) -- added this for SR 80723
        then

            v_next_approver_manager := get_manager_email(v_original_approver);
            insert into EAT_Approvals(request_id,approver) values (p_id, v_next_approver_manager);
            -- notify next approver
			    sendmail(lower(v_next_approver_manager), null, c_app_name,
			    'Request ('||to_char(p_id)||') - Action Required', c_msg_for_review_act||request_2_html(p_id)||buttons(p_id,v_next_approver_manager));
            -- notify replacement of the next approver if any:
			    for r in (
			    select replaced_by from EAT_Replacements
			    where replaced_user = trim(upper(v_next_approver_manager)) and
				    replacement_from_utc < sysdate and
				    replacement_to_utc > sysdate
			        )loop
			    sendmail(lower(r.replaced_by), null, c_app_name,
				'Request ('||to_char(p_id)||') - Action Required', c_msg_for_review_act||request_2_html(p_id)||buttons(p_id,r.replaced_by)
			    );
			    end loop;
		else
         bhu_logs(15,'v_m_level '||v_m_level||' c_max_mgr_level '||c_max_mgr_level,'clob15'); 
			    v_log_line := 14; 
			    v_next_approver_manager := get_manager_email(v_original_approver);
                v_log_line := 15;
			    insert into EAT_Approvals(request_id,approver) 
                values (p_id, v_next_approver_manager);
                v_log_line := 16;
                bhu_logs(3,'v_m_level '||v_m_level||' c_max_mgr_level '||c_max_mgr_level,'clob3');
			    -- notify next approver
			    sendmail(lower(v_next_approver_manager), null, c_app_name,
			    'Request ('||to_char(p_id)||') - Action Required', c_msg_for_review_act||request_2_html(p_id)||buttons(p_id,v_next_approver_manager));
			    v_log_line := 18;
			    -- notify replacement of the next approver if any:
			    for r in (
			    select replaced_by from EAT_Replacements
			    where replaced_user = trim(upper(v_next_approver_manager)) and
			    replacement_from_utc < sysdate and
			    replacement_to_utc > sysdate
			    )loop
			    sendmail(lower(r.replaced_by), null, c_app_name,
				'Request ('||to_char(p_id)||') - Action Required', c_msg_for_review_act||request_2_html(p_id)||buttons(p_id,r.replaced_by)
			    );
			    end loop;
                v_log_line := 19;
		end if;
	end if;
  v_log_line := 20;
  insert into audit_log values (nvl(v('APP_USER'),v_approver),v('SESSION'),'Exceptional Approvals','UPDATE','MANAGER',systimestamp,c_application_id);
  v_log_line := 21;
  commit;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version,'ID='||to_char(p_id)||', '||p_approver||' - '||case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end ||' - l'||v_log_line, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end approve_request;
 
procedure reject_request(p_id number, p_approver in varchar2 default v('APP_USER')) is
/** Rejects a request
2017.06.19 - 1.0 - András Tóth - create
2019.01.29 - 1.1 - András Tóth - adding approver.
2020.02.04 - 1.2 - András Tóth - approver can be a replacement...
2021.07.05 - 1.3 - András Tóth - adding extra logs
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'reject_request';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_approve_record_id number;
  v_comments varchar2(4000 char);
  v_requester varchar2(256 char);
  v_country varchar2(300 char);
  v_rejecter varchar2(256 char) := trim(upper(p_approver));
  v_original_rejecter varchar2(256 char);
  v_m_level number;
begin
  wwv_flow_api.set_security_group_id;
  -- security check:
  if p_id is null then raise pcg.invalid_input_value; end if;
  if is_approvable(p_id,v_rejecter) = 'N' then raise pcg.not_authorized; end if;
 
  -- Get Basic Data on Request:
  select r.comments, r.requester, coalesce(c.country||case when c.branch is not null then ' - '||c.branch end, c.sub_region, c.hub, c.region, c.company)
  into v_comments, v_requester, v_country
  from EAT_Requests r, md_countries c where r.id = p_id and c.id=r.country_id;
 
  select id, approver into v_approve_record_id, v_original_rejecter from EAT_Approvals where request_id = p_id and approval_date is null;
  v_m_level := get_m_level(v_original_rejecter);
 
  -- set status rejected:
  update EAT_Approvals set
    approval_date = systimestamp,
    approver = v_rejecter,
    approver_level = v_m_level,
    approved_sign = 'N'
  where id = v_approve_record_id;
 
  -- notify rejector
  sendmail(lower(v_rejecter), null, c_app_name,
      'Request ('||to_char(p_id)||') - Rejected', replace(c_msg_rejected_note,'See comments bellow.',null)
    );
 
  -- notify original rejecter
  if lower(v_original_rejecter) != lower(v_rejecter) then
    sendmail(lower(v_original_rejecter), null, c_app_name,
        'Request ('||to_char(p_id)||') - Rejected', replace(c_msg_rejected_note,'See comments bellow.',null)
      );
  end if;
 
  -- Notify Requester:
  sendmail(lower(v_requester), null, c_app_name,
      'Request ('||to_char(p_id)||') - Rejected', c_msg_rejected_note||request_2_html(p_id)
    );
  insert into audit_log values (nvl(v('APP_USER'),v_rejecter),v('SESSION'),'Exceptional Approvals','UPDATE','MANAGER',systimestamp,c_application_id);
  commit;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, 'ID='||to_char(p_id)||', '||p_approver||' - '||case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end reject_request;
 
function is_editable(p_request_id number, p_requester in varchar2 default v('APP_USER')) return char is
/** Returns Y/N if the request is editable by the current user
2017.06.21 - 1.0 - András Tóth - create
2019.02.11 - 1.1 - András Tóth - p_requester addon
2020.09.01 - 1.2 - András Tóth - updating with analyst access
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_editable';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_approval_happend number;
begin
  if has_Page_Access(trim(upper(p_requester))) = 'N' then return 'N'; end if;
  -- when new(-id or no approvals) or approvable
  select nvl(max(request_id),0) into v_approval_happend from eat_approvals where request_id = p_request_id;
  return case when p_request_id < 0 or v_approval_happend = 0 or is_approvable(p_request_id, trim(upper(p_requester))) = 'Y'
              then 'Y' else 'N' end;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_editable;
 
function is_approvable(p_request_id number, p_approver in varchar2 default v('APP_USER')) return char is
/** Returns Y/N if the request is approvable/rejectable by the current user
2017.06.21 - 1.0 - András Tóth - create
2019.02.11 - 1.1 - András Tóth - p_apptover addon for better testing
2020.02.04 - 1.2 - András Tóth - extending the ability to approve for replacements.
2020.09.01 - 1.3 - András Tóth - updating with Analyst access
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_approvable';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_tmp number;
begin
  if is_Manager(trim(upper(p_approver))) = 'N' then return 'N'; end if;
  -- Approvable, only if selected as a next level approver.
  select nvl(max(a.request_id),0) into v_tmp from EAT_Approvals a
  where
    a.request_id = p_request_id and
    a.APPROVER in (
      select trim(upper(p_approver)) from dual union all
      select replaced_user from EAT_Replacements
        where replaced_by = trim(upper(p_approver)) and
          replacement_from_utc < sysdate and
          replacement_to_utc > sysdate
    ) and
    APPROVED_SIGN is null;
 
  return case when v_tmp > 0 then 'Y' else 'N' end;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_approvable;
 
function is_escalatable(p_request_id number, p_requester in varchar2 default v('APP_USER')) return char is
/** Returns Y/N if the user is eligable to escalate the given request
2017.06.21 - 1.0 - András Tóth - create
2020.02.04 - 1.1 - András Tóth - escalation is not alowed when manager is M6. Adding requestor as parameter.
2020.09.01 - 1.2 - András Tóth - updating with Analyst access
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_escalatable';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_tmp number;
  v_mgr_email_addr varchar2(256 char);
begin
  if has_Page_Access = 'N' then return 'N'; end if;
  -- when it is waiting for someone's approval and the only the requestor can escalate.
  select nvl(max(r.id),0), max(r.approver) into v_tmp, v_mgr_email_addr from EAT_Requests_V r where r.id = p_request_id and r.approved_sign is null and r.requester = p_requester;
 
  if
    nvl(get_m_level(v_mgr_email_addr),0) > c_max_mgr_level - 1
    then return 'N';
  elsif
    v_tmp > 0
    then return 'Y';
  else
    return 'N';
  end if;
 
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_escalatable;
 
procedure escalate_request(p_id number, p_requester in varchar2 default v('APP_USER')) is
/** Escalates a request
2017.06.21 - 1.0 - András Tóth - create
2020.02.04 - 1.1 - András Tóth - adding Request ID into Subject, notifying the replacement also; adding requester as a parameter
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'escalate_request';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_next_approver_manager varchar2(256 char);
  v_approver varchar2(256 char);
begin
  -- security check:
  if p_id is null then raise pcg.invalid_input_value; end if;
  if is_escalatable(p_id, p_requester) = 'N' then raise pcg.not_authorized; end if;
 
  -- getting general info
  select a.approver into v_approver from EAT_Approvals a where a.request_id = p_id and approved_sign is null;
  v_next_approver_manager := get_manager_email(v_approver);
 
  -- Setting the name of the approver to the next level approver.
  update EAT_Approvals a set a.approver = v_next_approver_manager
  where a.request_id = p_id and approved_sign is null;
 
  -- notifying the original approver:
  sendmail(lower(v_approver), null, c_app_name,
    'Request ('||to_char(p_id)||') - Escalation note',c_msg_escalate_above_note
  );
 
  -- notifying the requestor:
  sendmail(lower(p_requester), null, c_app_name,
    'Request ('||to_char(p_id)||') - Escalation note',c_msg_escalate_note
  );
 
  -- Notifying next level approver:
  sendmail(lower(v_next_approver_manager), null, c_app_name,
    'Request ('||to_char(p_id)||') - Action Required', c_msg_for_escalate_review_act||request_2_html(p_id)||buttons(p_id,v_next_approver_manager)
  );
  -- Notifiing the replacement
  for r in (
  select replaced_by from EAT_Replacements
    where replaced_user = trim(upper(v_next_approver_manager)) and
      replacement_from_utc < sysdate and
      replacement_to_utc > sysdate
  ) loop
    sendmail(lower(r.replaced_by), null, c_app_name,
      'Request ('||to_char(p_id)||') - Action Required', c_msg_for_escalate_review_act||request_2_html(p_id)||buttons(p_id,r.replaced_by)
    );
  end loop;
 
  insert into audit_log values (v('APP_USER'),v('SESSION'),'Exceptional Approvals','UPDATE','MANAGER',systimestamp,c_application_id);
  commit;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end escalate_request;
 
function get_requester_email(p_id number) return varchar2 deterministic is
/** Returns the Requester of a given Request
2017.06.21 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_requester_email';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_out varchar2(256 char);
begin
  select requester into v_out from EAT_Requests where id = p_id;
  return v_out;
exception
when no_data_found then return null;
when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_requester_email;
 
function has_Page_Access(p_user in varchar2 default v('APP_USER')) return char deterministic is
/** Returns Y/N if the user is eligable to access the pages of the application. It checks OIM roles.
2017.06.21 - 1.0 - András Tóth - create
2017.07.14 - 1.1 - András Tóth - adding Operations, M&A
2019.02.11 - 1.2 - András Tóth - adding p_user
2020.09.01 - 1.3 - András Tóth - renaming, adding Analyst
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'has_Page_Access';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_user varchar2(256 char);
begin
select nvl(max(USERNAME),' ') into v_user from MD_USERS_V where USERNAME = trim(upper(p_user)) and (ROLE_NAME like '% ANALYST' or ROLE_NAME like '% APPROVER' or ROLE_NAME = 'ADMINISTRATOR' or ROLE_NAME = 'DIRECTOR' or role_name like 'OPERATIONS_%' or role_name ='M&A_MANAGER' or role_name ='M&A_ANALYST');
return case when v_user = trim(upper(p_user)) then 'Y' else 'N' end;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end has_Page_Access;
 
procedure test_Page_Access(p_user in varchar2 default v('APP_USER')) is
/* Raises error, if the user has no access to the pages of the application */
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_Page_Access';
  c_proc_version constant varchar2(5 char) := '1.3';
begin
  if has_Page_Access(p_user) = 'N' then raise pcg.not_authorized; end if;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_Page_Access;
 
function get_role(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** Returns the role of the person
2017.07.14 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_role';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_role_name varchar2(256 char);
begin
  select max(role_name) into v_role_name from MD_USERS_V where username = upper(p_email);
  return trim(v_role_name);
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_role;
 
function is_Manager(p_user in varchar2 default v('APP_USER')) return char deterministic is
/** Returns Y/N if the user is manager. It checks OIM roles.
2020.09.01 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_Manager';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_user varchar2(4000);
begin
  select nvl(max(USERNAME),' ') into v_user from MD_USERS_V where USERNAME = trim(upper(p_user)) and (ROLE_NAME like '% APPROVER' or ROLE_NAME = 'ADMINISTRATOR' or ROLE_NAME = 'DIRECTOR' or role_name like 'OPERATIONS_%' or role_name ='M&A_MANAGER');
  return case when v_user = trim(upper(p_user)) then 'Y' else 'N' end;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_Manager;
 
procedure test_Manager(p_user in varchar2 default v('APP_USER')) is
/** raises error if the user is not a manager. It checks OIM roles.
2020.09.01 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_Manager';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  if is_Manager(p_user) = 'N' then raise pcg.not_authorized; end if;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_Manager;
 
function get_region(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** Returns the region of the person
2017.07.14 - 1.0 - András Tóth - create
2020.09.01 - 1.1 - András Tóth - adding Analyst too.
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_region';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_role_name varchar2(256 char);
begin
  v_role_name := get_role(p_email);
  if v_role_name is null then return null; end if;
  if v_role_name like '%APPROVER' then return trim(replace(v_role_name,' APPROVER',null)); end if;
  if v_role_name like '%PAYROLL ANALYST' then return trim(replace(v_role_name,' PAYROLL ANALYST',null)); end if;
  if v_role_name like 'OPERATIONS%' then return 'GLOBAL'; end if;
  if v_role_name = 'DIRECTOR' then return 'GLOBAL'; end if;
  if v_role_name = 'ADMINISTRATOR' then return 'GLOBAL'; end if;
  if v_role_name = 'M&A_MANAGER' then return 'GLOBAL'; end if;
  if v_role_name = 'M&A_ANALYST' then return 'GLOBAL'; end if;
  return null;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_region;
 
procedure sendmail(p_to varchar2, p_app_id varchar2, p_app_name varchar2, p_title varchar2, p_text varchar2) is
/** Send email notifications
  2019.02.11 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'sendmail';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  if nvl(c_WS_NAME,'-1') = c_Prod_WS_NAME then
    pcg.sendmail(p_to, p_app_id, p_app_name, p_title, p_text);
  else
    if trim(lower(p_to)) in ('marek.szwarczewski@oracle.com') then
      pcg.sendmail('marek.szwarczewski@oracle.com', p_app_id, '[TEST] '||p_app_name, p_title, '<p>TO:'||p_to||'</p>'||p_text);
    else
      pcg.sendmail('marek.szwarczewski@oracle.com', p_app_id, '[TEST] '||p_app_name, p_title, '<p>TO:'||p_to||'</p>'||p_text);
    end if;
  end if;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end sendmail;
 
function request_2_html(p_request_id in number) return varchar2 is
/** Return information details on the request in HTML.
  2019.02.12 - 1.0 - András Tóth - create
  2019.02.28 - 1.1 - András Tóth - styleing for Outlook.
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'request_2_html';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2 (32767 char);
  v_REQUESTER_NAME varchar2 (4000 char);
  v_REQUEST_DATE varchar2 (4000 char);
  v_APPROVAL_CHAIN varchar2 (4000 char);
  v_Reviewer_name varchar2 (4000 char);
  v_ATTACHMENTS_COUNT varchar2 (4000 char);
  v_STATUS varchar2 (4000 char);
  v_Review_date varchar2 (4000 char);
  v_CATEGORY varchar2 (4000 char);
  v_COUNTRY_NAME_SHOW varchar2 (4000 char);
  v_REGION varchar2 (4000 char);
  v_HUB varchar2 (4000 char);
  v_HC varchar2 (4000 char);
  v_COMMENTS varchar2 (4000 char);
  v_BUSINESS_JUSTIFICATION varchar2 (4000 char);
  v_APPROVAL_DUE_DATE varchar2 (4000 char);
  v_AMOUNT varchar2 (4000 char);
  v_AMOUNT_TYPE varchar2 (4000 char);
  v_DOCUMENTID varchar2 (4000 char);
  V_EMPLOYEE_PAYMENTS_TYPE varchar2 (4000 char);
  v_id_with_link varchar2 (4000 char);
  c_tr constant varchar2(4000 char) := '<tr>';
  c_td constant varchar2(4000 char) := '<td style="border-bottom: 1px solid #dddddd;">';
begin
  select
    REQUESTER_NAME,
    to_char(REQUEST_DATE,'YYYY-MM-DD') as REQUEST_DATE,
    APPROVAL_CHAIN,
    APPROVER_NAME as Reviewer_name,
    ATTACHMENTS_COUNT,
    STATUS,
    to_char(APPROVAL_DATE,'YYYY-MM-DD') as Review_date,
    CATEGORY,
    COUNTRY_NAME_SHOW,
    REGION,
    HUB,
    HC,
    COMMENTS,
    BUSINESS_JUSTIFICATION,
    to_char(APPROVAL_DUE_DATE,'YYYY-MM-DD') as APPROVAL_DUE_DATE,
    AMOUNT,
    AMOUNT_TYPE,
    DOCUMENTID,
    EMPLOYEE_PAYMENTS_TYPE
  into
    v_REQUESTER_NAME,
    v_REQUEST_DATE,
    v_APPROVAL_CHAIN,
    v_Reviewer_name,
    v_ATTACHMENTS_COUNT,
    v_STATUS,
    v_Review_date,
    v_CATEGORY,
    v_COUNTRY_NAME_SHOW,
    v_REGION,
    v_HUB,
    v_HC,
    v_COMMENTS,
    v_BUSINESS_JUSTIFICATION,
    v_APPROVAL_DUE_DATE,
    v_AMOUNT,
    v_AMOUNT_TYPE,
    v_DOCUMENTID,
    V_EMPLOYEE_PAYMENTS_TYPE
  from eat_requests_v
  where id = p_request_id;
 
  v_id_with_link:= link2request(p_request_id);
 
  v_ret := '<br /><div style="padding: 10px;">'||'<i>Details of request</i> <b>#'||v_id_with_link||'</b>:'||
    '<table style="border-collapse: collapse; border: 1px solid black; text-align: left; vertical-align: middle; padding: 5px; background-color: #f5f5f5;">'||
      c_tr||c_td||'Requester Name</td>'||c_td||v_REQUESTER_NAME||'</td></tr>'||
      c_tr||c_td||'Request Date</td>'||c_td||v_REQUEST_DATE||'</td></tr>'||
      c_tr||c_td||'Status</td>'||c_td||v_STATUS||'</td></tr>'||
      c_tr||c_td||'Region</td>'||c_td||v_REGION||'</td></tr>'||
      c_tr||c_td||'Hub</td>'||c_td||v_HUB||'</td></tr>'||
      c_tr||c_td||'Country</td>'||c_td||v_COUNTRY_NAME_SHOW||'</td></tr>'||
      c_tr||c_td||'Category</td>'||c_td||v_CATEGORY||'</td></tr>'||
      c_tr||c_td||'Headcount</td>'||c_td||v_HC||'</td></tr>'||
      c_tr||c_td||'Doc ID (LON)</td>'||c_td||v_DOCUMENTID||'</td></tr>'||
      c_tr||c_td||'Amount</td>'||c_td||v_AMOUNT||' '||
      ' '||v_AMOUNT_TYPE||'</td></tr>'||
      c_tr||c_td||'Approval Due Date</td>'||c_td||v_APPROVAL_DUE_DATE||'</td></tr>'||
      c_tr||c_td||'Employee&nbsp;Payments&nbsp;Type&nbsp;</td>'||c_td||V_EMPLOYEE_PAYMENTS_TYPE||'</td></tr>'||
      c_tr||c_td||'Business Justification</td>'||c_td||v_BUSINESS_JUSTIFICATION||'</td></tr>'||
      c_tr||c_td||'Comments</td>'||c_td||v_COMMENTS||'</td></tr>'||
      c_tr||c_td||'# of Attachments</td>'||c_td||nvl(v_ATTACHMENTS_COUNT,'0')||'</td></tr>'||
      c_tr||c_td||'Approval chain</td>'||c_td||v_APPROVAL_CHAIN||'</td></tr>'||
      c_tr||c_td||'Reviewed by</td>'||c_td||case when v_Review_date is not null then v_Reviewer_name end||'</td></tr>'||
      '<tr>'||c_td||'Reviewed on</td>'||c_td||v_Review_date||'</td></tr>'||
    '</table>'||
  '</div>';
 
  return v_ret;
exception when others then
  -- logging to Standard PCG_ERRORS table
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end request_2_html;
 
function buttons(p_request_id in number, p_email in varchar2) return varchar2 is
/** Returns HTML Buttons source code
  2019.02.12 - 1.0 - András Tóth - create
  2020.02.04 - 1.1 - András Tóth - little cosmetics
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'buttons';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2 (32000 char);
begin
  v_ret := '<div align="center" style="text-align: center;"><table align="center" style="text-align: center;">'||
    '<tr>'||
      '<td>&nbsp;</td>'||
      '<td style="background-color: ForestGreen; padding: 15px;">'||
      '<a style="color: white;" href="mailto:payroll-apex_ww@oracle.com?Subject=EAT_A_'||to_char(p_request_id)
      ||'&body=NN'||security_number(p_request_id, p_email)||'NN'||
      '">Approve</a></td>'||
      '<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>'||
      '<td style="background-color: FireBrick; padding: 15px;">'||
      '<a style="color: white;" href="mailto:payroll-apex_ww@oracle.com?Subject=EAT_R_'||to_char(p_request_id)
      ||'&body=NN'||security_number(p_request_id, p_email)||'NN'||'%0A'||
      '_Type_the_reason_for_rejection_bellow_'||'%0A%0A'||
      '_Type_the_reason_for_rejection_above_'||
      '">Reject</a></td>'||
      '<td>&nbsp;</td>'||
    '</tr>'||
  '</table></div>';
  return v_ret;
exception when others then
-- logging to Standard PCG_ERRORS table
pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end buttons;
 
procedure read_mails is
/** Returns HTML Buttons source code
  2019.02.12 - 1.0 - András Tóth - create
  2019.02.28 - 1.1 - András Tóth - trimming the input reason text...
  2020.05.15 - 1.2 - András Tóth - server access method change
  2021.06.30 - 1.3 - András Tóth - connecting to new email server
  2022.04.08 - 1.4 - András Tóth - enhance logging
  2026.10.07 - 1.5 - Pragya Kapoor -If duplicate emails are triggered by the same person for the same request, the subsequent emails remain unread. Updated the code to mark those duplicate emails as read.
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'read_mails';
  c_proc_version constant varchar2(5 char) := '1.5';
  v_emails_response CLOB;
  v_marking_response CLOB;
  v_cnt number;
  v_sender varchar2(4000 char);
  v_subject varchar2(4000 char);
  v_msg_txt varchar2(4000 char);
  v_reason varchar2(4000 char);
  v_request_id number;
  v_comments varchar2(4000 char);
  v_security_number varchar2(4000 char);
  v_msg_id varchar2(4000 char);
  v_ln clob;
  v_already_actioned NUMBER;
begin
  -- Read Logs:    select * from pcg_errors where 'eat_pkg.read_mails' = ERROR_SENDER order by 1 desc;
  v_ln := '1';
  wwv_flow_api.set_security_group_id;
 
  v_ln := '2';
  v_emails_response := apex_web_service.make_rest_request
  (
     p_proxy_override       => 'appoci-proxy01-vip.oraclevcn.com:80',
     p_url                  => replace('https://graph.microsoft.com/v1.0/users/'||c_user||'/messages?$count=true&$select=subject,from,isRead,id,bodyPreview&$filter=((receivedDateTime ge 2021-06-22T00:00:00Z) and (isRead eq false) and (startswith(subject,''EAT'')))&$orderby=receivedDateTime asc', ' ', c_space),
     p_http_method          => 'GET',
     p_token_url            => 'https://login.microsoftonline.com/'||c_tenant||'/oauth2/v2.0/token',
     p_credential_static_id => 'payroll_exchange'
     );
  v_ln := '3 - '|| v_emails_response;
  v_cnt := json_value (v_emails_response,'$."@odata.count"' returning number);
  v_ln := '4';
  pcg.log(c_proc_name, c_version, c_proc_version, v_emails_response, null, 'D');
  v_ln := '5';
 
  for i in 0..v_cnt-1 loop
    begin
      v_ln := '6 - '|| v_emails_response;
      v_msg_id := json_value (v_emails_response,'$.value['||to_char(i)||'].id' returning varchar2);
      v_ln := '7 - '|| v_emails_response;
      v_subject := json_value (v_emails_response,'$.value['||to_char(i)||'].subject' returning varchar2);
      v_ln := '8 - '|| v_emails_response;
      v_msg_txt := json_value (v_emails_response,'$.value['||to_char(i)||'].bodyPreview' returning varchar2);
      v_ln := '9 - '|| v_emails_response;
      v_sender :=  trim(upper(json_value (v_emails_response,'$.value['||to_char(i)||'].from.emailAddress.address' returning varchar2)));
 
      v_ln := '9 - '||v_subject;
      v_request_id := to_number(replace(replace(v_subject,'EAT_A_'),'EAT_R_'));
      v_ln := '10 - '||v_msg_txt;
      v_reason := trim(regexp_replace(replace(replace(regexp_substr(v_msg_txt, 'bellow_.*_Type', 1,1, 'cmn'),'bellow_'),'_Type'),'\s+',' ',1,0,'im'));
      v_ln := '11 - '||v_msg_txt;
      v_security_number := trim(replace(regexp_substr(v_msg_txt, 'NN.*NN', 1,1, 'cmn'),'N'));
 
      v_ln := '12';
      if v_security_number = security_number(v_request_id,v_sender) then
        v_ln := '13';
		
		if is_approvable(v_request_id, v_sender) = 'Y' then
			if substr(v_subject,1,6) = 'EAT_A_' then
			v_ln := '14 - approve_request('||to_char(v_request_id)||', '||v_sender||')';
			approve_request(v_request_id,v_sender);
			v_ln := '15';
			elsif substr(v_subject,1,6) = 'EAT_R_' then
			v_ln := '16';
			if v_reason is not null then
				v_ln := '17';
				select comments into v_comments from EAT_Requests where id = v_request_id;
				v_ln := '18';
				v_comments :=
				substr(v_comments || '<span style="font-weight: normal;"><b>' ||pcg.email2name(v_sender) || ' (</b><i style="color: #808080;font-weight: lighter;"><small>'||pcg.to_iso8601_datetime(systimestamp)||'</small></i><b>): </b><br><span style="font-weight: lighter;">'|| v_reason ||'</span></span>'||CHR(10)||CHR(13) ,1,4000);
				v_ln := '19';
				update EAT_Requests set comments = v_comments where id = v_request_id;
				v_ln := '20';
				commit;
			end if;
			v_ln := '21 - reject_request('||to_char(v_request_id)||', '||v_sender||')';
			reject_request(v_request_id,v_sender);
			v_ln := '22';
			end if;
			v_ln := '23';
		else
			-- Only treat it as a duplicate if this sender already actioned it
			select count(*) into v_already_actioned
			from EAT_Approvals
			where request_id = v_request_id
			and upper(approver) = upper(v_sender)
			and approval_date is not null and approved_sign in ('Y', 'N');
		
			if v_already_actioned > 0 then
				pcg.log(c_proc_name, c_version, c_proc_version, 'Duplicate email ignored and marked as read. Request ID: ' || v_request_id || ', Sender: ' || v_sender, null, 'D');
			 else
				pcg.log(c_proc_name, c_version, c_proc_version, 'You are not authorized to access this object. Request ID: ' || v_request_id || ', Sender: ' || v_sender, null, 'E');
				raise pcg.not_authorized;
			end if;
		end if;
      end if;
 
      v_ln := '24';
      apex_web_service.g_request_headers(1).name := 'Content-Type';
      apex_web_service.g_request_headers(1).value := 'application/json; charset=utf-8';
      v_ln := '25 - msg: '||v_msg_id||' request_id:'||to_char(v_request_id)||' sender:'||v_sender||')';
      v_marking_response := apex_web_service.make_rest_request
          (
           p_proxy_override       => 'appoci-proxy01-vip.oraclevcn.com:80',
           p_url                  => 'https://graph.microsoft.com/v1.0/users/'||c_user||'/messages/'||v_msg_id,
           p_http_method          => 'PATCH',
           p_token_url            => 'https://login.microsoftonline.com/'||c_tenant||'/oauth2/v2.0/token',
           p_credential_static_id => 'payroll_exchange',
           p_body                 => '{"isRead":"true"}'
           );
       v_ln := '26';
       pcg.log(c_proc_name, c_version, c_proc_version, v_marking_response, null, 'D');
       v_ln := '27';
    exception when others then
      pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE, 'W');
    end;
  end loop;
exception when others then
-- logging to Standard PCG_ERRORS table
pcg.log(c_proc_name, c_version, c_proc_version, v_ln || ' - '|| case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE, 'E');
if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end read_mails;
  
function security_number(p_request_id in number, p_email in varchar2) return varchar2 deterministic is
/** Calculates a number out of input data
  2019.02.12 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'security_number';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret varchar2(4000 char);
begin
  -- TODO: instead of sending a HASH, we could generate, save a random number and use that for checking...
  select to_char(ORA_HASH( trim(upper(p_email))||to_char(p_request_id) ) + length(p_email) * 83)
    into v_ret from dual;
  return v_ret;
exception when others then
-- logging to Standard PCG_ERRORS table
pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end security_number;
 
begin
  wwv_flow_api.set_security_group_id;
  c_WS_NAME := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
  c_application_id := v('APP_ID');
  if trim(c_application_id) is null then
    c_application_id := case when pcg.is_prod_env='Y' then c_prod_app_id else c_test_app_id end;
  end if;
  if trim(c_WS_NAME) is null then
    c_WS_NAME := case when pcg.is_prod_env='Y' then c_Prod_WS_NAME else c_Test_WS_NAME end;
  end if;
end EAT_pkg;
/