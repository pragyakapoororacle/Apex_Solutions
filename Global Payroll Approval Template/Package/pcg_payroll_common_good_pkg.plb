create or replace package body PCG_Payroll_Common_Good_pkg as
-- TODO: Please, update the change log and version number after every modification.
/** Oracle Global Payroll; Payroll common untilities to excelerate implementation and testing speed.
Created: 2017.03.14
Developer: andras.a.toth@oracle.com
Modifications:
2017.03.14 - 1.0 - András Tóth - create package
2017.03.17 - 1.1 - András Tóth - adding rowid to history table
2017.03.31 - 1.2 - András Tóth - adding list to table conversion function, exceptions.
2017.04.05 - 1.3 - András Tóth - sendmail addon.
2017.04.07 - 1.4 - András Tóth - history creation: data copiing force meta data filling.
2017.04.21 - 1.5 - András Tóth - sendmail corrections; other small enhancments. Adding session to the history tables
2017.05.22 - 1.6 - András Tóth - Key-Value Store subsystem addon. Adding general roles.
2017.08.09 - 1.7 - András Tóth - adding string_2_list, custom_auth, get_manager, has_region, test_region, get_region, get_role, get_org, get_title,
                                 get_emp_type, get_telephon, get_location, get_timezone functions. updateing email2name with LDAP.
2017.08.15 - 1.8 - András Tóth - Caching LDAP queries for email2name, get_manager(PCG_TMP_CACHE); common named LOV handling functions (MD_LOV*);
                                 adding 2 new lines before subroutines; Adding the Tree Handling utilities. Adding deleted_sign to MD_COUNTRIES,
                                 adding HeadCount tables and functions.  Increase varchar2 limits (4000 to 32767)
2017.09.06 - 1.9 - András Tóth - adding get_tree_leaf_name. Correcting separator for tree_leaf_2_path. Adding md_users_v other_roles field.
2017.12.06 - 2.0 - András Tóth - string_2_list error when input contains space corrected.
2018.01.22 - 2.1 - András Tóth - has_role corrected; HR connection, cache for get_location, get_timezone; lower case for hr and ldap search; removing "pcg.". The c_pkg_name||'.'||c_proc_name correction
2018.03.29 - 2.2 - András Tóth - cache_put_s deletes previous value when called automatically now, cache_forget is not necessary any more; type changed: varchar to varchar2
2018.04.19 - 2.3 - András Tóth - get_manager --> returns more than one rows...
2018.04.26 - 2.4 - András Tóth - adding log level optional parameter to the log procedure; adding audit_log procedure. Adding debug information to sendmail, sso_2_employee_number and get_manager procedures. Extra log to cache_put_s - TODO: this should be turned off later. 27 - adding   wwv_flow_api.set_security_group_id to the full procedure call
2018.05.02 - 2.5 - András Tóth - removing some extra logs; adding get_country_region, get_country_hub, get_country_subregion functions.
2018.05.22 - 2.6 - András Tóth - migration function for country codes. Fiscal Year function. Country names C version. Pragmas restrict references.
2018.06.13 - 2.7 - András Tóth - small corrections in get_country_* to return null if not found. Finishing app_url* functions. handle null input in id_string_2_id_list, string_2_list. p_options for app_url_a; updating LOG procedure with better central handling of logs.
2018.07.10 - 2.8 - András Tóth - Optimizations for MD_COUNTRIES and MD_USERS_V
2018.07.23 - 2.9 - András Tóth - update create_history_for_table with inmemory option; GCWAU instead of GCWAD
2018.08.02 - 3.0 - András Tóth - adding a daily job - checking the storage size; c_pkg_name replacing with $$PLSQL_UNIT.
2018.09.07 - 3.1 - András Tóth - adding hire-date; tree duplicatior functions, extra log for tree_leaf_create function.
2019.02.07 - 3.2 - András Tóth - adding get_hr_manager;
2019.02.20 - 3.3 - András Tóth - adding get_hr_job; remove trim() and some lower() form HR Secure View email address access
2019.02.26 - 3.4 - András Tóth - new mail template; update is_prod_env() with schema checking.
2019.03.20 - 3.5 - András Tóth - update mail template (case when app_id is null).
2019.03.28 - 3.6 - András Tóth - is_prod_env log update; get_cost_center, create_auto_id_for_table updates.
2019.04.01 - 3.7 - András Tóth - LDAP script for get_manager updated from apex mailing list advise...
2019.04.03 - 3.8 - András Tóth - update HR Secure View for optimizations... employee_number_2_SSO - update with business_group_id
2019.04.22 - 3.9 - András Tóth - LDAP update for get_manager...
2019.05.08 - 4.0 - András Tóth - updating get_manager again...
2019.05.27 - 4.1 - András Tóth - adding country_id generation functions
2019.06.26 - 4.2 - András Tóth - further country calling functions
2019.07.02 - 4.3 - András Tóth - updating email with one attachment capability; adding vcalendar blob file generation function; new: get_all_directs. increase PCG_TMP_CACHE varchar size. PCG_Errors - clob to varchar2. create_history_for_table - adding APP_ID too.
2019.08.08 - 4.4 - András Tóth - adding get_country_company.
2019.08.16 - 4.5 - András Tóth - refactoring sub_region to subregion.
2019.10.18 - 4.6 - András Tóth - PCG_Errors, PCG_TMP_CACHE back to clob as it is currently not supported in prod :-( I hope, one day it will be supported....
2020.01.24 - 4.7 - András Tóth - redwood emails.
2020.01.31 - 4.8 - András Tóth - branch is not handled correctly in get_hub_id_from_country_code2 function.
2020.02.20 - 4.9 - András Tóth - adding Entity handling, history table handling non-standard names
2020.03.18 - 5.0 - András Tóth - updating get_hr_job_level function.
2020.03.26 - 5.1 - András Tóth - get_country_*() allow query deleted ones for regions, subregions, hubs... keep consistencies as the get_country_*_id(<number>) already supports this method
2020.04.01 - 5.2 - András Tóth - new: get_hr_business_group_id, get_hr_bg_country_code2
2020.04.24 - 5.3 - András Tóth - Adding cache to get_hr_business_group_id, get_hr_bg_country_code2. adding v(APP_ID) to PCG_Errors
2020.05.15 - 5.4 - András Tóth - LDAP acccess method and path changing. sso_2_employee_number has syntax.
2020.09.21 - 5.5 - András Tóth - email template compatibility with Outlook.
2020.09.25 - 5.6 - András Tóth - adding PCGI package: because of 'history of country activeness'.
2020.10.22 - 5.7 - András Tóth - adding matview explain helper function for development
2020.11.09 - 5.8 - András Tóth - a common email validation function
2020.11.20 - 5.9 - András Tóth - get_manager() logs errors when LDAP raises error on non-existing employee - removed log
2021.02.05 - 6.0 - András Tóth - Slack-Integration.
2021.02.08 - 6.1 - András Tóth - adding some more logs.
2021.02.16 - 6.2 - András Tóth - slack-integration with more security
2021.05.21 - 6.3 - András Tóth - adding some more logs
2021.09.24 - 6.4 - András Tóth - country_payroll_manager and analyst column length limit raised.
2021.10.04 - 6.5 - András Tóth - sendslack enhancement, cache saving correction.
2021.11.17 - 6.6 - András Tóth - adding HR Entity data
2021.12.02 - 6.7 - András Tóth - get_hr_entity_code - data type should be varchar not number. adding the Person Type filter for HR data queries.
2021.12.06 - 6.8 - András Tóth - blob and clob conversation functions added.
2022.01.10 - 6.9 - András Tóth - adjusting HR View functions --> they will try again in case of failure - handle multiple attempts.
2022.01.18 - 7.1 - András Tóth - blob_to_clob adjustments
2022.11.21 - 7.2 - Marek Szwarczewski - in procedure update_md_users_v allow colecting entries from the table MD_TEST_USERS
2023.11.15 - 7.3 - Bhuvi Chauhan - Merged HR_paas_PKG created by Marek into this package. 
2024.02,23 - 7.4 - Bhuvi Chauhan - Changes in get_manager function as LDAP seems to be not returning any data, so now getting the data via PAAS.
2024.02.28 - 7.5 - Bhuvi Chauhan - Added new paramter p_status in sendmail procedure and created a new logic for enhancement 101107.
2024.06.12 - 7.6 - Bhuvi Chauhan - Added new function get_hr_paas_data_pid 
2024.06.18 - 7.7 - Bhuvi Chauhan - Updating function get_hr_job_level,get_hr_bg_country_code2,get_hr_business_group_id to use paas
2024.06.20 - 7.8 - Bhuvi Chauhan - Created a new function to get the data via pass based on the country (get_hr_paas_country_data)
2024.06.24 - 7.9 - Bhuvi Chauhan - Created a new function to get the data via pass based on the department name (get_hr_paas_dept_data)
2024.08.02 - 8.0 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
2024.12.19 - 8.1 - Bhuvi Chauhan - Included get_reporting_mail function in this package created by Rohit Kumar
2025.03.11 - 8.2 - Bhuvi Chauhan - Added fix_temp_entity_folders
2026.07.31 - 8.3 - Pragya Kapoor - Remove dependency of LDAP
*/
 
-- TODO: get_manager: caching null values also? review the LDAP cache timeout also?
 
-- Version of Package
c_version constant varchar2(5 char) := '8.2';
 
function get_SQLERRM(p_SQLCODE number) return varchar2 deterministic is
/** returns messages for user-defined exception
2017.03.14 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'get_sqlerrm';
 
begin return case p_SQLCODE
  when -20001 then 'SQL injection attempt.'
  when -20002 then 'Modification of rows not allowed.'
  when -20003 then 'Invalid input value.'
  when -20004 then 'Cannot create, already exists.'
  when -20005 then 'Cannot proceed, does not exist.'
  when -20006 then 'Cannot be a valid object name.'
  when -20007 then 'You are not authorized to access this object.'
  else sqlerrm end;
end get_SQLERRM;
 
 
function explain_mview(p_view_name in varchar2) return clob is
    c_proc_name varchar2(30) := 'explain_mview';
    c_proc_version varchar2(10) := '1.0';
    v_explain_array sys.ExplainMVArrayType;
    v_explain_plan clob;
    v_ln varchar2(1000);
begin
    v_ln := 1;
    v_explain_plan := '--------' || c_new_line;
    v_ln := 2;
    dbms_mview.explain_mview(trim(upper(p_view_name)),v_explain_array);
    v_ln := 3;
    v_explain_plan := v_explain_plan || 'Explain MV ' || v_explain_array(1).mvowner || '.' || v_explain_array(1).mvname || c_new_line;
 
    v_ln := 4;
    for i in 1..v_explain_array.count loop
        v_ln := 5;
        v_explain_plan := v_explain_plan ||
            rpad(v_explain_array(i).capability_name, 30)
            || ' [' || case v_explain_array(i).possible
                       when 'T' then 'TRUE'
                       when 'F' then 'FALSE'
                       else v_explain_array(i).possible
                       end || ']'
            || case when v_explain_array(i).related_num != 0 then
                   ' ' || v_explain_array(i).related_text
                   || ' (' || v_explain_array(i).related_num || ')'
               end
            || case when v_explain_array(i).msgno != 0 then
                   ' ' || v_explain_array(i).msgtxt
                   || ' (' || v_explain_array(i).msgno || ')'
               end
        || c_new_line;
    end loop;
    v_ln := 6;
    v_explain_plan := v_explain_plan || '--------' || c_new_line;
    v_ln := 7;
    return v_explain_plan;
exception when others then
  log($$PLSQL_UNIT ||'.'|| c_proc_name, c_version, c_proc_version, '['||v_ln||'] '||SQLERRM, SQLCODE, c_ERROR);
end;
 
function vcalendar(
  p_title in varchar2,
  p_description in varchar2,
  p_location in varchar2,
  p_start in date /* we are expecting UTC */,
  p_end in date /* we are expecting UTC */,
  p_email in varchar2 default 'noreply@oracle.com',
  p_uid in varchar2 default null,
  p_CREATION_DATE in date default null /* we are expecting UTC ; same as start date if not provided */
) return varchar2 deterministic is
begin
  return decode_regexp_replace(c_vcalendar_template,
    '#SUBJECT#',regexp_replace(p_title,'\W',' '),
    '#DESC#',regexp_replace(p_description,'\W',' '),
    '#LOC#',regexp_replace(p_location,'\W',' '),                                  /* maybe escape would also work: Hodgenville\, Kentucky   */
    '#CREATION_DATE#',to_char( nvl(p_CREATION_DATE,p_start) ,'YYYYMMDD"T"HH24MISS"Z"'),
    '#START#',to_char(p_start,'YYYYMMDD"T"HH24MISS"Z"'),                          /* 19970714T170000Z */
    '#END#',to_char(p_end,'YYYYMMDD"T"HH24MISS"Z"'),                              /* 19970715T035959Z */
    '#UID#',nvl(p_uid,to_char( nvl(p_CREATION_DATE,p_start) ,'YYYYMMDD"T"HH24MISS"Z"')||'-'||p_email),   /* e.g.   87CB6470F0A9C438E0532F37548C66FA */
    '#ONAME#',nvl(trim(regexp_replace(email2name(p_email),'\W',' ')),'Unknown'),
    '#ORGANIZER#',lower(p_email)
  );
end;
 
function calculate_error_level(p_error_level in varchar2) return varchar2 deterministic is
/** Returns the error level standard constant value; returns null if not applicable.
2018.06.15 - 1.0 - András Tóth - create procedure
2020.09.25 - 1.1 - András Tóth - Moved to another package
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'calculate_error_level';
begin
  return PCG_INDEPENDENT_PKG.calculate_error_level(p_error_level);
end calculate_error_level;
 
procedure log(
  p_sender in varchar2 default null,
  p_pkg_version in varchar2 default null,
  p_proc_version in varchar2 default null,
  p_message in clob default null,
  p_error_code in number default null,
  p_error_level in varchar2 default null)
is pragma autonomous_transaction;
/** Make a log entry to PCG_Errors table. p_sender and p_message must have a value.
2017.03.14 - 1.0 - András Tóth - create procedure
2018.04.26 - 1.1 - András Tóth - adding log level (if wrong string is provided, null is inserted), and update defaults
2018.06.15 - 1.2 - András Tóth - adding log level masking functionality.
2020.04.27 - 1.3 - András Tóth - adding APEX metadata also.
*/
  c_proc_version constant varchar2(5 char) := '1.3';
  c_proc_name constant varchar2(30 char) := 'log';
  v_masked number := 0; /* 0 - false, 1 - true */
  v_error_level varchar2(200 char);
  v_apex_app_id varchar2(4000);
  v_apex_app_page_id varchar2(4000);
  v_apex_app_user varchar2(4000);
  v_apex_session varchar2(4000);
begin
/* Only these are accepted:
  DEBUG - Information that is diagnostically helpful.
  INFO - Generally useful information to log (service start/stop, configuration assumptions, etc).
  WARN - Anything that can potentially cause application oddities.
  ERROR - Any error which is fatal to the operation, but not the service or application (can't open a required file, missing data, etc.).
  FATAL - Any error that is forcing a shutdown of the service or application to prevent data loss.
*/
v_error_level := calculate_error_level(p_error_level);
 
  begin
    v_apex_app_id := v('APP_ID');
    v_apex_app_page_id := v('APP_PAGE_ID');
    v_apex_app_user := v('APP_USER');
    v_apex_session := v('SESSION'); -- needed for CSSAP compliance.
  exception when others then null;
  end;
 
  select nvl(max(1),0) into v_masked
  from PCG_Errors_Control_Masks
  where
    trim(lower(error_sender)) = trim(lower(p_sender)) and
    nvl(error_level,'NULL') = nvl(v_error_level,'NULL');
 
  if p_sender is not null and p_message is not null and v_masked = 0 then
  insert into PCG_Errors (error_time,error_sender,error_sender_pkg_version,error_sender_proc_version,error_text, error_code, error_level, apex_app_id, apex_app_page_id, apex_app_user, apex_session)
    values (systimestamp,trim(lower(p_sender)),trim(lower(p_pkg_version)),trim(lower(p_proc_version)),p_message, p_error_code, v_error_level, v_apex_app_id, v_apex_app_page_id, v_apex_app_user, v_apex_session);
  commit;
  end if;
end log;
 
function log(p_sender in varchar2 default null, p_pkg_version in varchar2 default null, p_proc_version in varchar2 default null, p_message in clob default null, p_error_code in number default null, p_error_level in varchar2 default null) return varchar2 is
/** Runs the log procedure and returns the line of the log. The dbms_output.put_line can handle max 32767 bytes.
    2018.06.15 - 1.0 - András Tóth - create
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'log';
  v_clb clob;
  v_msg varchar2(32767 byte);
begin
  log(p_sender, p_pkg_version, p_proc_version, p_message, p_error_code, p_error_level);
  v_clb := to_clob('['||calculate_error_level(p_error_level)||'] '||to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||' - '||p_sender||' ('||trim(lower(p_pkg_version))||', '||trim(lower(p_proc_version))||') '|| p_error_code ||' - ') || p_message;
  v_msg := dbms_lob.substr(v_clb,32767,1);
  return v_msg;
exception when others then
  log($$PLSQL_UNIT ||'.'|| c_proc_name, c_version, c_proc_version, SQLERRM, SQLCODE, c_ERROR);
end log;
 
procedure audit_log(p_object varchar2, p_op varchar2, p_privs varchar2)
is pragma autonomous_transaction;
  /** Inserting into AUDIT LOG; application ID, session ID and User SSO automatically inserted
      Example: audit_log ('REPORT_UY', 'GENERATE', 'PAYROLL');
  2018.04.26 - 1.0 - András Tóth - create procedure
  */
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'audit_log';
begin
  insert into AUDIT_LOG(
      EMAIL,TIMESTAMP,SESSION_ID,SCHEMA_OBJECT,OPERATION,SYSTEM_PRIVILEGE_USED,APPLICATION_ID
    )
  values (
      v('APP_USER'),systimestamp,v('APP_SESSION'),p_object,p_op,p_privs,v('APP_ID')
    );
  commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end audit_log;
 
 
function to_iso8601_datetime (p_time timestamp) return varchar2 deterministic is
 
begin
return replace(to_char(p_time, 'YYYY-MM-DD hh24:mi:ss'),' ','T');
end;
 
 
function cv (p_constant in varchar2, p_package in varchar2 default 'pcg_payroll_common_good_pkg') return varchar2 deterministic as
/** Constant Value; Returns the value of a package constant.
2017.03.14 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'cv';
  v_res varchar2(32767 char);
begin
  test_sql_free(p_constant);
  test_sql_free(replace(p_package,'.','_'));
  execute immediate 'begin :res := '||p_package||'.c_'||p_constant||'; end;' using out v_res;
  return v_res;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cv;
 
 
function string_2_list(p_serial_list varchar2, p_sep varchar2 default ',') return PCG_string_LIST deterministic is
/** returning a list of IDs out of a string with IDs
2017.08.09 - 1.0 - András Tóth - create
2017.12.06 - 1.1 - András Tóth - string contained space handled wrongly.
2018.06.13 - 1.2 - András Tóth - return null if input is null.
*/
  c_proc_name constant varchar2(61 char) := 'string_2_list';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_car varchar2(1 char);
  v_word VARCHAR2(32767 char);
  v_list PCG_string_LIST;
  v_cnt number;
begin
  v_word := null;
  select null bulk collect into v_list from dual where 1=2;
  if p_serial_list is null then return v_list; end if;
  if p_sep is null then  select p_serial_list bulk collect into v_list from dual; return v_list; end if;
  v_cnt := 0;
  for i in 1..length(p_serial_list) loop
    v_car := substr(p_serial_list,i,1);
    if v_car = p_sep then
      v_list.extend(1);
      v_cnt := v_cnt + 1;
      v_list(v_cnt) := v_word;
      v_word := '';
    else v_word:=v_word||v_car;
    end if;
  end loop;
  v_list.extend(1);
  v_cnt := v_cnt + 1;
  v_list(v_cnt) := trim(v_word);
  return v_list;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
END string_2_list;
 
 
function id_string_2_id_list(p_ids varchar2, p_sep char default ',') return PCG_number_LIST deterministic is
/** returning a list of IDs out of a string with IDs
2017.03.21 - 1.0 - András Tóth - create
2018.06.13 - 1.1 - András Tóth - return null if input is null.
*/
  c_proc_name constant varchar2(61 char) := 'id_string_2_id_list';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_id_list PCG_number_LIST;
  v_ids varchar2(32767 char);
  v_char char:='';
  v_num varchar2(32767 char):='';
begin
  test_sql_free(replace(p_ids,p_sep,''));
  v_ids := replace(trim(p_ids),' ','');
  if v_ids is null then return null; end if;
  if not regexp_like(replace(v_ids,p_sep,''), '^[0-9]+$') then raise invalid_input_value; /* Only numbers allowed */ end if;
  select 0 bulk collect into v_id_list from dual where 1=2;
  if p_ids is null then return v_id_list; end if;
 
  for i in 1..length(v_ids) loop
   v_char := substr(v_ids,i,1);
   if v_char = p_sep then v_id_list.extend(1); v_id_list(v_id_list.last) := to_number(v_num); v_num := '';
   else v_num := v_num || v_char;
   end if;
  end loop;
  if v_char != p_sep then v_id_list.extend(1); v_id_list(v_id_list.last) := to_number(v_num); v_num := ''; end if;
 
  return v_id_list;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
END id_string_2_id_list;
 
 
procedure test_sql_free(p_text varchar2) is
/** raises exception if the text is not safe for using it in dynamic sql expression.
2017.03.14 - 1.0 - András Tóth - create procedure
*/
begin
  if is_sql_free(p_text) = c_no then raise sql_injection; end if;
end test_sql_free;
 
 
function is_sql_free(p_text varchar2) return char deterministic is
/** Returns Y or N if the text is safe for using it in dynamic sql expressions.
2017.03.14 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'is_sql_free';
 
begin
  if p_text like '%;%' or p_text like '% %' or p_text like '%(%' or p_text like '%.%' or regexp_replace(replace(p_text,'"','_'),'\w*','') is not null
    then return c_NO;
    else return c_YES;
  end if;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end is_sql_free;
 
 
function is_valid_object_name(p_name varchar2) return char deterministic is
/** Returns Y or N if the text is safe to use as a DB object name.
2017.03.16 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'is_valid_object_name';
begin
  if is_sql_free(p_name)='N' or length(trim(p_name))>30 or length(trim(p_name)) is null or length(trim(p_name)) = 0
    then return c_NO;
    else return c_YES;
  end if;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end is_valid_object_name;
 
 
function email2name(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** Returns the name out of an email
2017.03.27 - 1.0 - András Tóth - create procedure
2017.08.09 - 1.1 - András Tóth - LDAP service integration; this may cause slowing down!!!
2017.08.15 - 1.2 - András Tóth - adding cache
2018.03.29 - 1.3 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.4 - András Tóth - LDAP access method change
2024.08.02 - 1.5 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
2026.07.31 - 1.6 - Pragya Kapoor - remove LDAP and use email address to find the name
*/
  c_proc_version constant varchar2(5 char) := '1.5';
  c_proc_name constant varchar2(30 char) := 'email2name';
  v_name varchar2(32767 char);
  v_out varchar2(32767 char);
  c_hv number := 335643694 /*ORA_HASH('email2name')*/;
begin
  if trim(p_email) is null then return null; end if;
  -- get from cache
  v_name := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
 
  -- cache failed:
  if v_name is null then
    -- begin -- LDAP Querry
    --   SELECT
    --   max(val) into v_name
    --   FROM
    --   TABLE
    --     ( apex_ldap.search(
    --       p_host => c_ldap_host,
    --       p_username => c_ldap_username,
    --       p_pass => c_ldap_key,
    --       p_port => c_ldap_port,
    --       p_use_ssl => c_ldap_use_ssl,
    --       p_search_base=>c_ldap_search_base,
    --       p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
    --       p_attribute_names => 'displayname'
    --       )
    --     );
    -- exception when DBMS_LDAP.general_error then null;
    -- end;
    -- LDAP/Hand-made name from corporate email address:
    v_out := nvl(trim(v_name),initcap(replace(replace(replace(replace(upper(trim(p_email)),'@ORACLE.COM',''),'.',' '),'_',' '),'-',' ')) );
    -- put to the cash (empty old values if exists)
    cache_put_s(c_hv,p_email,v_out);
  else
    -- cache hit:
    v_out := v_name;
  end if;
 
  -- return value
  return v_out;
 
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end email2name;
 
 
procedure test_valid_object_name(p_name varchar2) is
/** raises exception if the text is not safe for using it in dynamic sql expression.
2017.03.14 - 1.0 - András Tóth - create procedure
*/
begin
  if is_valid_object_name(p_name) = c_no then raise not_valid_object_name; end if;
end test_valid_object_name;
 
 
procedure selftest is
/** TODO: Only for testing purposes.
2017.03.14 - 1.0 - András Tóth - create procedure
2017.08.01 - 1.1 - András Tóth - remove code for moving prod.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'selftest';
  v_tmp number;
  v_tablename varchar2(30 char) := 'SZAL001';
  v_i pls_integer; v_j pls_integer;
begin
  null;
 
/*
  --select 1 into v_tmp from dual;
  --select 1 into v_tmp from dual where 1=2;
  --raise table_row_modification;
  --test_sql_free('select * from dual');
 
  begin execute immediate 'drop table '||v_tablename; exception when others then null; end;
  begin execute immediate 'drop table '||v_tablename||'_H'; exception when others then null; end;
  --begin execute immediate 'drop trigger '||v_tablename||'_H_T1'; exception when others then null; end;
  --begin execute immediate 'drop trigger '||v_tablename||'_T1'; exception when others then null; end;
  --begin execute immediate 'drop trigger '||v_tablename||'_T2'; exception when others then null; end;
  --begin execute immediate 'drop trigger '||v_tablename||'_T3'; exception when others then null; end;
  execute immediate 'CREATE TABLE '||v_tablename||' (ID NUMBER, LOAD_TIME TIMESTAMP, LOAD_USER VARCHAR2(256 CHAR), VALUEFIELD VARCHAR2(4000 CHAR), valuefield2 number)';
  create_auto_audit_for_table(v_tablename);
  create_auto_id_for_table(v_tablename);
  create_history_for_table(v_tablename);
  --for idx in 2..50000 loop v_j:=v_i; v_i:=idx; end loop;
  execute immediate 'insert into '||v_tablename||'(VALUEFIELD,VALUEFIELD2) values (''v1'',1)';
  --for idx in 2..50000 loop v_j:=v_i; v_i:=idx; end loop;
  execute immediate 'insert into '||v_tablename||'(VALUEFIELD,VALUEFIELD2) values (''v2'',2)';
  --for idx in 2..50000 loop v_j:=v_i; v_i:=idx; end loop;
  execute immediate 'insert into '||v_tablename||'(VALUEFIELD,VALUEFIELD2) values (''v3'',3)';
  --for idx in 2..50000 loop v_j:=v_i; v_i:=idx; end loop;
  execute immediate 'update '||v_tablename||' set VALUEFIELD = ''v4'' where VALUEFIELD2 = 3';
  --for idx in 2..50000 loop v_j:=v_i; v_i:=idx; end loop;
  execute immediate 'update '||v_tablename||' set VALUEFIELD = ''v5'' where VALUEFIELD2 = 3';
  --for idx in 2..50000 loop v_j:=v_i; v_i:=idx; end loop;
  execute immediate 'delete from '||v_tablename||' where VALUEFIELD2 = 3';
  --for idx in 2..50000 loop v_j:=v_i; v_i:=idx; end loop;
*/
 
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end selftest;
 
 
procedure create_history_for_table (p_tablename varchar2 default null, p_schema varchar2 default sys_context('userenv', 'current_schema'), p_except varchar2 default '(LOAD_TIME)|(LOAD_USER)') is pragma autonomous_transaction;
/** Creates history table and trigger for an ordinary table.
2017.03.14 - 1.0 - András Tóth - create procedure
2017.03.17 - 1.1 - András Tóth - rowid addon
2017.03.27 - 1.2 - András Tóth - copy all rows to the _H table at first creation.
2017.04.28 - 1.3 - András Tóth - session_id addon.
2018.07.23 - 1.4 - András Tóth - adding inmemory option. I hope, it will be saved quicklier.
Known limitations: only works when less then 10 trigger exists on the given table when long tablenames are used.
                   reconstruction only works properly when the original table has some sort of ID fields.
				   Problems with extravagant tablenames
				   problems with multiple after triggers on original table.
2019.07.09 - 1.5 - András Tóth - adding APP_ID to the history table trigger also.
2020.02.25 - 1.6 - András Tóth - handling unstandard names.
*/
  c_proc_version constant varchar2(5 char) := '1.6';
  c_proc_name constant varchar2(30 char) := 'create_history_for_table';
  v_exec varchar2(32767 char);
  v_tablename varchar2(30 char);
  v_tablename_H varchar2(30 char);
  v_schema varchar2(30 char);
  v_tmp number;
  v_trigger varchar2(30 char);
  v_trigger_H varchar2(30 char);
  v_collist varchar2(32767 char):='';
  v_log clob := 'executed:'||c_line_feed||c_line_feed;
begin
DBMS_OUTPUT.PUT_LINE(1);
  -- Input validation against hacking
  --if is_valid_object_name(p_tablename)=c_no then raise invalid_input_value; end if;
  --if is_valid_object_name(p_schema)=c_no and trim(p_schema) is not null then raise invalid_input_value; end if;
  v_schema := nvl(trim(p_schema), sys_context('userenv', 'current_schema'));
  v_tablename := trim(p_tablename);
  -- name for the history table:
  v_tablename_H := replace(trim(substr(v_tablename,1,28)),'"','')||'_H';
  -- Checking if the table exists
  select count(1) into v_tmp from sys.all_tables where table_name = v_tablename and owner = v_schema;
  if v_tmp is null or v_tmp = 0 then raise data_does_not_exist; end if;
  -- checking if the table name for history table already exists:
  select count(1) into v_tmp from sys.all_tables where table_name = v_tablename_H and owner = v_schema;
  if v_tmp != 0 then raise data_already_exists; end if;
  -- A new name for the table trigger:
  select trim(substr(v_tablename,1,27))||'_T'||to_char(to_number(regexp_substr(nvl(max(object_name),trim(substr(v_tablename,1,27))||'_T0'),'[0-9]+$'))+1)
  into v_trigger
  from sys.all_objects where regexp_like (object_name,'^'||trim(substr(v_tablename,1,27))||'_T[0-9]+$');
 
  -- beginning create history table script:
  v_exec := 'create table "'||v_schema||'"."'||v_tablename_H||'"(';
  -- Collectig collumn list and type
  for i in (select '"'||COLUMN_NAME||'"' col, '"'||COLUMN_NAME||'" '||DATA_TYPE||case when DATA_TYPE like '%CHAR%' then '('||DATA_LENGTH||' char)' end col_and_type
  from sys.ALL_TAB_COLUMNS where table_name = v_tablename and owner = v_schema
  and not regexp_like(COLUMN_NAME,p_except)
  ) loop
   -- adding column types to create history table script:
   v_exec:=v_exec||','||i.col_and_type;
   -- Collecting column list:
   v_collist:=v_collist||','||i.col;
  end loop;
  -- ending and executing create history table script
  v_exec := replace(v_exec,'(,','(');
  v_collist := regexp_replace(v_collist,'^,','');
  v_exec := v_exec||',pcgh_load_user varchar2(256 byte),pcgh_load_time timestamp,pcgh_deleted char, pcgh_rowid varchar2(18 char), pcgh_session VARCHAR2(4000), pcgh_app_id VARCHAR2(4000) ) NOLOGGING INMEMORY';
  v_log := v_log||c_line_feed||c_line_feed||v_exec;
  execute immediate v_exec;
  commit;
 
  -- Creating the trigger for original table to save the history:
  v_exec:='create or replace trigger "'||v_trigger||'" after delete or update or insert on "'||v_schema||'"."'||v_tablename||'" for each row'||c_line_feed||
   '/* Generated by PCG v'||c_version||' create_history_for_table v'||c_proc_version||' on '||to_iso8601_datetime(sysdate)||' */ '||c_line_feed||
   'begin case when deleting then insert into "'||v_schema||'"."'||v_tablename_H||'" (pcgh_session, pcgh_app_id, pcgh_rowid, pcgh_load_user, pcgh_load_time, pcgh_deleted,'||v_collist||') values (v(''SESSION''), v(''APP_ID''), :OLD.rowid, v(''APP_USER''), systimestamp, pcg.cv(''yes''),'||replace(':OLD.'||v_collist,',',',:OLD.')||');'||c_line_feed||
   'else insert into "'||v_schema||'"."'||v_tablename_H||'" (pcgh_session, pcgh_app_id, pcgh_rowid, pcgh_load_user, pcgh_load_time,'||v_collist||') values (v(''SESSION''), v(''APP_ID''), :NEW.rowid, v(''APP_USER''), systimestamp,'||replace(':NEW.'||v_collist,',',',:NEW.')||');'||c_line_feed||
   'end case;'||c_line_feed||
   'exception when others then PCG.log('''||v_trigger||''',null,null,sqlerrm,sqlcode); raise;'||c_line_feed||
   'end "'||v_trigger||'";';
  v_log := v_log||c_line_feed||c_line_feed||v_exec;
  execute immediate v_exec;
  commit;
 
  -- Trigger to protect the history table
  -- A new name for the history table trigger:
  select trim(substr(rtrim(v_tablename_H,'H'),1,26))||'H_T'||to_char(to_number(regexp_substr(nvl(max(object_name),trim(substr(rtrim(v_tablename_H,'H'),1,26))||'H_T0'),'[0-9]+$'))+1)
  into v_trigger_H
  from sys.all_objects where regexp_like (object_name,'^'||trim(substr(rtrim(v_tablename_H,'H'),1,26))||'H_T[0-9]+$');
  -- trigger create script
  v_exec := 'create or replace trigger "'||v_trigger_H||'"'||c_line_feed||
   'before delete or update on "'||v_schema||'"."'||v_tablename_H||'" for each row'||c_line_feed||
   '/* Generated by PCG v'||c_version||' create_history_for_table v'||c_proc_version||' on '||to_iso8601_datetime(sysdate)||' */ '||c_line_feed||
   'begin PCG.log('''||v_trigger_H||''',null,null,PCG.get_sqlerrm(-20002),-20002); raise_application_error(-20002,PCG.get_SQLERRM(-20002));'||c_line_feed||
   'end "'||v_trigger_H||'";';
  v_log := v_log||c_line_feed||c_line_feed||v_exec;
  execute immediate v_exec;
  commit;
 BHU_LOGS(800, 'test' ,'test');
  -- Copiing all data from original table to the History table:
  v_exec := 'insert into "'||v_schema||'"."'||v_tablename_H||'"(pcgh_session, pcgh_rowid, pcgh_load_user, pcgh_load_time, '||v_collist||')'||c_line_feed||
   'select v(''SESSION''), rowid, v(''APP_USER''), systimestamp, '||v_collist||c_line_feed||
   'from "'||v_schema||'"."'||v_tablename||'"';
  execute immediate v_exec;
  commit;
 
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,v_log,-1);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end create_history_for_table;
 
 
procedure create_auto_id_for_table(p_tablename varchar2 default null, p_schema varchar2 default sys_context('userenv', 'current_schema'), p_id varchar2 default 'ID', p_seq varchar2 default 'PCG_ID_SEQ') is pragma autonomous_transaction;
/** Creates triggers to automatically update table's ID field; and prevent ID modification.
2017.03.16 - 1.0 - András Tóth - create procedure
2019.03.28 - 1.1 - András Tóth - update logging.
2020.02.25 - 1.2 - András Tóth - handling non-standard names
 
Known limitations: works only when less then 10 triggers are defined on the table with long table names.
                   Problems with extravagant tablenames and columnnames!
*/
  c_proc_version constant varchar2(5 char) := '1.2';
  c_proc_name constant varchar2(30 char) := 'create_auto_id_for_table';
  v_exec varchar2(32767 char);
  v_tablename varchar2(30 char);
  v_id varchar2(30 char);
  v_schema varchar2(30 char);
  v_tmp number;
  v_trigger varchar2(30 char);
  v_log clob := 'executed:'||c_line_feed||c_line_feed;
  v_seq varchar2(30 char);
begin
  -- input validation
  --if is_valid_object_name(p_tablename)=c_no then raise invalid_input_value; end if;
  --if is_valid_object_name(p_schema)=c_no then raise invalid_input_value; end if;
  --if is_valid_object_name(p_id)=c_no then raise invalid_input_value; end if;
  --if is_valid_object_name(p_seq)=c_no then raise invalid_input_value; end if;
  v_schema := trim(p_schema);
  v_tablename := trim(p_tablename);
  v_id := trim(p_id);
  v_seq := trim(p_seq);
  select count(1) into v_tmp from sys.all_tables where table_name = v_tablename and owner = v_schema;
  if v_tmp is null or v_tmp = 0 then raise data_does_not_exist; end if;
  -- A new name for the table trigger:
  select trim(substr(v_tablename,1,27))||'_T'||to_char(to_number(regexp_substr(nvl(max(object_name),trim(substr(v_tablename,1,27))||'_T0'),'[0-9]+$'))+1)
  into v_trigger
  from sys.all_objects where regexp_like (object_name,'^'||trim(substr(v_tablename,1,27))||'_T[0-9]+$');
  -- create trigger script:
  v_exec := 'create or replace TRIGGER  "'||v_trigger||'" before update or insert on "'||v_schema||'"."'||v_tablename||'" for each row'||c_line_feed||
   '/* Generated by PCG v'||c_version||' create_auto_id_for_table v'||c_proc_version||' on '||to_iso8601_datetime(sysdate)||' */ '||c_line_feed||
   'begin case when updating and :OLD."'||V_ID||'" != :NEW."'||v_ID||'" then raise PCG.table_row_modification; when inserting then :NEW."'||v_ID||'" := "'||v_seq||'".nextval; else null; end case;'||c_line_feed||
   'exception when others then PCG.log('''||v_trigger||''',null,null,sqlerrm,sqlcode); raise;'||c_line_feed||
   'end "'||v_trigger||'";';
  v_log := v_log||c_line_feed||c_line_feed||v_exec;
  execute immediate v_exec;
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,v_log,null,c_Debug);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,v_log,-1);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end create_auto_id_for_table;
 
 
procedure create_auto_audit_for_table(p_tablename varchar2 default null, p_schema varchar2 default sys_context('userenv', 'current_schema'), p_user varchar2 default 'LOAD_USER', p_time varchar2 default 'LOAD_TIME') is pragma autonomous_transaction;
/** Creates triggers to automatically update load_user and load_time fields
2017.03.16 - 1.0 - András Tóth - create procedure
 
Known limitations: works only when less then 10 triggers are defined on the table with long table names.
                   Problems with extravagant tablenames and columnnames!
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'create_auto_audit_for_table';
  v_exec varchar2(32767 char);
  v_tablename varchar2(30 char);
  v_user varchar2(30 char);
  v_time varchar2(30 char);
  v_schema varchar2(30 char);
  v_tmp number;
  v_trigger varchar2(30 char);
  v_log clob := 'executed:'||c_line_feed||c_line_feed;
begin
  -- input validation
  if is_valid_object_name(p_tablename)=c_no then raise invalid_input_value; end if;
  if is_valid_object_name(p_schema)=c_no then raise invalid_input_value; end if;
  if is_valid_object_name(p_user)=c_no then raise invalid_input_value; end if;
  if is_valid_object_name(p_time)=c_no then raise invalid_input_value; end if;
  v_schema := trim(p_schema);
  v_tablename := trim(p_tablename);
  v_user := trim(p_user);
  v_time := trim(p_time);
  select count(1) into v_tmp from sys.all_tables where table_name = v_tablename and owner = v_schema;
  if v_tmp is null or v_tmp = 0 then raise data_does_not_exist; end if;
  -- A new name for the table trigger:
  select trim(substr(v_tablename,1,27))||'_T'||to_char(to_number(regexp_substr(nvl(max(object_name),trim(substr(v_tablename,1,27))||'_T0'),'[0-9]+$'))+1)
  into v_trigger
  from sys.all_objects where regexp_like (object_name,'^'||trim(substr(v_tablename,1,27))||'_T[0-9]+$');
  -- create trigger script:
  v_exec := 'create or replace TRIGGER  '||v_trigger||' before update or insert on '||v_schema||'.'||v_tablename||' for each row'||c_line_feed||
   '/* Generated by PCG v'||c_version||' create_auto_audit_for_table v'||c_proc_version||' on '||to_iso8601_datetime(sysdate)||' */ '||c_line_feed||
   'begin :NEW.'||v_user||' := v(''APP_USER''); :NEW.'||v_time||' := systimestamp;'||c_line_feed||
   'exception when others then PCG.log('''||v_trigger||''',null,null,sqlerrm,sqlcode); raise;'||c_line_feed||
   'end '||v_trigger||';';
  v_log := v_log||c_line_feed||c_line_feed||v_exec;
  execute immediate v_exec;
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,v_log,0);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,v_log,-1);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end create_auto_audit_for_table;
 
 
procedure sendmail(
  p_to in varchar2,
  p_app_id in varchar2,
  p_app_name in varchar2,
  p_title in varchar2,
  p_text in varchar2,
  p_attachment in blob default null,
  p_attachment_mime in varchar2 default null,
  p_attachment_filename in varchar2 default null
   , p_status in varchar2 default null
) as
/** Sends emails to the recipients
2017.04.05 - 1.0 - András Tóth - create procedure
2017.05.04 - 1.1 - András Tóth - formating options for Maurice.
2018.04.26 - 1.2 - András Tóth - adding some extra logging; adding the security group setting; adding "commit;", delete "Wwv_Flow_Mail.Push_Queue" - TO-DO: remove debug when not needed.
2018.05.02 - 1.3 - András Tóth - removing extra debug log.
2019.02.26 - 1.4 - András Tóth - new mail template.
2019.03.20 - 1.5 - András Tóth - amend: no link to the application when p_app_id is null!
2019.07.02 - 1.6 - András Tóth - adding the attachments
2020.01.24 - 1.7 - András Tóth - redwood emails.
2020.09.21 - 1.8 - András Tóth - email compatibility with Outlook
2024.02.27 - 1.9 - Bhuvi Chauhan - email template adjusted as per payroll edu tracker application also added a new parameter p_status.
*/
pragma autonomous_transaction;
  c_proc_version constant varchar2(5 char) := '1.9';
  c_proc_name constant varchar2(30 char) := 'sendmail';
  v_out_body_html varchar2(32767 char);
  v_app_url varchar2(32767 char);
  v_meeting_url varchar2(32767 char) := null; 
  v_start_pos NUMBER;
 
  v_mail_id NUMBER;
 
  v_mail_template varchar2(32767 char);
 
   --l_mailhost VARCHAR2(255) := 'aria.us.oracle.com';
   --l_mail_conn utl_smtp.connection;
begin
  wwv_flow_api.set_security_group_id;
 
  begin -- logging debug information
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
    ,'Params: p_to='||p_to||', p_app_id='||p_app_id||', p_app_name='||p_app_name||', p_title='||p_title||', p_text='||p_text||', WS_ID='||v('WORKSPACE_ID')
    ,null,c_Debug);
  exception when others then null;
  end;
 
  if p_to is null or p_text is null /*or p_app_id is null*/ or p_title is null or p_app_name is null then return; end if;
 
  select text into v_mail_template from PT_TEXTS_V where TEXT_TYPE = 'EMAIL_TEMPLATE' and LANG = 'en';
  if trim(p_app_id) is null then
    v_app_url := '#';
--   elsif trim(p_app_id) = '13548' then
--     v_app_url := app_url(p_app_id,311);

  else
    v_app_url := app_url(p_app_id);
  end if;

--New Logic added in V1.9 for PT enhancement added a new button join training for that added this meeting_url, also mande change in pt_texts table
  if p_app_id = '9205701'
   and p_status = 'enroll' 
   then
   bhu_logs(1,'PT 1 IF','clob1pt');
   -- As we want to use enroll email template with that new join training button in it
   v_mail_template := null;
   select text into v_mail_template from PT_TEXTS_V where TEXT_TYPE = 'EMAIL_TEMPLATE_ENROLL' and LANG = 'en';
-- Find the position of "Meeting URL:"
    v_start_pos := INSTR(p_text, 'Meeting URL:');
    bhu_logs(2,'PT 2 IF '||v_start_pos,'clob2pt');

-- Extract the substring starting from the position of "Meeting URL:"
    IF v_start_pos > 0 THEN
        v_meeting_url := SUBSTR(p_text, v_start_pos + LENGTH('Meeting URL:'));
        bhu_logs(3,'PT 3 IF '||v_meeting_url,'clob3pt');
    ELSE
        v_meeting_url := NULL; -- "Meeting URL:" not found
        bhu_logs(4,'PT 4 ELSE '||v_meeting_url,'clob4pt');
    END IF;

    bhu_logs(5,'PT 5 IF '||v_meeting_url,'clob5pt');
    v_out_body_html:= replace(replace(replace(replace(replace(replace(replace(replace(v_mail_template
    ,'#NAME#',  p_app_name)
    ,'#TITLE#', p_title)
    ,'#YEAR#', to_char(sysdate,'YYYY'))
    ,'#TEXT#', p_text)
    ,'#MEETING_URL#',v_meeting_url)
    ,'#APP_URL#', v_app_url)
    ,'#BUTTON_START#', case when trim(p_app_id) is null then ' <!-- ' else ' ' end)
    ,'#BUTTON_END#', case when trim(p_app_id) is null then ' --> ' else ' ' end);
    bhu_logs(6,'PT 6 IF '||v_out_body_html,'v_out_body_html clob '||v_out_body_html);
  else
 
    v_out_body_html:= replace(replace(replace(replace(replace(replace(replace(v_mail_template
    ,'#NAME#',  p_app_name)
    ,'#TITLE#', p_title)
    ,'#YEAR#', to_char(sysdate,'YYYY'))
    ,'#TEXT#', p_text)
    ,'#APP_URL#', v_app_url)
    ,'#BUTTON_START#', case when trim(p_app_id) is null then ' <!-- ' else ' ' end)
    ,'#BUTTON_END#', case when trim(p_app_id) is null then ' --> ' else ' ' end);
    bhu_logs(7,'PT 7 ELSE '||v_out_body_html,'v_out_body_html clob else '||v_out_body_html);
  end if;

/*
-- case when trim(p_app_id) is not null then
 
<a style="font-size: 12pt; font-style: italic; color: white; background-color: #ff0000; text-shadow: 1px 1px 2px black, 0 0 25px darkgray, 0 0 5px gray; text-decoration: none; padding: 3px 3px 3px 3px; font-weight: bold; letter-spacing: 1px; display:#DISPLNK#;"
  title="open #NAME# application page"
  href="'||v_app_url||'">#NAME#</a>'||chr(13)||chr(10)
'		    <br />
 
 
v_app_url --> #APP_URL#
 
*/
 
  /*begin -- logging debug information
  log(c_pkg_name||'.'||c_proc_name,c_version,c_proc_version
    ,'generated: p_to='||p_to||', v_out_body_html='||v_out_body_html
    ,null,c_Debug);
  exception when others then null;
  end;*/
 
    v_mail_id := APEX_MAIL.SEND(lower(p_to),'noreply@oracle.com',null/*v_out_body_txt*/,v_out_body_html, p_app_name||' - '||p_title);
 
    if p_attachment_filename is not null then
      APEX_MAIL.ADD_ATTACHMENT(
                p_mail_id    => v_mail_id,
                p_attachment => p_attachment,
                p_filename   => p_attachment_filename,
                p_mime_type  => p_attachment_mime );
    end if;
    --Wwv_Flow_Mail.Push_Queue;
   commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end sendmail;
 
procedure sendslack(p_email in varchar2, p_message in varchar2, p_channel in varchar2 default null) is
  v_ret clob;
begin
  v_ret := sendslack(p_email, p_message, p_channel);
end sendslack;
 
procedure sendslack_err(p_email in varchar2, p_message in varchar2, p_channel in varchar2 default null) is
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'sendslack_err';
  v_ret clob;
begin
  v_ret := sendslack(p_email, p_message, p_channel);
  if not json_value(v_ret, '$.ok' RETURNING BOOLEAN) then raise_application_error(-20009, 'sending slack message failed'); end if;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,SQLERRM||' - '||v_ret,sqlcode);
  raise;
end sendslack_err;
 
 
function sendslack(p_email in varchar2, p_message in varchar2, p_channel in varchar2 default null) return clob is
/** Sends messages via Slack.
**Note**: Only URLs to applications, pages and resource IDs allowed; no any confidential information!
Modifications:
2021.02.05 - 1.0 - András Tóth - create procedure
2021.02.08 - 1.1 - András Tóth - adding more logs
2021.02.11 - 1.2 - András Tóth - change header for first call.
2021.02.16 - 1.3 - András Tóth - updating security, searching other workspaces
2021.10.04 - 1.4 - András Tóth - enhancement with channel support.
*/
pragma autonomous_transaction;
  c_proc_version constant varchar2(5 char) := '1.4';
  c_proc_name constant varchar2(30 char) := 'sendslack';
 
  v_result1 CLOB;
  v_result2 CLOB;
  v_result3 CLOB;
  v_user_id varchar2(4000);
  v_ln varchar2(4000);
begin
  v_ln := 0;
  wwv_flow_api.set_security_group_id;
  v_ln := 1;
 
  if p_email is not null then
    apex_web_service.g_request_headers(1).name := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/x-www-form-urlencoded; charset=utf-8';
    v_ln := 2;
 
    v_ln := 3;
    v_result1 := apex_web_service.make_rest_request(
        p_url => 'https://slack.com/api/users.lookupByEmail?email='||trim(lower(p_email)),
        p_http_method => 'GET',
        p_proxy_override => 'pdit-b2b-proxy.oraclecorp.com:80',
        p_credential_static_id => 'payroll_slack'
    );
    v_ln := 4;
 
    v_user_id := json_value(v_result1, '$.user.id');
    v_ln := 5;
 
    apex_web_service.g_request_headers(1).name := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/json; charset=utf-8';
    v_result2 := apex_web_service.make_rest_request(
        p_url => 'https://slack.com/api/chat.postMessage',
        p_http_method => 'POST',
        p_proxy_override => 'pdit-b2b-proxy.oraclecorp.com:80',
        p_body => '{"channel":"'||APEX_ESCAPE.JSON(v_user_id)||'","text":"'||APEX_ESCAPE.JSON(p_message)||'"}',
        p_credential_static_id => 'payroll_slack'
    );
    v_ln := 6;
 
    commit;
  end if;
 
  if p_channel is not null then
    v_ln := 7;
    apex_web_service.g_request_headers(1).name := 'Content-Type';
    v_ln := 8;
    apex_web_service.g_request_headers(1).value := 'application/json; charset=utf-8';
    v_ln := 9;
    v_result3 := apex_web_service.make_rest_request(
        p_url => 'https://slack.com/api/chat.postMessage',
        p_http_method => 'POST',
        p_proxy_override => 'pdit-b2b-proxy.oraclecorp.com:80',
        p_body => '{"channel":"'||APEX_ESCAPE.JSON(p_channel)||'","text":"'||APEX_ESCAPE.JSON(p_message)||'"}',
        p_credential_static_id => 'payroll_slack'
    );
    v_ln := 10;
    commit;
  end if;
 
  v_ln := 11;
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,
    '--- p_email ---'||c_new_line||p_email||c_new_line||
    '--- p_message ---'||c_new_line||p_message||c_new_line||
    '--- p_channel ---'||c_new_line||p_channel||c_new_line||
    '--- v_user_id ---'||c_new_line||v_user_id||c_new_line||
    '--- v_result1 ---'||c_new_line||v_result1||c_new_line||
    '--- v_result2 ---'||c_new_line||v_result2||c_new_line||
    '--- v_result3 ---'||c_new_line||v_result3||c_new_line
    ,null,c_Debug);
  v_ln := 12;
 
  if v_result2 is not null and not json_value(v_result2, '$.ok' RETURNING BOOLEAN) then return v_result2; end if;
  if v_result3 is not null and not json_value(v_result3, '$.ok' RETURNING BOOLEAN) then return v_result3; end if;
 
  return nvl(v_result2, v_result3);
 
exception when others then
 log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'['||v_ln||'] '||SQLERRM||', p_email='||p_email||', p_message='||p_message||', v_user_id='||v_user_id||', p_channel='||p_channel||', v_result1='||v_result1||', v_result2='||v_result2||', v_result3='||v_result3,sqlcode);
 raise;
end sendslack;
 
function decode_regexp_replace (p_text clob
, p_in0 varchar2 default null, p_out0 varchar2 default null
, p_in1 varchar2 default null, p_out1 varchar2 default null
, p_in2 varchar2 default null, p_out2 varchar2 default null
, p_in3 varchar2 default null, p_out3 varchar2 default null
, p_in4 varchar2 default null, p_out4 varchar2 default null
, p_in5 varchar2 default null, p_out5 varchar2 default null
, p_in6 varchar2 default null, p_out6 varchar2 default null
, p_in7 varchar2 default null, p_out7 varchar2 default null
, p_in8 varchar2 default null, p_out8 varchar2 default null
, p_in9 varchar2 default null, p_out9 varchar2 default null
, p_in10 varchar2 default null, p_out10 varchar2 default null
, p_in11 varchar2 default null, p_out11 varchar2 default null
, p_in12 varchar2 default null, p_out12 varchar2 default null
, p_in13 varchar2 default null, p_out13 varchar2 default null
, p_in14 varchar2 default null, p_out14 varchar2 default null
, p_in15 varchar2 default null, p_out15 varchar2 default null
, p_in16 varchar2 default null, p_out16 varchar2 default null
, p_in17 varchar2 default null, p_out17 varchar2 default null
, p_in18 varchar2 default null, p_out18 varchar2 default null
, p_in19 varchar2 default null, p_out19 varchar2 default null
, p_in20 varchar2 default null, p_out20 varchar2 default null
, p_in21 varchar2 default null, p_out21 varchar2 default null
, p_in22 varchar2 default null, p_out22 varchar2 default null
, p_in23 varchar2 default null, p_out23 varchar2 default null
, p_in24 varchar2 default null, p_out24 varchar2 default null
, p_in25 varchar2 default null, p_out25 varchar2 default null
, p_in26 varchar2 default null, p_out26 varchar2 default null
, p_in27 varchar2 default null, p_out27 varchar2 default null
, p_in28 varchar2 default null, p_out28 varchar2 default null
, p_in29 varchar2 default null, p_out29 varchar2 default null
, p_in30 varchar2 default null, p_out30 varchar2 default null
, p_occurence number default 0
, p_match_parameter varchar2 default null) return clob as
/** replaces multiple strings in an input clob. Maximum: 31.
2017.04.11 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'decode_regexp_replace';
 
begin
return
regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
regexp_replace(regexp_replace(regexp_replace(
  p_text
, p_in0 , p_out0 , 1, p_occurence, p_match_parameter)
, p_in1 , p_out1 , 1, p_occurence, p_match_parameter)
, p_in2 , p_out2 , 1, p_occurence, p_match_parameter)
, p_in3 , p_out3 , 1, p_occurence, p_match_parameter)
, p_in4 , p_out4 , 1, p_occurence, p_match_parameter)
, p_in5 , p_out5 , 1, p_occurence, p_match_parameter)
, p_in6 , p_out6 , 1, p_occurence, p_match_parameter)
, p_in7 , p_out7 , 1, p_occurence, p_match_parameter)
, p_in8 , p_out8 , 1, p_occurence, p_match_parameter)
, p_in9 , p_out9 , 1, p_occurence, p_match_parameter)
, p_in10 , p_out10 , 1, p_occurence, p_match_parameter)
, p_in11 , p_out11 , 1, p_occurence, p_match_parameter)
, p_in12 , p_out12 , 1, p_occurence, p_match_parameter)
, p_in13 , p_out13 , 1, p_occurence, p_match_parameter)
, p_in14 , p_out14 , 1, p_occurence, p_match_parameter)
, p_in15 , p_out15 , 1, p_occurence, p_match_parameter)
, p_in16 , p_out16 , 1, p_occurence, p_match_parameter)
, p_in17 , p_out17 , 1, p_occurence, p_match_parameter)
, p_in18 , p_out18 , 1, p_occurence, p_match_parameter)
, p_in19 , p_out19 , 1, p_occurence, p_match_parameter)
, p_in20 , p_out20 , 1, p_occurence, p_match_parameter)
, p_in21 , p_out21 , 1, p_occurence, p_match_parameter)
, p_in22 , p_out22 , 1, p_occurence, p_match_parameter)
, p_in23 , p_out23 , 1, p_occurence, p_match_parameter)
, p_in24 , p_out24 , 1, p_occurence, p_match_parameter)
, p_in25 , p_out25 , 1, p_occurence, p_match_parameter)
, p_in26 , p_out26 , 1, p_occurence, p_match_parameter)
, p_in27 , p_out27 , 1, p_occurence, p_match_parameter)
, p_in28 , p_out28 , 1, p_occurence, p_match_parameter)
, p_in29 , p_out29 , 1, p_occurence, p_match_parameter)
, p_in30 , p_out30 , 1, p_occurence, p_match_parameter);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end decode_regexp_replace;
 
 
procedure fill_tablespace is
/** Fills the tablespace full, then frees the space.
*/
  pragma autonomous_transaction;
begin
  commit;
  begin
    execute immediate 'drop table ux011040filler';
  exception when others then null;
  end;
  execute immediate 'create table ux011040filler (o varchar2(4000 char))';
  while 1=1 loop
    execute immediate 'insert into ux011040filler select ''xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'' from dual';
    commit;
  end loop;
exception when others then
  begin
    execute immediate 'drop table ux011040filler';
  exception when others then null;
  end;
end;
 
 
procedure kv_add(p_key varchar2, p_value varchar2, p_active_sign char default 'Y', p_order number default null) is
/** Adding a new key to the Key-Value Store.
2017.05.22 - 1.0 - András Tóth - create
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'kv_add';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  insert into MD_KV (k,v,a,o) values (p_key,p_value,p_active_sign,p_order);
  commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_add;
 
 
procedure kv_del(p_key varchar2, p_value varchar2 default null) is
/** Delete a full key or a key-value pair from the Key-Value Store.
2017.05.22 - 1.0 - András Tóth - create
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'kv_del';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  delete from MD_KV where k = p_key and (v = p_value or p_value is null);
  commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_del;
 
 
procedure kv_del(p_id number) is
/** Delete a key-value pair identified by ID from the Key-Value Store.
2017.05.22 - 1.0 - András Tóth - create
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'kv_del';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  delete from MD_KV where id = p_id;
  commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_del;
 
 
procedure kv_set(p_key varchar2, p_value varchar2 default null, p_active_sign char default 'Y', p_order number default null) is
/** Change an existing value in the Key-Value Store. Where no parameter is provided, it leaves the original value
2017.05.22 - 1.0 - András Tóth - create
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'kv_set';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  update MD_KV set v = nvl(p_value,v), a = nvl(p_active_sign,a), o = nvl(p_order,o) where k = p_key;
  commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_set;
 
 
procedure kv_set(p_id number, p_value varchar2 default null, p_active_sign char default 'Y', p_order number default null) is
/** Change an existing value in the Key-Value Store. Where no parameter is provided, it leaves the original value
2017.05.22 - 1.0 - András Tóth - create
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'kv_set';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  update MD_KV set v = nvl(p_value,v), a = nvl(p_active_sign,a), o = nvl(p_order,o) where id = p_id;
  commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_set;
 
 
function kv_get_id(p_key varchar2, p_value varchar2 default null, p_active_sign char default 'Y') return number is
/** Returns the ID for a given key (and value if multiple value exists); if active_sign is set to 'N' then searches inactive values too.
2017.05.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'kv_get_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin
  select id into v_tmp from MD_KV where k = p_key and (v = p_value or p_value is null) and (a = c_Yes or p_active_sign = c_No);
  return v_tmp;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_get_id;
 
 
function kv_get_ids(p_key varchar2, p_active_sign char default 'Y', p_separator varchar2 default ',') return clob is
/** Returns the IDs of matching Key-Values. ordered by O value. If value is not provided, all Ids will be returned.
2017.05.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'kv_get_ids';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp clob;
begin
  select listagg(id,p_separator) WITHIN GROUP (ORDER BY o,id) into v_tmp from MD_KV where k = p_key and (a = c_Yes or p_active_sign = c_No);
  return v_tmp;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_get_ids;
 
 
function kv_get_ids_c(p_key varchar2, p_active_sign char default 'Y')  return PCG_string_LIST is
/** Returns the IDs of matching Key-Values. ordered by O value. If value is not provided, all Ids will be returned.
2017.05.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'kv_get_ids_c';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp PCG_string_LIST;
begin
  select id bulk collect into v_tmp from MD_KV where k = p_key and (a = c_Yes or p_active_sign = c_No) order by o, id;
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_get_ids_c;
 
 
function kv_get_values(p_key varchar2, p_active_sign char default 'Y', p_separator varchar2 default ',') return clob is
/** Returns the IDs of matching Key-Values. ordered by O value.
2017.05.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'kv_get_values';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp clob;
begin
  select listagg(v,p_separator) WITHIN GROUP (ORDER BY o,v) into v_tmp from MD_KV where k = p_key and (a = c_Yes or p_active_sign = c_No);
  return v_tmp;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_get_values;
 
 
function kv_get_values_c(p_key varchar2, p_active_sign char default 'Y') return PCG_string_LIST is
/** Returns the IDs of matching Key-Values. ordered by O value.
2017.05.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'kv_get_values_c';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp PCG_string_LIST;
begin
  select v bulk collect into v_tmp from MD_KV where k = p_key and (a = c_Yes or p_active_sign = c_No) order by o,v;
  return v_tmp;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end kv_get_values_c;
 
 
function has_role(p_role_name varchar2, p_user varchar2 default v('APP_USER')) return char deterministic is
/** Retunrs Yes or No if a user has or not has a certain role through OIM or in test environment.
  2017.05.22 - 1.0 - András Tóth - create
  2018.01.30 - 1.1 - András Tóth - character conversion error
*/
  c_proc_name constant varchar2(61 char) := 'has_role';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_tmp char := null;
begin
  select case when max(1)=1 then c_yes else c_no end into v_tmp from MD_USERS_V where ROLE_NAME = p_role_name and username = p_user;
  return v_tmp;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end has_role;
 
 
procedure test_role(p_role_name varchar2, p_user varchar2 default v('APP_USER')) is
/** Retunrs Yes or No if a user has or not has a certain role through OIM or in test environment.
2017.05.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'test_role';
  c_proc_version constant varchar2(5 char) := '1.0';
begin if has_role(p_role_name,p_user) = c_No then raise not_authorized; end if;
end test_role;
 
 
function custom_auth (p_username in varchar2, p_password in varchar2) return boolean as
/** This function returns true if the package is not installed on the prod environment.
2017.08.09 - 1.0 - András Tóth - create
2018.05.02 - 1.1 - András Tóth - adding extra check if the c_ws_id is set or not...
*/
begin
 
  if trim(c_WS_ID) is null or trim(c_WS_ID) = '0' then
    wwv_flow_api.set_security_group_id;
    c_WS_NAME := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
    c_WS_ID := v('WORKSPACE_ID');
  end if;
 
  return case when c_Prod_WS_ID = c_WS_ID then false else true end;
end custom_auth;
 
 
function get_role(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** returns the OIM role for a user.
2017.08.09 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'get_role';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_username varchar2(256 char);
  v_role_name varchar2(256 char);
begin
   select /*max(username),*/ max(role_name) into /*v_username,*/ v_role_name from MD_USERS_V where username = upper(p_email);
   return v_role_name;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_role;
 
 
function get_other_roles(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** returns the OIM role for a user.
2017.09.13 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'get_other_roles';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_username varchar2(256 char);
  v_role_name varchar2(256 char);
begin
   select /*max(username),*/ max(other_roles) into /*v_username,*/ v_role_name from MD_USERS_V where username = upper(p_email);
   return v_role_name;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_other_roles;
 
 
function get_region(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** returns the user's Region; returns Null, if user does not exists.
2017.08.09 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'get_region';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_username varchar2(256 char);
  v_role_name varchar2(256 char);
begin
   select max(username), max(role_name) into v_username, v_role_name from MD_USERS_V where username = upper(p_email);
   return case when v_username is not null then nvl(trim(substr(v_role_name,1, instr(v_role_name,' ') ) ),'GLOBAL') end;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_region;
 
 
function has_region(p_region varchar2, p_email varchar2 default v('APP_USER')) return char deterministic is
/** searches the user's Region
2017.08.09 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'has_region';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  return case when get_region(p_email) = p_region then c_yes else c_no end;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end has_region;
 
 
procedure test_region(p_region varchar2, p_email varchar2 default v('APP_USER')) is
begin if has_region(p_region,p_email) = c_No then raise not_authorized; end if;
end test_region;
 
function get_all_directs (p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP  directs querrying; returns a colon-separated list. TODO: Optimization.
  2019.07.09 - 1.0 - András Tóth - create
  2020.05.15 - 1.1 - András Tóth - LDAP access method change
  2024.08.02 - 1.2 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'get_all_directs';
  c_proc_version constant varchar2(5 char) := '1.2';
  c_hv number := 571809934; /*ORA_HASH('get_all_directs')*/
  v_ln varchar2(50 char);
  v_directs varchar2(c_32k);
  v_recursive_directs varchar2(c_32k);
begin
  v_ln := 0;
 -- v_directs := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  v_ln := 1;
  -- cache hit
 -- if trim(v_directs) is not null then return v_directs; end if;
 
  v_ln := 2;
  SELECT upper(LISTAGG(emp_email_address, ':') WITHIN GROUP (ORDER BY emp_email_address)) AS email_list INTO v_directs
  FROM md_employees WHERE manager_email_address = p_email;

--   for i in (
--           SELECT upper(val) email FROM table(apex_ldap.search (
--             p_host => c_ldap_host,
--             p_username => c_ldap_username,
--             p_pass => c_ldap_key,
--             p_port => c_ldap_port,
--             p_use_ssl => c_ldap_use_ssl,
--             p_search_base=>c_ldap_search_base,
--             p_search_filter => 'manager='||
--               (
--                 SELECT dn FROM TABLE(apex_ldap.search(
--                   p_host => c_ldap_host,
--                   p_username => c_ldap_username,
--                   p_pass => c_ldap_key,
--                   p_port => c_ldap_port,
--                   p_use_ssl => c_ldap_use_ssl,
--                   p_search_base=>c_ldap_search_base,
--                   p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(upper(p_email))),
--                   p_attribute_names=>'manager'
--                 ))
--               )
--             ,
--             p_attribute_names => 'mail'
--           ))
--     ) loop
--       v_ln := 3;
--       v_directs := v_directs ||case when v_directs is not null then ':' end|| i.email;
--       v_ln := 4;
--       v_recursive_directs := get_all_directs(i.email);
--       v_ln := 5;
--       v_directs := v_directs ||case when v_recursive_directs is not null then ':' end|| v_recursive_directs;
--     end loop;
 
    v_ln := 6;
   -- cache_put_s(c_hv,p_email,v_directs);
    v_ln := 7;
    return v_directs;
exception
  when others then
    log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'['||v_ln||']('||p_email||','||v_directs||') '||get_sqlerrm(sqlcode),sqlcode);
    return null; /* null when not found or any error happened */
end get_all_directs;
 
function get_manager(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP manager querrying
2017.08.09 - 1.0 - András Tóth - create
2017.08.15 - 1.1 - András Tóth - caching
2018.03.29 - 1.2 - András Tóth - cache forget is not necessary any more
2018.04.19 - 1.3 - András Tóth - returns more than one row...
2018.04.26 - 1.4 - András Tóth - adding extra logs; adding email format check and return null if not @ORACLE...
2019.04.01 - 1.5 - András Tóth - updating the script from apex mailing list advice... - getting the mail directly from string
2019.04.22 - 1.6 - András Tóth - updating LDAP again.
2019.05.08 - 1.7 - András Tóth - better logs; not hiding duplication errors or missing data from logs, but hiding from user by returning null value. TODO: check if functionality change not causing problems elsewhere....
2020.05.15 - 1.8 - András Tóth - modification because of LDAP security changes.
2020.11.20 - 1.9 - András Tóth - do not put debug message into pcg_errors whenever it finds a non-existing employee.
2024.02.23 - 2.0 - Bhuvi Chauhan - LDAP seems to be not reutuning any data, so changes this to PAAS.
2025.05.27 - 2.1 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'get_manager';
  c_proc_version constant varchar2(5 char) := '2.1';
  v_manager varchar2(256 char);
  c_hv number := 652638039 /*ORA_HASH('get_manager')*/;
  v_tmp_base varchar2(c_32k);
  v_ln varchar2(50 char);
begin
    v_ln := 1;
    log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
      ,'Params: p_email='||p_email
      ,null,c_Debug);
    v_ln := 2;
    if trim(p_email) is null or upper(trim(p_email)) not like '%@ORACLE.COM' then return null; end if;
    v_ln := 3;
    -- get from cache:
    v_manager := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
    v_ln := 4;
 
    -- cache hit
    if v_manager is not null then return v_manager;
    -- cache fail
    else
      v_ln := 5;
       SELECT upper(manager_email_address) into v_manager
        FROM md_employees
        WHERE emp_email_address = lower(p_email);
        

    --   SELECT val into v_tmp_base FROM TABLE(apex_ldap.search(
    --     p_host => c_ldap_host,
    --     p_username => c_ldap_username,
    --     p_pass => c_ldap_key,
    --     p_port => c_ldap_port,
    --     p_use_ssl => c_ldap_use_ssl,
    --     p_search_base=>c_ldap_search_base,
    --     p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(upper(p_email))),
    --     p_attribute_names=>'manager'
    --   ));
    --   v_ln := 6;
    --   SELECT upper(val) into v_manager FROM table(apex_ldap.search (
    --     p_host => c_ldap_host,
    --     p_username => c_ldap_username,
    --     p_pass => c_ldap_key,
    --     p_port => c_ldap_port,
    --     p_use_ssl => c_ldap_use_ssl,
    --     p_search_base => v_tmp_base,
    --     p_search_filter => substr(v_tmp_base,1,instr(v_tmp_base,',')-1),
    --     p_attribute_names => 'mail'
    --   ));
      v_ln := 7;
      -- put to cache, (empty old cache data)
      cache_put_s(c_hv,p_email,v_manager);
      v_ln := 8;
      -- return
      return v_manager;
    end if;
exception
  when others then
    --log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'['||v_ln||']('||p_email||','||v_tmp_base||','||v_manager||') '||get_sqlerrm(sqlcode),sqlcode,c_Debug);
    return null; /* null when not found or any error happened */
end get_manager;
 
function get_country_code2 (p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying the Country Code
2018.02.05 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.2 - András Tóth - LDAP access method change
2021.05.21 - 1.3 - András Tóth - adding some more logs
2024.08.02 - 1.4 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
*/
  c_proc_name constant varchar2(61 char) := 'get_country_code2';
  c_proc_version constant varchar2(5 char) := '1.4';
  v_cc varchar2(256 char);
  c_hv number := 392588209 /*ORA_HASH('get_c_country_code')*/;
  v_ln varchar2(4000);
begin
    v_ln := 1;
    if trim(p_email) is null then return null; end if;
    v_ln := 2;
    -- get from cache:
  --  v_cc := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
   -- v_ln := 3;

    select trim(upper(COUNTRY)) into v_cc from MD_EMPLOYEES where upper(EMP_EMAIL_ADDRESS) = p_email;
 
    -- cache hit
    -- if v_cc is not null then return v_cc;
    -- v_ln := 4;
    -- -- cache fail
    -- else
    --   v_ln := 5;
    --   SELECT trim(upper(val)) into v_cc FROM TABLE (
    --         apex_ldap.search(
    --         p_host => c_ldap_host,
    --         p_username => c_ldap_username,
    --         p_pass => c_ldap_key,
    --         p_port => c_ldap_port,
    --         p_use_ssl => c_ldap_use_ssl,
    --         p_search_base=>c_ldap_search_base,
    --         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
    --         p_attribute_names => 'c')
    --         );
    --   v_ln := 6;
    --   -- put to cache, (empty old cache data)
    --   cache_put_s(c_hv,p_email,v_cc);
    --   v_ln := 7;
      -- return
      return v_cc;
   -- end if;
exception
  when DBMS_LDAP.general_error then return null; /* null when not found */
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'['||v_ln||'] '||get_sqlerrm(sqlcode)||', p_email='||p_email,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_code2;
 
 
function get_org(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying
2017.08.09 - 1.0 - András Tóth - create
2018.02.05 - 1.1 - András Tóth - adding cache
2018.03.29 - 1.2 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.3 - András Tóth - LDAP access method change
2024.08.02 - 1.4 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
*/
  c_proc_name constant varchar2(61 char) := 'get_org';
  c_proc_version constant varchar2(5 char) := '1.4';
  v_tmp  varchar2(32767 char);
  c_hv number := 390098251 /*ORA_HASH('get_org')*/;
begin
  if trim(p_email) is null then return null; end if;
--   v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
--   if v_tmp is not null then return v_tmp; end if;
   
  select LEGACY_COST_CENTER_NAME into v_tmp from MD_EMPLOYEES where upper(EMP_EMAIL_ADDRESS) = p_email;


--   SELECT max(val) into v_tmp FROM TABLE (
--         apex_ldap.search(
--         p_host => c_ldap_host,
--         p_username => c_ldap_username,
--         p_pass => c_ldap_key,
--         p_port => c_ldap_port,
--         p_use_ssl => c_ldap_use_ssl,
--         p_search_base=>c_ldap_search_base,
--         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
--         p_attribute_names => 'ou')
--         );
--   cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception
  when DBMS_LDAP.general_error then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_org;
 
function get_cost_center (p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying the cost center
2018.02.05 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2019.03.28 - 1.2 - András Tóth - adding max() in case of empty
2020.05.15 - 1.3 - András Tóth - LDAP access method change
2024.08.02 - 1.4 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
*/
  c_proc_name constant varchar2(61 char) := 'get_cost_center';
  c_proc_version constant varchar2(5 char) := '1.4';
  v_cc varchar2(256 char);
  c_hv number := 3691474518 /*ORA_HASH('get_cost_center')*/;
begin
    if trim(p_email) is null then return null; end if;
    -- get from cache:
    --v_cc := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
 
    -- cache hit
   -- if v_cc is not null then return v_cc;
    -- cache fail
    --else
 
 SELECT LEGACY_CC into v_cc from MD_EMPLOYEES where upper(EMP_EMAIL_ADDRESS) = p_email;
    --   SELECT trim(upper(max(val))) into v_cc FROM TABLE (
    --         apex_ldap.search(
    --         p_host => c_ldap_host,
    --         p_username => c_ldap_username,
    --         p_pass => c_ldap_key,
    --         p_port => c_ldap_port,
    --         p_use_ssl => c_ldap_use_ssl,
    --         p_search_base=>c_ldap_search_base,
    --         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
    --         p_attribute_names => 'orclcorpcostcenter')
    --         );
 
      -- put to cache, (empty old cache data)
     -- cache_put_s(c_hv,p_email,v_cc);
      -- return
      return v_cc;
  --  end if;
exception
  when DBMS_LDAP.general_error then return null; /* null when not found */
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_cost_center;
 
function get_uid (p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying the Computer login UID name.
2018.02.05 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.2 - András Tóth - LDAP Access Methods change
2026.07.31 - 1.3 - Pragya Kapoor - Remove dependency of LDAP; use MD_EMPLOYEES
*/
  c_proc_name constant varchar2(61 char) := 'get_uid';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_uid varchar2(256 char);
  c_hv number := 3237225601 /*ORA_HASH('get_uid')*/;
begin
    if trim(p_email) is null then return null; end if;
    -- get from cache:
    v_uid := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
 
    -- cache hit
    if v_uid is not null then return v_uid;
    -- cache fail
    else
        SELECT UPPER(TRIM(GUID)) into v_uid  
        FROM MD_EMPLOYEES WHERE UPPER(EMP_EMAIL_ADDRESS) = UPPER(p_email);
    --   SELECT trim(upper(val)) into v_uid FROM TABLE (
    --         apex_ldap.search(
    --         p_host => c_ldap_host,
    --         p_username => c_ldap_username,
    --         p_pass => c_ldap_key,
    --         p_port => c_ldap_port,
    --         p_use_ssl => c_ldap_use_ssl,
    --         p_search_base=>c_ldap_search_base,
    --         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
    --         p_attribute_names => 'uid')
    --         );
 
      -- put to cache, (empty old cache data)
      cache_put_s(c_hv,p_email,v_uid);
      -- return
      return v_uid;
    end if;
exception
  when DBMS_LDAP.general_error then return null; /* null when not found */
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_uid;
 
function get_title(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying
2017.08.09 - 1.0 - András Tóth - create
2018.02.05 - 1.1 - András Tóth - adding cache
2018.03.29 - 1.2 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.3 - András Tóth - LDAP Access Method chagne
2026.07.31 - 1.4 - Pragya Kapoor - Remove dependency of LDAP; use MD_EMPLOYEES
*/
  c_proc_name constant varchar2(61 char) := 'get_title';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_tmp  varchar2(32767 char);
  c_hv number := 1659894355 /*ORA_HASH('get_title')*/;
begin
  if trim(p_email) is null then return null; end if;
  v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;
    SELECT UPPER(TRIM(JOB_TITLE)) into v_tmp  
        FROM MD_EMPLOYEES WHERE UPPER(EMP_EMAIL_ADDRESS) = UPPER(p_email);
--   SELECT max(val) into v_tmp FROM TABLE (
--         apex_ldap.search(
--         p_host => c_ldap_host,
--         p_username => c_ldap_username,
--         p_pass => c_ldap_key,
--         p_port => c_ldap_port,
--         p_use_ssl => c_ldap_use_ssl,
--         p_search_base=>c_ldap_search_base,
--         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
--         p_attribute_names => 'title')
--         );
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception
  when DBMS_LDAP.general_error then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_title;
 
 
function get_emp_type(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying
2017.08.09 - 1.0 - András Tóth - create
2018.02.05 - 1.1 - András Tóth - adding cache
2018.03.29 - 1.2 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.3 - András Tóth LDAP Access Method change
2024.08.02 - 1.4 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
*/
  c_proc_name constant varchar2(61 char) := 'get_emp_type';
  c_proc_version constant varchar2(5 char) := '1.4';
  v_tmp  varchar2(32767 char);
  c_hv number :=  2823908118/*ORA_HASH('get_emp_type')*/;
begin
  if trim(p_email) is null then return null; end if;
--   v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
--   if v_tmp is not null then return v_tmp; end if;

  SELECT USER_PERSON_TYPE into v_tmp from MD_EMPLOYEES where upper(EMP_EMAIL_ADDRESS) = p_email;

--   SELECT max(val) into v_tmp FROM TABLE (
--         apex_ldap.search(
--         p_host => c_ldap_host,
--         p_username => c_ldap_username,
--         p_pass => c_ldap_key,
--         p_port => c_ldap_port,
--         p_use_ssl => c_ldap_use_ssl,
--         p_search_base=>c_ldap_search_base,
--         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
--         p_attribute_names => 'employeetype')
--         );
 -- cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception
  when DBMS_LDAP.general_error then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_emp_type;
 
 
function get_telephon(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying
2017.08.09 - 1.0 - András Tóth - create
2018.02.05 - 1.1 - András Tóth - adding cache
2018.03.29 - 1.2 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.3 - András Tóth - LDAP acccess Method change
*/
  c_proc_name constant varchar2(61 char) := 'get_telephon';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_tmp  varchar2(32767 char);
  c_hv number :=  537449609/*ORA_HASH('get_telephon')*/;
begin
  if trim(p_email) is null then return null; end if;
  v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;
  v_tmp := NULL;
--   SELECT max(val) into v_tmp FROM TABLE (
--         apex_ldap.search(
--         p_host => c_ldap_host,
--         p_username => c_ldap_username,
--         p_pass => c_ldap_key,
--         p_port => c_ldap_port,
--         p_use_ssl => c_ldap_use_ssl,
--         p_search_base=>c_ldap_search_base,
--         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
--         p_attribute_names => 'telephonenumber')
--         );
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception
--   when DBMS_LDAP.general_error then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_telephon;
 
function get_location (p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/* Deprecated */
  c_proc_name constant varchar2(61 char) := 'get_location';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'Deprecated function called by program :-( ',0);
  return get_city(p_email);
end;
 
function get_city(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying
2017.08.09 - 1.0 - András Tóth - create
2018.02.05 - 1.1 - András Tóth - adding cache
2018.03.29 - 1.2 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.3 - András Tóth - LDAP access method change
2024.08.02 - 1.4 - Bhuvi Chauhan - removing LDAP and using PAAS (MD_EMPLOYEES table).
*/
  c_proc_name constant varchar2(61 char) := 'get_city';
  c_proc_version constant varchar2(5 char) := '1.4';
  v_tmp  varchar2(32767 char);
  c_hv number :=  749136765/*ORA_HASH('get_location')*/;
begin
  if trim(p_email) is null then return null; end if;
  v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;
  
  select LOCATION_TOWN_OR_CITY into v_tmp from md_employees where upper(EMP_EMAIL_ADDRESS) = p_email;
  
--   SELECT max(val) into v_tmp FROM TABLE (
--         apex_ldap.search(
--         p_host => c_ldap_host,
--         p_username => c_ldap_username,
--         p_pass => c_ldap_key,
--         p_port => c_ldap_port,
--         p_use_ssl => c_ldap_use_ssl,
--         p_search_base=>c_ldap_search_base,
--         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
--         p_attribute_names => 'city')
--         );
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception
  when DBMS_LDAP.general_error then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_city;
 
 
function get_timezone(p_email varchar2 default v('APP_USER')) return varchar2 deterministic is
/** LDAP querrying
2017.08.09 - 1.0 - András Tóth - create
2018.02.05 - 1.1 - András Tóth - adding cache
2018.03.29 - 1.2 - András Tóth - cache forget is not necessary any more
2020.05.15 - 1.3 - András Tóth - LDAP acccess method changes
2026.07.31 - 1.4 - Pragya Kapoor - Remove dependency of LDAP
*/
  c_proc_name constant varchar2(61 char) := 'get_timezone';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_tmp  varchar2(32767 char);
  v_location_id VARCHAR2(100);
  l_clob      CLOB;
  l_clob_time CLOB;
  c_hv number :=  2501141355/*ORA_HASH('get_timezone')*/;
begin
  if trim(p_email) is null then return null; end if;
  v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;
    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?emailAddress='|| lower(p_email)
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    -- dbms_output.put_line(l_clob);        
    SELECT json_value(
         l_clob,
         '$.data[0].locationId'
         RETURNING NUMBER
       ) AS location_id into v_location_id
    FROM dual;
    dbms_output.put_line(v_location_id);     
    
    l_clob_time := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hrlocationservice?locationId='|| v_location_id
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    -- dbms_output.put_line(l_clob_time);   
    SELECT json_value(
         l_clob_time,
         '$.data[0].timezoneCode'
         RETURNING VARCHAR2(100)
       ) AS timezoneCode into v_tmp
    FROM dual;
--   SELECT max(val) into v_tmp FROM TABLE (
--         apex_ldap.search(
--         p_host => c_ldap_host,
--         p_username => c_ldap_username,
--         p_pass => c_ldap_key,
--         p_port => c_ldap_port,
--         p_use_ssl => c_ldap_use_ssl,
--         p_search_base=>c_ldap_search_base,
--         p_search_filter=>'mail='||apex_escape.ldap_search_filter(trim(p_email)),
--         p_attribute_names => 'orcltimezone')
--         );
   cache_put_s(c_hv,p_email,v_tmp);
   return v_tmp;
exception
  when DBMS_LDAP.general_error then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_timezone;
 
 
function cache_get_s(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return varchar2 is
/** returns the cache value
2017.08.15 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'cache_get_s';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_value varchar2 (32767 char);
begin
  select query_value_S into v_value from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param and load_time > p_date_after;
  return v_value;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_get_s;
 
 
function cache_get_n(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return number is
/** returns the cache value
2017.08.15 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'cache_get_n';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_value number;
begin
  select query_value_n into v_value from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param and load_time > p_date_after;
  return v_value;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_get_n;
 
 
function cache_get_d(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return date is
/** returns the cache value
2017.08.15 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'cache_get_d';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_value date;
begin
  select query_value_d into v_value from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param and load_time > p_date_after;
  return v_value;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_get_d;
 
 
function cache_get_t(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return timestamp is
/** returns the cache value
2017.08.15 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'cache_get_t';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_value timestamp;
begin
  select query_value_t into v_value from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param and load_time > p_date_after;
  return v_value;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_get_t;
 
 
function cache_get_c(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return clob is
/** returns the cache value
2017.08.15 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'cache_get_c';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_value clob;
begin
  select query_value_c into v_value from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param and load_time > p_date_after;
  return v_value;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_get_c;
 
 
function cache_get_b(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return blob is
/** returns the cache value
2017.08.15 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := 'cache_get_b';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_value blob;
begin
  select query_value_b into v_value from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param and load_time > p_date_after;
  return v_value;
exception
  when no_data_found then return null;
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_get_b;
 
 
procedure cache_forget(p_query_prog_id in number, p_query_param in varchar) is
/** delete the cache value
2017.08.15 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'cache_forget';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  delete from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param;
  commit;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_forget;
 
 
procedure cache_put_s(p_query_prog_id in number, p_query_param in varchar2, p_value varchar2) is
/** insert the cache value
Parameters are obligatory, cannot insert null into prog_id or query_param !!!! - no error message, just not caching valuesfor null inputs...
2017.08.15 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - delete existing value
2018.04.26 - 1.2 - András Tóth - adding extra logs
2018.05.02 - 1.3 - András Tóth - log only when error.
2021.10.06 - 1.4 - András Tóth - adding locking for the transaction.
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'cache_put_s';
  c_proc_version constant varchar2(5 char) := '1.4';
begin
  if p_query_prog_id is null or p_query_param is null then return; end if;
  begin
    lock table PCG_TMP_CACHE in SHARE MODE WAIT 5;
    delete from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param;
    insert into PCG_TMP_CACHE (load_time, query_prog_id, query_param, query_value_S) values (sysdate, p_query_prog_id, p_query_param, p_value);
    commit;
  end;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
    ,get_sqlerrm(sqlcode)||' Params received: p_query_prog_id='||to_char(p_query_prog_id)||', p_query_param='||p_query_param||', p_value='||p_value
    ,sqlcode);
  rollback;
  commit;
  --log(c_pkg_name||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_put_s;
 
 
procedure cache_put_n(p_query_prog_id in number, p_query_param in varchar2, p_value number) is
/** insert the cache value
2017.08.15 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - delete existing value b4 inserting
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'cache_put_n';
  c_proc_version constant varchar2(5 char) := '1.1';
begin
  if p_query_prog_id is null or p_query_param is null then return; end if;
  delete from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param;
  insert into PCG_TMP_CACHE (load_time, query_prog_id, query_param, query_value_n) values (sysdate, p_query_prog_id, p_query_param, p_value);
  commit;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_put_n;
 
 
procedure cache_put_d(p_query_prog_id in number, p_query_param in varchar2, p_value date) is
/** insert the cache value
2017.08.15 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - delete previous value b4 inserting
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'cache_put_d';
  c_proc_version constant varchar2(5 char) := '1.1';
begin
  if p_query_prog_id is null or p_query_param is null then return; end if;
  delete from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param;
  insert into PCG_TMP_CACHE (load_time, query_prog_id, query_param, query_value_d) values (sysdate, p_query_prog_id, p_query_param, p_value);
  commit;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_put_d;
 
 
procedure cache_put_t(p_query_prog_id in number, p_query_param in varchar2, p_value timestamp) is
/** insert the cache value
2017.08.15 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - delete previous value b4 inserting
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'cache_put_t';
  c_proc_version constant varchar2(5 char) := '1.1';
begin
  if p_query_prog_id is null or p_query_param is null then return; end if;
  delete from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param;
  insert into PCG_TMP_CACHE (load_time, query_prog_id, query_param, query_value_t) values (sysdate, p_query_prog_id, p_query_param, p_value);
  commit;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_put_t;
 
 
procedure cache_put_c(p_query_prog_id in number, p_query_param in varchar2, p_value clob) is
/** insert the cache value
2017.08.15 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - delete previous value b4 inserting
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'cache_put_c';
  c_proc_version constant varchar2(5 char) := '1.1';
begin
  if p_query_prog_id is null or p_query_param is null then return; end if;
  delete from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param;
  insert into PCG_TMP_CACHE (load_time, query_prog_id, query_param, query_value_c) values (sysdate, p_query_prog_id, p_query_param, p_value);
  commit;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_put_c;
 
 
procedure cache_put_b(p_query_prog_id in number, p_query_param in varchar2, p_value blob) is
/** insert the cache value
2017.08.15 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - delete previous value before inserting a new
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'cache_put_b';
  c_proc_version constant varchar2(5 char) := '1.1';
begin
  if p_query_prog_id is null or p_query_param is null then return; end if;
  delete from PCG_TMP_CACHE where query_prog_id = p_query_prog_id and p_query_param = query_param;
  insert into PCG_TMP_CACHE (load_time, query_prog_id, query_param, query_value_b) values (sysdate, p_query_prog_id, p_query_param, p_value);
  commit;
exception
  when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end cache_put_b;
 
 
function read_sec_blob(p_param in varchar2) return varchar2 deterministic is
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := 'read_sec_blob';
  c_proc_version constant varchar2(5 char) := '1.0';
  l_compressed_blob BLOB;
  l_uncompressed_blob BLOB;
begin
  l_uncompressed_blob := TO_BLOB('0');
  select secret into l_compressed_blob from MD_SEC where id = p_param;
  UTL_COMPRESS.lz_uncompress (src => l_compressed_blob,
                            dst => l_uncompressed_blob);
  return trim(utl_raw.cast_to_varchar2(dbms_lob.substr(l_uncompressed_blob)));
exception
  when others then log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  raise;
end read_sec_blob;
 
 
procedure lov_add(p_name in varchar2, p_lov_type in varchar2, p_display_name in varchar2 default null, p_tags in varchar2 default null) is
/* Create a new named list of value */
pragma autonomous_transaction;
begin insert into MD_LOVS (name,lov_type,display_name,tags) values(p_name,p_lov_type,p_display_name,p_tags); commit;
end lov_add;
 
 
function lov_add(p_name in varchar2, p_lov_type in varchar2, p_display_name in varchar2 default null, p_tags in varchar2 default null) return number is
/* Create a new named list of value */
pragma autonomous_transaction;
  v_tmp number;
begin insert into MD_LOVS (name,lov_type,display_name,tags) values(p_name,p_lov_type,p_display_name,p_tags) returning id into v_tmp; commit; return v_tmp;
end lov_add;
 
 
procedure lov_delete(p_id in number) is
/* Set the deleted_sign of a LOV */
pragma autonomous_transaction;
begin update MD_LOVS set deleted_sign = 'Y' where id = p_id; commit;
end lov_delete;
 
 
procedure lov_force_delete(p_id in number) is
/* Delete a LOV */
pragma autonomous_transaction;
begin delete from MD_LOVS where id = p_id; commit;
end lov_force_delete;
 
 
function lov_get_id_by_name(p_name in varchar2) return number is
/* query the ID of a LOV by name */
  v_tmp number;
begin select id into v_tmp from MD_LOVS where name = p_name; return v_tmp;
exception when no_data_found then return null;
end lov_get_id_by_name;
 
 
procedure lov_add_value(p_lov_id in number, p_lov_value in varchar2, p_display_value in varchar2 default null, p_value_order in number default null, p_tags in varchar2 default null) is
/* Create a LOV VALUE item */
pragma autonomous_transaction;
begin  insert into MD_LOV_VALUES (lov_id, lov_value, display_value, value_order, tags) values (p_lov_id, p_lov_value, p_display_value, p_value_order, p_tags); commit;
end lov_add_value;
 
 
function lov_add_value(p_lov_id in number, p_lov_value in varchar2, p_display_value in varchar2 default null, p_value_order in number default null, p_tags in varchar2 default null) return number is
/* Create a LOV VALUE item */
  v_tmp number;
pragma autonomous_transaction;
begin insert into MD_LOV_VALUES (lov_id, lov_value, display_value, value_order, tags) values (p_lov_id, p_lov_value, p_display_value, p_value_order, p_tags) returning id into v_tmp; commit; return v_tmp;
end lov_add_value;
 
 
procedure lov_delete_value(p_id in number) is
/* Set the deleted sign of LOV VALUE */
pragma autonomous_transaction;
begin update MD_LOV_VALUES set deleted_sign = 'Y' where id = p_id; commit;
end lov_delete_value;
 
 
procedure lov_force_delete_value(p_id in number) is
/* Delete LOV VALUE */
pragma autonomous_transaction;
begin delete from MD_LOV_VALUES where id = p_id; commit;
end lov_force_delete_value;
 
 
function lov_get_value_id_by_name(p_name in varchar2, p_lov_id in number default null) return number is
/* Get the ID by the unique name; search globaly or in the LOV */
v_tmp number;
begin select id into v_tmp from MD_LOV_VALUES where lov_value = p_name and (p_lov_id is null or lov_id = p_lov_id); return v_tmp;
exception when  no_data_found then return null;
end lov_get_value_id_by_name;
 
 
procedure lov_2_lov_link(p_lov_value_id in number, p_casc_lov_id in number) is
/* Create directed link between two LOVs */
pragma autonomous_transaction;
begin insert into MD_LOV_CASCADES (lov_value_id, casc_lov_id) values (p_lov_value_id, p_casc_lov_id); commit;
end lov_2_lov_link;
 
 
procedure lov_2_lov_unlink(p_lov_value_id in number, p_casc_lov_id in number) is
/* Set the deleted_sign for a link between two LOVs */
pragma autonomous_transaction;
begin update MD_LOV_CASCADES set deleted_sign = 'Y' where lov_value_id = p_lov_value_id and casc_lov_id = p_casc_lov_id; commit;
end lov_2_lov_unlink;
 
 
procedure lov_2_lov_force_unlink(p_lov_value_id in number, p_casc_lov_id in number) is
/* Delete permanently a link between two LOVs */
pragma autonomous_transaction;
begin delete from MD_LOV_CASCADES where lov_value_id = p_lov_value_id and casc_lov_id = p_casc_lov_id; commit;
end lov_2_lov_force_unlink;
 
 
function has_lov_2_lov_link(p_lov_value_id in number, p_casc_lov_id in number) return char is
/* returns Y if the link exists */
  v_tmp number;
begin
  select 1 into v_tmp from MD_LOV_CASCADES where lov_value_id = p_lov_value_id  and casc_lov_id = p_casc_lov_id and deleted_sign is null;
  return 'Y';
exception when no_data_found then return 'N';
end has_lov_2_lov_link;
 
 
function has_lov_2_lov_link_D(p_lov_value_id in number, p_casc_lov_id in number) return char is
/* returns Y if the link exists, even when was soft deleted */
  v_tmp number;
begin
  select 1 into v_tmp from MD_LOV_CASCADES where lov_value_id = p_lov_value_id  and casc_lov_id = p_casc_lov_id;
  return 'Y';
exception when no_data_found then return 'N';
end has_lov_2_lov_link_D;
 
 
function get_lov_name(p_id number) return varchar2 is
  v_name varchar2(32767 char);
begin
  select name into v_name from md_lovs where id = p_id;
  return v_name;
exception when no_data_found then return null;
end get_lov_name;
 
 
function get_lov_display_name(p_id number) return varchar2 is
  v_display_name varchar2(32767 char);
begin
  select display_name into v_display_name from md_lovs where id = p_id;
  return v_display_name;
exception when no_data_found then return null;
end get_lov_display_name;
 
 
function get_lov_type(p_id number) return varchar2 is
  v_type varchar2(32767 char);
begin
  select lov_type into v_type from md_lovs where id = p_id;
  return v_type;
exception when no_data_found then return null;
end get_lov_type;
 
 
function get_lov_tags(p_id number) return varchar2 is
  v_tags varchar2(32767 char);
begin
  select tags into v_tags from md_lovs where id = p_id;
  return v_tags;
exception when no_data_found then return null;
end get_lov_tags;
 
 
function get_lov_value_lov_id(p_id number) return number is
  v_lov_id number;
begin
  select lov_id into v_lov_id from md_lov_values where id = p_id;
  return v_lov_id;
exception when no_data_found then return null;
end get_lov_value_lov_id;
 
 
function get_lov_value_name(p_id number) return varchar2 is
  v_value_name varchar2(32767 char);
begin
  select lov_value into v_value_name from md_lov_values where id = p_id;
  return v_value_name;
exception when no_data_found then return null;
end get_lov_value_name;
 
 
function get_lov_value_display_name(p_id number) return varchar2 is
  v_disp_name varchar2(32767 char);
begin
  select display_value into v_disp_name from md_lov_values where id = p_id;
  return v_disp_name;
exception when no_data_found then return null;
end get_lov_value_display_name;
 
 
function get_lov_value_order(p_id number) return number is
  v_order number;
begin
  select value_order into v_order from md_lov_values where id = p_id;
  return v_order;
exception when no_data_found then return null;
end get_lov_value_order;
 
 
function get_lov_value_tags(p_id number) return varchar2 is
  v_tags varchar2(32767 char);
begin
  select tags into v_tags from md_lov_values where id = p_id;
  return v_tags;
exception when no_data_found then return null;
end get_lov_value_tags;
 
 
procedure set_lov_name(p_id number, p_new_value varchar2) is
  pragma autonomous_transaction;
begin update md_lovs set name = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_display_name(p_id number, p_new_value varchar2) is
pragma autonomous_transaction;
begin update md_lovs set display_name = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_type(p_id number, p_new_value varchar2) is
pragma autonomous_transaction;
begin update md_lovs set lov_type = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_tags(p_id number, p_new_value varchar2) is
pragma autonomous_transaction;
begin update md_lovs set tags = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_value_lov_id(p_id number, p_new_value number) is
pragma autonomous_transaction;
begin update md_lov_values set lov_id = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_value_name(p_id number, p_new_value varchar2) is
pragma autonomous_transaction;
begin update md_lov_values set lov_value = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_value_display_name(p_id number, p_new_value varchar2) is
pragma autonomous_transaction;
begin update md_lov_values set display_value = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_value_order(p_id number, p_new_value number) is
pragma autonomous_transaction;
begin update md_lov_values set value_order = p_new_value where id = p_id; commit; end;
 
 
procedure set_lov_value_tags(p_id number, p_new_value varchar2) is
pragma autonomous_transaction;
begin update md_lov_values set tags = p_new_value where id = p_id; commit; end;
 
 
function tree_create(p_name in varchar2, p_description in varchar2 default null) return number is
/* Create a new tree */
pragma autonomous_transaction;
v_tmp number;
begin insert into MD_TREES (name, description) values (p_name, p_description) returning id into v_tmp; commit; return v_tmp;
end tree_create;
 
 
function tree_leaf_create(p_tree_id in number, p_parent_id in number, p_name in varchar2) return number is
/* Create a new tree leaf */
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'tree_leaf_create';
pragma autonomous_transaction;
v_tmp number;
begin insert into MD_TREE_LEAVES (tree_id, parent_id, name) values (p_tree_id, p_parent_id, p_name) returning id into v_tmp; commit; return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
    ,get_sqlerrm(sqlcode)||' - p_tree_id='||to_char(p_tree_id)||', p_parent_id='||to_char(p_parent_id)||', p_name='||to_char(p_name)
    ,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end tree_leaf_create;
 
 
procedure tree_delete(p_id in number) is
/* Set the tree to be deleted */
pragma autonomous_transaction;
begin update MD_TREES set deleted_sign = 'Y' where id = p_id; commit;
end tree_delete;
 
 
procedure tree_deep_delete(p_id in number) is
/* Delete Tree and all leaves */
pragma autonomous_transaction;
begin delete from MD_TREES where id = p_id; commit;
end tree_deep_delete;
 
 
procedure tree_leaf_delete(p_id in number) is
/* set a leaf to be deleted */
pragma autonomous_transaction;
begin update MD_TREE_LEAVES set deleted_sign = 'Y' where id = p_id; commit;
end tree_leaf_delete;
 
 
procedure tree_leaf_deep_delete(p_id in number) is
/* Delete leaves */
pragma autonomous_transaction;
begin delete from MD_TREE_LEAVES where id = p_id; commit;
end tree_leaf_deep_delete;
 
 
procedure tree_leaf_move(p_id in number, p_new_parent_id in number) is
pragma autonomous_transaction;
begin update MD_TREE_LEAVES set parent_id = p_new_parent_id where id = p_id; commit;
end tree_leaf_move;
 
 
procedure tree_leaf_mod_name(p_id in number, p_new_name in varchar2) is
pragma autonomous_transaction;
begin update MD_TREE_LEAVES set name = p_new_name where id = p_id; commit;
end tree_leaf_mod_name;
 
 
procedure tree_mod_name(p_id in number, p_new_name in varchar2) is
pragma autonomous_transaction;
begin update MD_TREES set name = p_new_name where id = p_id; commit;
end tree_mod_name;
 
 
procedure tree_mod_desc(p_id in number, p_new_description in varchar2) is
pragma autonomous_transaction;
begin update MD_TREES set description = p_new_description where id = p_id; commit;
end tree_mod_desc;
 
 
function is_tree_leaf(p_id in number) return char is
/* returns Y or N if the element is a leaf. returns null if it does not exist.*/
  v_id number;
begin
  select 1 into v_id from MD_TREE_LEAVES where id = p_id;
  select max(parent_id) into v_id from MD_TREE_LEAVES where parent_id = p_id;
  return case when v_id is null then 'Y' else 'N' end;
exception when no_data_found then return null;
end is_tree_leaf;
 
 
function is_tree_root(p_id in number) return char is
/* returns Y or N if the element is a root. returns null if it does not exist.*/
  v_parent_id number;
begin
  select parent_id into v_parent_id from MD_TREE_LEAVES where id = p_id;
  return case when v_parent_id is null then 'Y' else 'N' end;
exception when no_data_found then return null;
end is_tree_root;
 
 
function get_tree_leaf_name(p_id in number, p_tree_id in number default null) return varchar2 is
/* returns the parent_id of a tree leaf; null if does not exist */
  v_name varchar2(4000 char);
begin
  select max(name) into v_name from MD_TREE_LEAVES where id = p_id and (p_tree_id is null or p_tree_id = tree_id);
  return v_name;
exception when no_data_found then return null;
end get_tree_leaf_name;
 
 
function get_tree_leaf_parent(p_id in number) return number is
/* returns the parent_id of a tree leaf; null if does not exist */
  v_parent_id number;
begin
  select parent_id into v_parent_id from MD_TREE_LEAVES where id = p_id;
  return v_parent_id;
exception when no_data_found then return null;
end get_tree_leaf_parent;
 
 
function get_tree_leaf_root(p_id in number) return number is
/* returns the root element ID of a tree where the given leaf element is; it returns itself if it is a root element */
  v_parent_id number;
begin
  v_parent_id := get_tree_leaf_parent(p_id);
  if v_parent_id is null then return p_id;
  else return get_tree_leaf_root(v_parent_id);
  end if;
end get_tree_leaf_root;
 
 
function get_tree_leaf_id(p_leaf_name in varchar2, p_tree_id in number default null) return number is
/* finds and returns the id of a leaf by name */
  v_id number;
begin
  select id into v_id from MD_TREE_LEAVES where name = p_leaf_name and (p_tree_id is null or tree_id = p_tree_id);
  return v_id;
exception when no_data_found then return null;
end get_tree_leaf_id;
 
 
function tree_leaf_2_path(p_leaf_id in number) return varchar2 is
/* Returns the path string to display of the given tree leaf */
  v_tmp varchar2(32767 char);
begin
  SELECT SYS_CONNECT_BY_PATH(name, ' --> ') tree_leaf_path into v_tmp
    FROM md_tree_leaves where id = p_leaf_id
    START WITH parent_id is null
    CONNECT BY NOCYCLE PRIOR id = parent_id;
  return v_tmp;
exception when no_data_found then return null;
end tree_leaf_2_path;
 
/* -- Tree Test:
declare v_tree_id number; v_leaf_id number; v_tmp number;
begin
--return;
v_tree_id :=pcg.tree_create('Test Tree',null);
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'alma');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'körte');
v_tmp := v_leaf_id;
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_tmp, 'kis körte');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_tmp, 'nagy körte');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_leaf_id, 'kukac');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'narancs');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'paradicsom');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_leaf_id , 'zöld');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_leaf_id , 'mélyzöld');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_leaf_id , 'rodhadó');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_leaf_id , 'bűzlő');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_leaf_id , 'savanyú');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'krumpli');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'füge');
 
v_tree_id :=pcg.tree_create('Test Tree 2',null);
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'alma');
v_leaf_id := pcg.tree_leaf_create(v_tree_id, null, 'körte');
v_tmp := v_leaf_id;
v_leaf_id := pcg.tree_leaf_create(v_tree_id, v_tmp, 'kis körte');
 
end;
*/
 
 
function get_country_headcount_force(p_country_id in number, p_max_date in date default sysdate) return number is
/* Get most accurate country-headcount available for a given country on a given date (last modified hc b4 max_date or first modified after max_date )
   Note: this will try to get the historical data even if the value was deleted!
*/
  v_hc number;
begin
  -- if actual is needed, then search the actual-table:
  if to_char(p_max_date,'YYYY-MM-DD') = to_char(sysdate,'YYYY-MM-DD') then
    select max(headcount) into v_hc from MD_COUNTRY_HEADCOUNTS where country_id = p_country_id;
    if v_hc is not null then return v_hc; end if;
  end if;
 
  -- when not found in actual-table or historical data is needed, search the most accurate available in the past.
  select headcount into v_hc from (
    select headcount, row_number() over (partition by country_id order by PCGH_LOAD_TIME desc) rn from MD_COUNTRY_HEADCOUNTS_h
           where p_max_date >= PCGH_LOAD_TIME and p_country_id = country_id and PCGH_DELETED is null
  ) where rn = 1;
  return v_hc;
exception when no_data_found then
  begin
    select headcount into v_hc from (
      select headcount, row_number() over (partition by country_id order by PCGH_LOAD_TIME asc) rn from MD_COUNTRY_HEADCOUNTS_h
             where p_country_id = country_id and PCGH_DELETED is null
    ) where rn = 1;
    return v_hc;
  exception when no_data_found then return null;
  end;
end get_country_headcount_force;
 
 
function get_country_headcount(p_country_id in number) return number is
/* returns the actual Head Count of a Country/Region if available
   TODO: this solution may be implemented through HR link. */
v_hc number; begin select max(headcount) into v_hc from MD_COUNTRY_HEADCOUNTS where country_id = p_country_id; return v_hc; end;
 
 
function timestamp_diff(p_start_time in timestamp, p_end_time in timestamp, p_unit in varchar2 default 'MILISECONDS') return number deterministic is
/* Returns the difference between 2 timestamps */
v_diff number;
begin
  select extract( day from diff )*24*60*60*1000 +
       extract( hour from diff )*60*60*1000 +
       extract( minute from diff )*60*1000 +
       round(extract( second from diff )*1000)
       into v_diff /* miliseconds */
  from (select p_end_time - p_start_time diff from dual);
 
  return case p_unit
     when 'MILISECONDS' then v_diff
     when 'SECONDS' then v_diff / 1000
     when 'MINUTES' then v_diff / 1000 / 60
     when 'HOURS' then v_diff / 1000 / 60 / 60
     when 'DAYS' then v_diff / 1000 / 60 / 60 / 24
     when 'WEEKS' then v_diff / 1000 / 60 / 60 / 24 / 7
     when 'MONTHS' then v_diff / 1000 / 60 / 60 / 24 / 30
     when 'YEARS' then v_diff / 1000 / 60 / 60 / 24 / 365
     else null
  end;
end timestamp_diff;
 
function employee_number_2_SSO (p_employee_number varchar2, p_business_group_id in number default null, p_attempt_number in number default 1) return varchar2 deterministic is
/** Employee Number 2 SSO conversion, query from database.
2017.05.22 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2018.04.27 - 1.2 - András Tóth - adding security_group_id setting...
2019.04.03 - 1.3 - András Tóth - adding Business Group ID
2022.01.10 - 1.4 - András Tóth - adding attempts.
2025.05.27 - 1.5 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'employee_number_2_SSO';
  c_proc_version constant varchar2(5 char) := '1.5';
  c_hv number := 1190978789/*ORA_HASH('employee_number_2_SSO')*/;
  v_tmp varchar2(256 char);
begin
  if trim(p_employee_number) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
 
  wwv_flow_api.set_security_group_id;
 
  v_tmp := cache_get_s(c_hv,p_employee_number,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;
 
SELECT max(upper(trim(EMP_EMAIL_ADDRESS ))) into V_TMP
FROM md_employees
WHERE GSI_EMPLOYEE_NUMBER = trim(p_employee_number);

--   if is_prod_env = c_YES then
--     SELECT upper(col_1) into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_PROD,
--     'select max(upper(trim(email_address))) from (
--      select ppl_emp.email_address, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and'
--         ||case when p_business_group_id is not null then ' ppl_emp.business_group_id = '||p_business_group_id||' and ' end||
--         'assign.primary_flag      = ''Y'' and
--         employee_number = '''||trim(p_employee_number)||'''
--     )
--     where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT upper(col_1) into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--     'select max(upper(trim(email_address))) from (
--      select ppl_emp.email_address, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and'
--         ||case when p_business_group_id is not null then ' ppl_emp.business_group_id = '||p_business_group_id||' and ' end||
--         'assign.primary_flag      = ''Y'' and
--         employee_number = '''||trim(p_employee_number)||'''
--     )
--     where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT upper(col_1) into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--     'select max(upper(trim(email_address))) from (
--      select ppl_emp.email_address, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_DATA_V  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V  assign
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and'
--         ||case when p_business_group_id is not null then ' ppl_emp.business_group_id = '||p_business_group_id||' and ' end||
--         'assign.primary_flag      = ''Y'' and
--         employee_number = '''||trim(p_employee_number)||''' and
--         ppl_emp.user_person_type = ''Employee''
--     )
--     where rn = 1'
--     ));
--   end if;
 
  cache_put_s(c_hv,p_employee_number,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||'p_employee_number='||p_employee_number||' p_business_group_id='||to_char(p_business_group_id)||' '||get_sqlerrm(sqlcode),sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then employee_number_2_SSO(p_employee_number, p_business_group_id, p_attempt_number + 1) else null end;
end employee_number_2_SSO;
 
function get_hire_date(p_sso in varchar2, p_attempt_number in number default 1) return varchar2 deterministic is
/** get HR Hire Date of Employee
2018.09.07 - 1.0 - András Tóth - create
2022.01.10 - 1.1 - András Tóth - adding attempts.
2025.05.27 - 1.2 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'get_hire_date';
  c_proc_version constant varchar2(5 char) := '1.2';
  c_hv number := 1860354330/*ORA_HASH('get_hire_date')*/;
  v_tmp varchar2(100 char);
begin
  if trim(p_sso) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
 
  wwv_flow_api.set_security_group_id;
 
--   v_tmp := cache_get_s(c_hv,p_sso,sysdate-c_cache_ldap_expire_days);
--   if v_tmp is not null then return v_tmp; end if;
 
SELECT UPPER(TO_CHAR(MIN(TO_DATE(HIRE_DATE, 'MM-DD-YYYY')), 'YYYY-MM-DD')) into V_TMP
FROM md_employees
WHERE EMP_EMAIL_ADDRESS = lower(trim(p_sso));


--   if is_prod_env = c_YES then
--     SELECT upper(col_1) into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_PROD,
--     'select to_char(min(ORIGINAL_DATE_OF_HIRE),''YYYY-MM-DD'') from HR_PEOPLE_L1_L2_L3_DATA_V_GCW where upper(email_address) = '''||upper(trim(p_sso))||''' and sysdate between effective_start_date and effective_end_date'));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT upper(col_1) into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--     'select to_char(min(ORIGINAL_DATE_OF_HIRE),''YYYY-MM-DD'') from HR_PEOPLE_L1_L2_L3_DATA_V_GCW where upper(email_address) = '''||upper(trim(p_sso))||''' and sysdate between effective_start_date and effective_end_date'));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT upper(col_1) into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--     'select to_char(min(ORIGINAL_DATE_OF_HIRE),''YYYY-MM-DD'') from HR_PEOPLE_L1_L2_DATA_V where upper(email_address) = '''||upper(trim(p_sso))||''' and sysdate between effective_start_date and effective_end_date'));
--   end if;
 
--   cache_put_s(c_hv,p_sso,v_tmp);
  return v_tmp;
 
exception when others then
  --log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
    ,'(attempt_#: '||to_char(p_attempt_number)||') '||SQLERRM||' variables: p_sso='||p_sso||', v_tmp='||v_tmp
    ,sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then get_hire_date(p_sso, p_attempt_number + 1) else null end;
 
end get_hire_date;
 
function sso_2_employee_number (p_sso in varchar2, p_e in char default 'N', p_attempt_number in number default 1) return varchar2 deterministic is
/** SSO to Employee Number conversion, query from database.
2017.05.22 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2018.04.26 - 1.2 - András Tóth - adding extra logging.
2020.04.27 - 1.3 - András Tóth - correcting the production query from Ida Bereczky's GSI query: adding employee_type flag.
2020.05.15 - 1.4 - András Tóth - Syntax error in remote sql call.
2022.01.10 - 1.5 - András Tóth - adding attempts. remove debug log
2024.11.13 - 1.6 - Bhuvi Chauhan - Removing/Commenting this cache_get_s/cache_put_s as now we are using paas also this is refered from STAA pkg 
2025.05.27 - 1.7 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'sso_2_employee_number';
  c_proc_version constant varchar2(5 char) := '1.7';
  c_hv number := 1548675276/*ORA_HASH('sso_2_employee_number')*/;
  v_tmp varchar2(256 char);
begin
 
  /*
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
    ,'Params: p_sso='||p_sso||', p_e='||p_e
    ,null,c_Debug);
  */
 
  if trim(p_sso) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
 
--   v_tmp := cache_get_s(c_hv,p_sso,sysdate-c_cache_ldap_expire_days);
--   if v_tmp is not null then return v_tmp; end if;

  SELECT max(GSI_EMPLOYEE_NUMBER) into v_tmp
  FROM md_employees
  WHERE EMP_EMAIL_ADDRESS = lower(p_sso);
 
--   if is_prod_env = c_YES then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_PROD,
--     'select max(employee_number) from (
--      select employee_number, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''''||
--         case when p_e = 'Y' then ' and assign.assignment_type = ''E'' ' end||'
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select max(employee_number) from (
--      select employee_number, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||'''
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select max(employee_number) from (
--      select employee_number, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_DATA_V  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V  assign
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         ppl_emp.user_person_type = ''Employee''
--       )
--       where rn = 1'
--     ));
--   end if;
 
--   cache_put_s(c_hv,p_sso,v_tmp);
  return v_tmp;
exception when others then
  --log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
    ,'(attempt_#: '||to_char(p_attempt_number)||') '||SQLERRM||' - variables: p_sso='||p_sso||', v_tmp='||v_tmp
    ,sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then sso_2_employee_number (p_sso, p_e, p_attempt_number + 1) else null end;
end sso_2_employee_number;
 
function is_prod_env return char deterministic is
/** Returns if the environment is product environment or not.
2017.03.14 - 1.0 - András Tóth - create procedure
2018.04.27 - 1.2 - András Tóth - adding log; adding pragma; calling security_id.
2018.05.02 - 1.3 - András Tóth - adding ws_id generation and removing the extra logs.
2019.02.28 - 1.4 - András Tóth - schema identification - in case of no APEX environment is running; no autonomous.
2019.03.28 - 1.5 - András Tóth - log update
*/
--pragma autonomous_transaction;
  c_proc_version constant varchar2(5 char) := '1.5';
  c_proc_name constant varchar2(30 char) := 'is_prod_env';
  v_ret varchar2(2);
begin
 
  if trim(c_WS_ID) is null or trim(c_WS_ID) = '0' then -- set up constants manualy if not set yet:
    wwv_flow_api.set_security_group_id;
    c_WS_ID := trim(v('WORKSPACE_ID'));
    c_WS_NAME := trim(APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID')));
    if trim(c_WS_ID) is null or trim(c_WS_ID) = '0' then
      c_WS_ID := case when SYS_CONTEXT('USERENV','CURRENT_SCHEMA') = 'PAYROLL_PRODUCTION' then c_Prod_WS_ID else c_Test_WS_ID end;
    end if;
    if trim(c_WS_NAME) is null then
      c_WS_NAME := case when SYS_CONTEXT('USERENV','CURRENT_SCHEMA') = 'PAYROLL_PRODUCTION' then c_Prod_WS_NAME else c_Test_WS_NAME end;
    end if;
  end if;
 
  v_ret := case when c_Prod_WS_ID = c_WS_ID then c_YES else c_NO end;
 
  log(c_pkg_name||'.'||c_proc_name,c_version,c_proc_version
    ,'IDs set: WS_ID='||v('WORKSPACE_ID')||', c_WS_ID='||c_WS_ID||', v_ret='||v_ret
    ,null,c_Debug);
 
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end is_prod_env;
 
function get_hr_entity_code (p_email in varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic is
/** return Entity of employee from HR Secure Views.
2021.11.17 - 1.0 - András Tóth - create procedure
2021.12.02 - 1.1 - András Tóth - correcting data type from number to varchar, correcting filters
2022.01.10 - 1.2 - András Tóth - adding attempts. Adding PU Filter, primary_flag
2025.05.27 - 1.3 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_version constant varchar2(5 char) := '1.3';
  c_proc_name constant varchar2(30 char) := 'get_hr_entity_code';
  c_hv number := 417955603 /*ORA_HASH('get_hr_entity_code')*/;
  v_tmp varchar2(4000 char);
begin
  if trim(p_email) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
  v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;

  SELECT jt.Company_code into v_tmp
  FROM dual
  CROSS JOIN JSON_TABLE(
     get_hr_paas_data(p_email),
    '$.data[*]'
  COLUMNS (
    Company_code VARCHAR2(240) PATH '$.companyCode'
  )
) jt;
 
--   if is_prod_env = c_YES then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_PROD,
--         'select
--         org.company
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_BUSINESS_GROUPS_LOOKUP_V pbg
--         ,HR_ORGANIZATION_LOOKUP_V org
--         ,HR_PERSON_TYPES_LOOKUP_V ppl_typ
--         ,HR_PERSON_TYPE_USAGES_L1_L2_V pu
--         where
--         hp_emp.person_id = ha.person_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and sysdate  between  pu.effective_start_date  and  pu.effective_end_date
--         and hp_emp.business_group_id = pbg.business_group_id
--         and ha.organization_id    = org.organization_id
--         and hp_emp.current_employee_flag = ''Y''
--         and pu.PERSON_TYPE_ID = ppl_typ.person_type_id
--         and ppl_typ.user_person_type != ''Contractor''
--         and ppl_typ.system_person_type = ''EMP''
--         and pu.PERSON_ID = hp_emp.person_id
--         --and asg.assignment_type = ''E''
--         and ha.primary_flag = ''Y''
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         org.company
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_BUSINESS_GROUPS_LOOKUP_V pbg
--         ,HR_ORGANIZATION_LOOKUP_V org
--         ,HR_PERSON_TYPES_LOOKUP_V ppl_typ
--         ,HR_PERSON_TYPE_USAGES_L1_L2_V pu
--         where
--         hp_emp.person_id = ha.person_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and sysdate  between  pu.effective_start_date  and  pu.effective_end_date
--         and hp_emp.business_group_id = pbg.business_group_id
--         and ha.organization_id    = org.organization_id
--         and hp_emp.current_employee_flag = ''Y''
--         and pu.PERSON_TYPE_ID = ppl_typ.person_type_id
--         and ppl_typ.user_person_type != ''Contractor''
--         and ppl_typ.system_person_type = ''EMP''
--         and pu.PERSON_ID = hp_emp.person_id
--         --and asg.assignment_type = ''E''
--         and ha.primary_flag = ''Y''
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         org.company
--         from
--         HR_PEOPLE_L1_L2_DATA_V hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V ha
--         ,HR_BUSINESS_GROUPS_LOOKUP_V pbg
--         ,HR_ORGANIZATION_LOOKUP_V org
--         where
--         hp_emp.person_id = ha.person_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and hp_emp.business_group_id = pbg.business_group_id
--         and ha.organization_id    = org.organization_id
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   end if;
 
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||p_email||'-'||get_sqlerrm(sqlcode),sqlcode);
  if upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then 
    return get_hr_entity_code(p_email, p_attempt_number + 1);
  else
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,p_email||'-'||get_SQLERRM(SQLCODE)); else raise; end if;
  end if;
end get_hr_entity_code;
 
function get_hr_entity_name (p_email in varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic is
/** return Entity of employee from HR Secure Views.
2021.11.17 - 1.0 - András Tóth - create procedure
2021.12.02 - 1.1 - András Tóth - correcting filters
2022.01.10 - 1.2 - András Tóth - adding attempts. adding PU filter, primary_flag
2025.05.27 - 1.3 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_version constant varchar2(5 char) := '1.3';
  c_proc_name constant varchar2(30 char) := 'get_hr_entity_name';
  c_hv number := 75656383 /*ORA_HASH('get_hr_entity_name')*/;
  v_tmp varchar2(4000 char);
begin
  if trim(p_email) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
  v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;

  SELECT jt.Legal_Entity_Name into v_tmp
FROM dual
CROSS JOIN JSON_TABLE(
  PCG.get_hr_paas_data(trim(p_email)),
  '$.data[*]'
  COLUMNS (
    Legal_Entity_Name VARCHAR2(240) PATH '$.legalEntityName'
  )
) jt;
 
--   if is_prod_env = c_YES then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_PROD,
--         'select
--         pbg.name
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_BUSINESS_GROUPS_LOOKUP_V pbg
--         ,HR_ORGANIZATION_LOOKUP_V org
--         ,HR_PERSON_TYPES_LOOKUP_V ppl_typ
--         ,HR_PERSON_TYPE_USAGES_L1_L2_V pu
--         where
--         hp_emp.person_id = ha.person_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and sysdate  between  pu.effective_start_date  and  pu.effective_end_date
--         and hp_emp.business_group_id = pbg.business_group_id
--         and ha.organization_id    = org.organization_id
--         and hp_emp.current_employee_flag = ''Y''
--         and pu.PERSON_TYPE_ID = ppl_typ.person_type_id
--         and ppl_typ.user_person_type != ''Contractor''
--         and ppl_typ.system_person_type = ''EMP''
--         and pu.PERSON_ID = hp_emp.person_id
--         --and asg.assignment_type = ''E''
--         and ha.primary_flag = ''Y''
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         pbg.name
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_BUSINESS_GROUPS_LOOKUP_V pbg
--         ,HR_ORGANIZATION_LOOKUP_V org
--         ,HR_PERSON_TYPES_LOOKUP_V ppl_typ
--         ,HR_PERSON_TYPE_USAGES_L1_L2_V pu
--         where
--         hp_emp.person_id = ha.person_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and sysdate  between  pu.effective_start_date  and  pu.effective_end_date
--         and hp_emp.business_group_id = pbg.business_group_id
--         and ha.organization_id    = org.organization_id
--         and hp_emp.current_employee_flag = ''Y''
--         and pu.PERSON_TYPE_ID = ppl_typ.person_type_id
--         and ppl_typ.user_person_type != ''Contractor''
--         and ppl_typ.system_person_type = ''EMP''
--         and pu.PERSON_ID = hp_emp.person_id
--         --and asg.assignment_type = ''E''
--         and ha.primary_flag = ''Y''
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         pbg.name
--         from
--         HR_PEOPLE_L1_L2_DATA_V hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V ha
--         ,HR_BUSINESS_GROUPS_LOOKUP_V pbg
--         ,HR_ORGANIZATION_LOOKUP_V org
--         where
--         hp_emp.person_id = ha.person_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and hp_emp.business_group_id = pbg.business_group_id
--         and ha.organization_id    = org.organization_id
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   end if;
 
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||p_email||'-'||get_sqlerrm(sqlcode),sqlcode);
  if upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then
    return get_hr_entity_name(p_email, p_attempt_number + 1);
  else
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,p_email||'-'||get_SQLERRM(SQLCODE)); else raise; end if;
  end if;
end get_hr_entity_name;
 
function get_hr_job (p_email varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic is
/** Get Job Name from HR Secure Views
2019.02.20 - 1.0 - András Tóth - create
2022.01.10 - 1.1 - András Tóth - adding attempts.
2024.04.01 - 1.2 - Bhuvi Chauhan - Replace HR Views with HR PAAS Service
2025.05.27 - 1.3 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'get_hr_job';
  c_proc_version constant varchar2(5 char) := '1.3';
  c_hv number := 1911165908 /*ORA_HASH('get_hr_job')*/;
  v_tmp varchar2(256 char);
begin
  if trim(p_email) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
  v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
  if v_tmp is not null then return v_tmp; end if;

  select SUBSTR(jobTitle, 1, INSTR(jobTitle, '.', 1, 2) - 1) ||'.'||jobFunction as col_1 into v_tmp
                        from JSON_TABLE(pcg.get_hr_paas_data(p_email), '$.data[*]'
                         COLUMNS (
                                    jobTitle                VARCHAR2(255) PATH '$.jobTitle',
                                    jobFunction             VARCHAR2(255) PATH '$.jobFunction'
                                 )
                                        );
                                         
--   if is_prod_env = c_YES then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_PROD,
--         'select
--         j.name
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_JOBS_LOOKUP_V j
--         where
--         hp_emp.person_id = ha.person_id
--         and j.job_id = ha.job_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         j.name
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_JOBS_LOOKUP_V j
--         where
--         hp_emp.person_id = ha.person_id
--         and j.job_id = ha.job_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         j.name
--         from
--         HR_PEOPLE_L1_L2_DATA_V hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V ha
--         ,HR_JOBS_LOOKUP_V j
--         where
--         hp_emp.person_id = ha.person_id
--         and j.job_id = ha.job_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   end if;
 
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||get_sqlerrm(sqlcode),sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then get_hr_job(p_email, p_attempt_number + 1) else null end;
end get_hr_job;
 
 
function get_hr_manager (p_email varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic is
/** Get manager from HR Secure Views
2019.02.07 - 1.0 - András Tóth - create
2022.01.10 - 1.1 - András Tóth - adding attempts.
2024.04.01 - 1.2 - Bhuvi Chauhan - Replace HR Views with HR PAAS Service
*/
  c_proc_name constant varchar2(61 char) := 'get_hr_manager';
  c_proc_version constant varchar2(5 char) := '1.2';
  c_hv number := 697474888 /*ORA_HASH('get_hr_manager')*/;
  v_tmp varchar2(256 char);
begin
  if trim(p_email) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
 -- v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
 -- if v_tmp is not null then return v_tmp; end if;

--   SELECT jt.manager_email_address into v_tmp
--   FROM dual
--   CROSS JOIN JSON_TABLE(
--   PCG.get_hr_paas_data(p_email),
--   '$.data[*]'
--   COLUMNS (
--     manager_email_address VARCHAR2(240) PATH '$.managerEmailAddress'
--   )
-- ) jt;

  SELECT MANAGER_EMAIL_ADDRESS into v_tmp from md_employees where lower(p_email) = EMP_EMAIL_ADDRESS;
 
--   if is_prod_env = c_YES then
--     SELECT col_4 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_PROD,
--     'select
--     hp_emp.person_id,
--     hp_emp.email_address,
--     hp_mgr.person_id,
--     hp_mgr.email_address
--     from
--     HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--     ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--     ,HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_mgr
--     where
--     hp_emp.person_id=ha.person_id
--     and ha.supervisor_id = hp_mgr.person_id
--     and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--     and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--     and sysdate  between  hp_mgr.effective_start_date  and  hp_mgr.effective_end_date
--     and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--     ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_4 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select
--     hp_emp.person_id,
--     hp_emp.email_address,
--     hp_mgr.person_id,
--     hp_mgr.email_address
--     from
--     HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--     ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--     ,HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_mgr
--     where
--     hp_emp.person_id=ha.person_id
--     and ha.supervisor_id = hp_mgr.person_id
--     and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--     and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--     and sysdate  between  hp_mgr.effective_start_date  and  hp_mgr.effective_end_date
--     and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--     ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_4 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select
--     hp_emp.person_id,
--     hp_emp.email_address,
--     hp_mgr.person_id,
--     hp_mgr.email_address
--     from
--     HR_PEOPLE_L1_L2_DATA_V hp_emp
--     ,HR_ASSIGNMENT_L1_L2_DATA_V ha
--     ,HR_PEOPLE_L1_L2_DATA_V hp_mgr
--     where
--     hp_emp.person_id=ha.person_id
--     and ha.supervisor_id = hp_mgr.person_id
--     and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--     and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--     and sysdate  between  hp_mgr.effective_start_date  and  hp_mgr.effective_end_date
--     and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--     ));
--   end if;
 
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||get_sqlerrm(sqlcode),sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then get_hr_manager(p_email, p_attempt_number + 1) else null end;
end get_hr_manager;
 
 
function get_hr_job_level (p_email varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic is
/** Get Job level from HR Secure Views
2019.02.20 - 1.0 - András Tóth - create
2020.03.18 - 1.1 - András Tóth - adjusting query
2022.01.10 - 1.2 - András Tóth - adding attempts.
2024.06.18 - 1.3 - Bhuvi Chauhan - Updating this to use paas
2025.05.27 - 1.4 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'get_hr_job_level';
  c_proc_version constant varchar2(5 char) := '1.4';
  c_hv number := 1184674801 /*ORA_HASH('get_hr_job_level')*/;
  v_tmp varchar2(256 char);
begin
  if trim(p_email) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
  --v_tmp := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
 -- if v_tmp is not null then return v_tmp; end if;

  SELECT jt.careerLevel into v_tmp
  FROM dual
  CROSS JOIN JSON_TABLE(
  PCG.get_hr_paas_data(p_email),
  '$.data[*]'
  COLUMNS (
    careerLevel VARCHAR2(20) PATH '$.careerLevel'
  )
  ) jt;
 
--   if is_prod_env = c_YES then
--     SELECT
--       trim(upper(col_1)) ||
--       case
--       when trim(upper(col_1)) = 'MG' then trim(nvl(col_3,'0'))
--       else coalesce(trim(substr(col_2,4,1)),
--         trim(regexp_substr(regexp_replace(col_4,'^[0-9]*'),'[0-9]') ),
--         case when upper(col_4) like '%CONTRACTOR%' then 'X' end,
--         '1'
--         )
--       end
--     into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_PROD,
--         'select
--         j.status,
--         j.SALARY_SURVEY_CODE,
--         j.APPROVAL_AUTHORITY,
--         j.name
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_JOBS_LOOKUP_L3_L4_V j
--         where
--         hp_emp.person_id = ha.person_id
--         and j.job_id = ha.job_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and ha.primary_flag = ''Y''
--         and hp_emp.current_employee_flag = ''Y''
--         and ha.payroll_id IS NOT NULL
--         --and asg.assignment_type = ''E''
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT
--       trim(upper(col_1)) ||
--       case
--       when trim(upper(col_1)) = 'MG' then trim(nvl(col_3,'0'))
--       else coalesce(trim(substr(col_2,4,1)),
--         trim(regexp_substr(regexp_replace(col_4,'^[0-9]*'),'[0-9]') ),
--         case when upper(col_4) like '%CONTRACTOR%' then 'X' end,
--         '1'
--         )
--       end
--     into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         j.status,
--         j.SALARY_SURVEY_CODE,
--         j.APPROVAL_AUTHORITY,
--         j.name
--         from
--         HR_PEOPLE_L1_L2_L3_DATA_V_GCW hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V_GCW ha
--         ,HR_JOBS_LOOKUP_L3_L4_V j
--         where
--         hp_emp.person_id = ha.person_id
--         and j.job_id = ha.job_id
--         and ha.primary_flag = ''Y''
--         and hp_emp.current_employee_flag = ''Y''
--         and ha.payroll_id IS NOT NULL
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT
--       trim(upper(col_1)) ||
--       case
--       when trim(upper(col_1)) = 'MG' then trim(nvl(col_3,'0'))
--       else coalesce(trim(substr(col_2,4,1)),
--         trim(regexp_substr(regexp_replace(col_4,'^[0-9]*'),'[0-9]') ),
--         case when upper(col_4) like '%CONTRACTOR%' then 'X' end,
--         '1'
--         )
--       end
--     into v_tmp FROM table(bug_java_util.query_remote_table(c_GCW_TEST,
--         'select
--         j.status,
--         j.SALARY_SURVEY_CODE,
--         j.APPROVAL_AUTHORITY,
--         j.name
--         from
--         HR_PEOPLE_L1_L2_DATA_V hp_emp
--         ,HR_ASSIGNMENT_L1_L2_DATA_V ha
--         ,HR_JOBS_LOOKUP_L3_L4_V j
--         where
--         hp_emp.person_id = ha.person_id
--         and j.job_id = ha.job_id
--         and sysdate  between  hp_emp.effective_start_date  and  hp_emp.effective_end_date
--         and sysdate  between  ha.effective_start_date  and  ha.effective_end_date
--         and ha.primary_flag = ''Y''
--         and ha.payroll_id IS NOT NULL
--         and hp_emp.current_employee_flag = ''Y''
--         and upper(hp_emp.email_address) = '''||trim(upper(p_email))||''''
--         ));
--   end if;
 
  v_tmp := case when v_tmp = 'M0' then 'M1' else v_tmp end;
 
  cache_put_s(c_hv,p_email,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||p_email||' - '||get_sqlerrm(sqlcode),sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then get_hr_job_level(p_email, p_attempt_number + 1) else null end;
end get_hr_job_level;
 
function get_hr_country_code2 (p_sso varchar2, p_attempt_number in number default 1) return varchar2 deterministic is
/** Location Country Code 2
2017.05.22 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2022.01.10 - 1.2 - András Tóth - adding attempts.
2024.04.01 - 1.3 - Bhuvi Chauhan - Replace HR Views with HR PAAS Service
2024.11.13 - 1.4 - Bhuvi Chauhan - Removing/Commenting this cache_get_s/cache_put_s as now we are using paas also this is refered from STAA pkg 
2025.05.27 - 1.5 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'get_hr_country_code2';
  c_proc_version constant varchar2(5 char) := '1.5';
  c_hv number := 821812947 /*ORA_HASH('get_hr_country_code')*/;
  v_tmp varchar2(256 char);
begin
  if trim(p_sso) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
--   v_tmp := cache_get_s(c_hv,p_sso,sysdate-c_cache_ldap_expire_days);
--   if v_tmp is not null then return v_tmp; end if;

  SELECT jt.country into v_tmp
  FROM dual
  CROSS JOIN JSON_TABLE(
  PCG.get_hr_paas_data(p_sso),
  '$.data[*]'
  COLUMNS (
    country VARCHAR2(240) PATH '$.country'
  )
  ) jt;
 
--   if is_prod_env = c_YES then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_PROD,
--     'select upper(max(country)) from (
--      select loc.country, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select upper(max(country)) from (
--      select loc.country, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select upper(max(country)) from (
--      select loc.country, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_DATA_V  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         ppl_emp.user_person_type = ''Employee'' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   end if;
 
--   cache_put_s(c_hv,p_sso,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||'p_sso='||p_sso||' - '||get_sqlerrm(sqlcode),sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then get_hr_country_code2(p_sso, p_attempt_number + 1) else null end;
end get_hr_country_code2;
 
function get_hr_city (p_sso varchar2, p_attempt_number in number default 1) return varchar2 deterministic is
/** Location City
2017.05.22 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2022.01.10 - 1.2 - András Tóth - adding attempts.
2024.11.13 - 1.3 - Bhuvi Chauhan - Removing/Commenting this cache_get_s/cache_put_s as now we are using paas.
2025.05.27 - 1.4 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'get_hr_city';
  c_proc_version constant varchar2(5 char) := '1.4';
  c_hv number := 3385190996 /*ORA_HASH('get_hr_city')*/;
  v_tmp varchar2(256 char);
begin
  if trim(p_sso) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
--   v_tmp := cache_get_s(c_hv,p_sso,sysdate-c_cache_ldap_expire_days);
--   if v_tmp is not null then return v_tmp; end if;

  SELECT jt.town_Or_city into v_tmp
  FROM dual
  CROSS JOIN JSON_TABLE(
  PCG.get_hr_paas_data(trim(p_sso)),
  '$.data[*]'
  COLUMNS (
    town_Or_city VARCHAR2(240) PATH '$.townOrCity'
  )
) jt;
 
--   if is_prod_env = c_YES then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_PROD,
--     'select max(TOWN_OR_CITY) from (
--      select loc.TOWN_OR_CITY, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select max(TOWN_OR_CITY) from (
--      select loc.TOWN_OR_CITY, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select max(TOWN_OR_CITY) from (
--      select loc.TOWN_OR_CITY, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_DATA_V  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         ppl_emp.user_person_type = ''Employee'' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   end if;
 
--   cache_put_s(c_hv,p_sso,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||get_sqlerrm(sqlcode),sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then get_hr_city(p_sso, p_attempt_number + 1) else null end;
end get_hr_city;
 
function get_hr_loc_code (p_sso varchar2, p_attempt_number in number default 1) return varchar2 deterministic is
/** Location code e.g. "HU-Budapest-Lechner Odon fasor 7"
2017.05.22 - 1.0 - András Tóth - create
2018.03.29 - 1.1 - András Tóth - cache forget is not necessary any more
2022.01.10 - 1.2 - András Tóth - adding attempts.
2024.11.13 - 1.3 - Bhuvi Chauhan - Removing/Commenting this cache_get_s/cache_put_s as now we are using paas.
2025.05.27 - 1.4 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_name constant varchar2(61 char) := 'get_hr_loc_code';
  c_proc_version constant varchar2(5 char) := '1.3';
  c_hv number :=  3736878925/*ORA_HASH('get_hr_loc_code')*/;
  v_tmp varchar2(256 char);
begin
  if trim(p_sso) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
--   v_tmp := cache_get_s(c_hv,p_sso,sysdate-c_cache_ldap_expire_days);
--   if v_tmp is not null then return v_tmp; end if;

  SELECT jt.location_name into v_tmp
  FROM dual
  CROSS JOIN JSON_TABLE(
  PCG.get_hr_paas_data(p_sso),
  '$.data[*]'
  COLUMNS (
    location_name VARCHAR2(240) PATH '$.locationName'
  )
) jt;
 
--   if is_prod_env = c_YES then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_PROD,
--     'select max(location_code) from (
--      select loc.location_code, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAU' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select max(location_code) from (
--      select loc.location_code, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_L3_DATA_V_GCW  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V_GCW  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   elsif c_GCW_TEST = 'GCWAD' then
--     SELECT col_1 into v_tmp FROM table(bug_java_util.query_remote_table( c_GCW_TEST,
--     'select max(location_code) from (
--      select loc.location_code, row_number() over (partition by ppl_emp.email_address order by assign.effective_start_date desc) rn
--       from HR_PEOPLE_L1_L2_DATA_V  ppl_emp,
--            HR_ASSIGNMENT_L1_L2_DATA_V  assign,
--            HR_LOCATIONS_LOOKUP_V  loc
--       where
--         sysdate between ppl_emp.effective_start_date and ppl_emp.effective_end_date and
--         sysdate between assign.effective_start_date and assign.effective_end_date and
--         ppl_emp.person_id = assign.person_id and
--         assign.primary_flag = ''Y'' and
--         upper(ppl_emp.email_address) = '''||trim(upper(p_sso))||''' and
--         ppl_emp.user_person_type = ''Employee'' and
--         assign.location_id = loc.location_id
--       )
--       where rn = 1'
--     ));
--   end if;
 
--   cache_put_s(c_hv,p_sso,v_tmp);
  return v_tmp;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||get_sqlerrm(sqlcode),sqlcode);
  return case when upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then get_hr_loc_code(p_sso, p_attempt_number + 1) else null end;
end get_hr_loc_code;
 
function app_url(p_app_id number) return varchar2 deterministic is
begin
 
  if trim(c_WS_ID) is null or trim(c_WS_ID) = '0' then
    wwv_flow_api.set_security_group_id;
    c_WS_NAME := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
    c_WS_ID := v('WORKSPACE_ID');
  end if;
 
  if c_WS_ID = c_Prod_WS_ID then
    return 'https://apex.oraclecorp.com/pls/apex/f?p='||to_char(p_app_id);
--   elsif trim(p_app_id) = '13548' then
--     return 'https://apex.oraclecorp.com/pls/apex/f?p='||to_char(p_app_id)||'311';
  else
    return 'https://apex-stage.oraclecorp.com/pls/apex/f?p='||to_char(p_app_id);
  end if;
end;
 
function app_url(p_app_id varchar2) return varchar2 deterministic is
begin
 
  if trim(c_WS_ID) is null or trim(c_WS_ID) = '0' then
    wwv_flow_api.set_security_group_id;
    c_WS_NAME := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
    c_WS_ID := v('WORKSPACE_ID');
  end if;
 
  if c_WS_ID = c_Prod_WS_ID then
    return 'https://apex.oraclecorp.com/pls/apex/f?p='||p_app_id;
  else
    return 'https://apex-stage.oraclecorp.com/pls/apex/f?p='||p_app_id;
  end if;
end;
 
function app_url(
  p_app_id number,
  p_page varchar2,
  p_session varchar2,
  p_options varchar2 default null
) return varchar2 deterministic is
begin
  return apex_util.prepare_url(
      app_url(p_app_id)||':'||p_page||':'||p_session||':'||p_options
    , p_checksum_type =>'SESSION'
    );
end;
 
function app_url_a(
  p_app_id number,
  p_page varchar2,
  p_session varchar2,
  p_display_name varchar2,
  p_options varchar2 default null
) return varchar2 is
begin return '<a href='''||app_url(p_app_id,p_page,p_session,p_options)||'''>'||p_display_name||'</a>';
end;
 
function get_country_activity_history (p_country_id in number) return varchar2 deterministic is
  c_proc_name constant varchar2(61 char) := 'get_country_activity_history';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret MD_COUNTRIES.COUNTRY_ACTIVITY_HISTORY%TYPE;
begin
  select max(country_activity_history) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_activity_history;
 
function get_country_region (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_region';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(region) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_region;
 
function get_country_company (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_company';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(company) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_company;
 
function get_country_hub (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_hub';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(hub) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_hub;
 
function get_country_subregion (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_subregion';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(sub_region) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_subregion;
 
function get_country_name (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_name';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(country) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_name;
 
function get_country_branch (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_branch';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(branch) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_branch;
 
function get_country_code2 (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_code2';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(country_code2) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_code2;
 
function get_country_code3 (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_code3';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(country_code3) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_code3;
 
function get_country_gpo_team_member (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_gpo_team_member';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(gpo_team_member) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_gpo_team_member;
 
function get_country_payroll_analyst (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_payroll_analyst';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_ret varchar2(4000 char);
begin
  select max(payroll_analyst) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_payroll_analyst;
 
function get_country_payroll_manager (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_payroll_manager';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_ret varchar2(4000 char);
begin
  select max(payroll_manager) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_payroll_manager;
 
function get_country_vendor_name (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_vendor_name';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(vendor_name) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_vendor_name;
 
 
function get_country_currency_code3 (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_currency_code3';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(currency_code3) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_currency_code3;
 
function get_country_currency_name (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_currency_name';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(currency_name) into v_ret from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_currency_name;
 
function get_country_name_branch (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_name_branch';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(country||case when branch is not null then ' - '||branch end) into v_ret
    from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_name_branch;
 
function get_country_name_branch_c (p_country_id in number) return varchar2 deterministic as
  c_proc_name constant varchar2(61 char) := 'get_country_name_branch_c';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(200 char);
begin
  select max(coalesce(country||case when branch is not null then ' - '||branch end,sub_region,hub,region,company)) into v_ret
    from MD_COUNTRIES where id = p_country_id;
  return v_ret;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_name_branch_c;
 
function migrate_country_code_2_id (p_country_code varchar2) return number deterministic is
/** converts old country codes into country id. country-code like identifiers used by Madelina in old programs converted into the new ID-s in MD_COUNTRIES table replaced in new applications. Returns null if country not exists in new environment, raises error if no such code in the original table.
2018.05.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := $$PLSQL_UNIT||'.'||'migrate_country_code_2_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_country_code varchar2(4000 char) := trim(upper(p_country_code));
  v_ret number;
begin
  select case when v_country_code in ('CG','CM','ET','MZ') then null else id end into v_ret from md_countries
  where deleted_sign is null and (
     v_country_code = 'AA' and hub = 'RO_HUB' and sub_region is null
  or v_country_code = 'AD-OF' and country = 'Abu Dhabi' and BRANCH = 'OFSS'
  or v_country_code = 'AE' and hub = 'RO_HUB' and sub_region is null
  or v_country_code = 'AL' and country = 'Albania' and branch is null
  or v_country_code = 'ALL' and region = 'GLOBAL' and hub is null
  or v_country_code = 'AR' and country = 'Argentina' and branch is null
  or v_country_code = 'ARM' and country = 'Armenia' and branch is null
  or v_country_code = 'AT' and country = 'Austria' and branch is null
  or v_country_code = 'AU' and country = 'Australia' and branch is null
  or v_country_code = 'AU-OF' and country = 'Australia' and branch = 'OFSS'
  or v_country_code = 'AZ' and country = 'Azerbaijan' and branch is null
  or v_country_code = 'BA' and country ='Bosnia and Herzegovina' and branch is null
  or v_country_code = 'BE' and country ='Belgium' and branch is null
  or v_country_code = 'BG' and country ='Bulgaria' and branch is null
  or v_country_code = 'BH' and country ='Bahrain' and branch is null
  or v_country_code = 'BR' and country ='Brazil' and branch is null
  or v_country_code = 'BY' and country ='Belarus' and branch is null
  or v_country_code = 'CA' and country ='Canada' and branch is null
  or v_country_code = 'CEN' and region = 'LAD' and hub is null
  or v_country_code = 'CG' and rownum = 1
  or v_country_code = 'CH' and country ='Switzerland' and branch is null
  or v_country_code = 'CI' and country ='Ivory Coast' and branch is null
  or v_country_code = 'CL' and country ='Chile' and branch is null
  or v_country_code = 'CL-OF' and country ='Chile' and branch = 'OFSS'
  or v_country_code = 'CM' and rownum = 1
  or v_country_code = 'CN' and country ='China' and branch is null
  or v_country_code = 'CN-OF' and country ='China' and branch = 'OFSS'
  or v_country_code = 'COL' and country ='Colombia' and branch is null
  or v_country_code = 'CR' and country ='Costa Rica' and branch is null
  or v_country_code = 'CRB' and region = 'LAD' and hub is null
  or v_country_code = 'CT' and country ='Croatia' and branch is null
  or v_country_code = 'CY' and country ='Cyprus' and branch is null
  or v_country_code = 'CZ' and country ='Czech Republic' and branch is null
  or v_country_code = 'DE' and country ='Germany' and branch is null
  or v_country_code = 'DE-OF' and country ='Germany' and branch = 'OFSS'
  or v_country_code = 'DK' and country ='Denmark' and branch is null
  or v_country_code = 'DZ' and country ='Algeria' and branch is null
  or v_country_code = 'EE' and country ='Estonia' and branch is null
  or v_country_code = 'EG' and country ='Egypt' and branch is null
  or v_country_code = 'EMEA' and region ='EMEA' and hub is null
  or v_country_code = 'ES' and country ='Spain' and branch is null
  or v_country_code = 'ET' and rownum = 1
  or v_country_code = 'FI' and country ='Finland' and branch is null
  or v_country_code = 'FR' and country ='France' and branch is null
  or v_country_code = 'FR-OF' and country ='France' and branch = 'OFSS'
  or v_country_code = 'GB' and country ='UK' and branch is null
  or v_country_code = 'GB-OF' and country ='UK' and branch = 'OFSS'
  or v_country_code = 'GH' and country ='Ghana' and branch is null
  or v_country_code = 'GM' and country ='Guam' and branch is null
  or v_country_code = 'GR' and country ='Greece' and branch is null
  or v_country_code = 'GR-OF' and country ='Greece' and branch = 'OFSS'
  or v_country_code = 'HK' and country ='Hong Kong' and branch is null
  or v_country_code = 'HU' and country ='Hungary' and branch is null
  or v_country_code = 'ID' and country ='Indonesia' and branch is null
  or v_country_code = 'IE' and country ='Ireland' and branch is null
  or v_country_code = 'IE-OF' and country ='Ireland' and branch = 'OFSS'
  or v_country_code = 'IL' and country ='Israel' and branch is null
  or v_country_code = 'IN' and country ='India' and branch is null
  or v_country_code = 'IN-OF' and country ='India' and branch = 'OFSS'
  or v_country_code = 'IT' and country ='Italy' and branch is null
  or v_country_code = 'JO' and country ='Jordan' and branch is null
  or v_country_code = 'JP' and country ='Japan' and branch is null
  or v_country_code = 'JP-OF' and country ='Japan' and branch = 'OFSS'
  or v_country_code = 'JPOIS' and country ='Japan' and branch = 'OIS'
  or v_country_code = 'KE' and country ='Kenya' and branch is null
  or v_country_code = 'KR' and country ='Korea' and branch is null
  or v_country_code = 'KW' and country ='Kuwait' and branch is null
  or v_country_code = 'KZ' and country ='Kazakhstan' and branch is null
  or v_country_code = 'LB' and country ='Lebanon' and branch is null
  or v_country_code = 'LK' and country ='Sri Lanka' and branch is null
  or v_country_code = 'LT' and country ='Lithuania' and branch is null
  or v_country_code = 'LU' and country ='Luxembourg' and branch is null
  or v_country_code = 'LV' and country ='Latvia' and branch is null
  or v_country_code = 'LY' and country ='Libya' and branch is null
  or v_country_code = 'MA' and country ='Morocco' and branch is null
  or v_country_code = 'MC' and country ='Macau' and branch is null
  or v_country_code = 'MK' and country ='Macedonia' and branch is null
  or v_country_code = 'ML' and country ='Malta' and branch is null
  or v_country_code = 'MU' and country ='Mauritius' and branch is null
  or v_country_code = 'MV' and country ='Maldives' and branch is null
  or v_country_code = 'MX' and country ='Mexico' and branch is null
  or v_country_code = 'MY' and country ='Malaysia' and branch is null
  or v_country_code = 'MZ' and rownum = 1
  or v_country_code = 'NG' and country ='Nigeria' and branch is null
  or v_country_code = 'NL' and country ='Netherlands' and branch is null
  or v_country_code = 'NO' and country ='Norway' and branch is null
  or v_country_code = 'NT' and country ='Netherlands' and branch = 'OFSS'
  or v_country_code = 'NZ' and country ='New Zealand' and branch is null
  or v_country_code = 'OM' and country ='Oman' and branch is null
  or v_country_code = 'PH' and country ='Philippines' and branch is null
  or v_country_code = 'PK' and country ='Pakistan' and branch is null
  or v_country_code = 'PL' and country ='Poland' and branch is null
  or v_country_code = 'PR' and country ='Peru' and branch is null
  or v_country_code = 'PRC' and country ='Puerto Rico' and branch is null
  or v_country_code = 'PT' and country ='Portugal' and branch is null
  or v_country_code = 'QA' and country ='Qatar' and branch is null
  or v_country_code = 'RO' and country ='Romania' and branch is null
  or v_country_code = 'RS' and country ='Serbia' and branch is null
  or v_country_code = 'RU' and country ='Russia' and branch is null
  or v_country_code = 'RU-OF' and country ='Russia' and branch = 'OFSS'
  or v_country_code = 'SA' and country ='Saudi Arabia' and branch is null
  or v_country_code = 'SCT' and country ='UK' and branch is null
  or v_country_code = 'SE' and country ='Sweden' and branch is null
  or v_country_code = 'SG' and country ='Singapore' and branch is null
  or v_country_code = 'SG-OF' and country ='Singapore' and branch = 'OFSS'
  or v_country_code = 'SK' and country ='Slovakia' and branch is null
  or v_country_code = 'SL' and country ='Slovenia' and branch is null
  or v_country_code = 'SN' and country ='Senegal' and branch is null
  or v_country_code = 'TH' and country ='Thailand' and branch is null
  or v_country_code = 'TR' and country ='Turkey' and branch is null
  or v_country_code = 'TW' and country ='Taiwan' and branch is null
  or v_country_code = 'UA' and country ='Ukraine' and branch is null
  or v_country_code = 'UE' and country ='UAE' and branch is null
  or v_country_code = 'UE-OF' and country ='UAE' and branch = 'OFSS'
  or v_country_code = 'US' and country ='USA' and branch is null
  or v_country_code = 'US-OF' and country ='USA' and branch = 'OFSS'
  or v_country_code = 'UY' and country ='Uruguay' and branch is null
  or v_country_code = 'VT' and country ='Vietnam' and branch is null
  or v_country_code = 'VZ' and country ='Venezuela' and branch is null
  or v_country_code = 'ZA' and country ='South Africa' and branch is null
  );
 
  return v_ret;
 
exception when others then
  -- logging to Standard PCG_ERRORS table
  log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end migrate_country_code_2_id;
 
function to_Fiscal_Year(p_date in date) return varchar2 deterministic is
/* Returns the Fiscal Year created from the date */
  v_y number;
  v_m number;
 
begin
  v_y := to_number(to_char(p_date,'YYYY'));
  v_m := to_number(to_char(p_date,'MM'));
  if v_m > 5 then v_y := v_y + 1; end if;
  return 'FY'||substr(to_char(v_y),-2);
end to_Fiscal_Year;
 
function to_Fiscal_Quarter(p_date in date) return varchar2 deterministic is
/* Returns the Fiscal Quarter created from the date */
  v_m number;
 
begin
  v_m := to_number(to_char(p_date,'MM'));
  if v_m in (6,7,8) then return 'FQ1';
  elsif v_m in (9,10,11) then return 'FQ2';
  elsif v_m in (12,1,2) then return 'FQ3';
  elsif v_m in (3,4,5) then return 'FQ4';
  end if;
end to_Fiscal_Quarter;
 
function is_adp_country (p_country_id in number) return char deterministic is
  v_vendor_name varchar2(4000 char);
begin
  v_vendor_name := get_country_vendor_name(p_country_id);
  if v_vendor_name like '%ADP%' or v_vendor_name like '%ABC%' or v_vendor_name like '%RSM%'
  then return c_yes;
  else return c_no;
  end if;
exception when no_data_found then
  return null;
end is_adp_country;
 
procedure update_md_users_v is
/** Rebuild the values of the users view.
2018.07.11 - 1.0 - András Tóth - create procedure
2022.11.21 - 1.1 - Marek Szwarczewski - allow colecting entries from the table MD_TEST_USERS
*/
pragma autonomous_transaction;
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'update_md_users_v';
begin
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'procedure called...',null,c_Debug);
  delete from MD_USERS_V;
  insert into MD_USERS_V  (ID,APPLICATION_ID,APPLICATION_NAME,USERNAME,ROLE,REGION,ROLE_NAME,CREATED_BY,CREATED,UPDATED_BY,UPDATED,OTHER_ROLES,EMP_NAME)
  select /*+ RESULT_CACHE */
         ora_hash(username||v.ROLE_NAME) as id
       , v.APPLICATION_ID
       , v.APPLICATION_NAME
       , v.USERNAME
       , trim(SUBSTR( v.ROLE_NAME,    INSTR( v.ROLE_NAME, ' ', -1, 1) +1 )) AS ROLE
       , trim(SUBSTR( v.ROLE_NAME, 1, INSTR( v.ROLE_NAME, ' ', 1 , 1) -1 )) AS REGION
       , v.ROLE_NAME
       , v.CREATED_BY
       , v.CREATED
       , v.UPDATED_BY
       , v.UPDATED
       , v.OTHER_ROLES
       , email2name(v.USERNAME) as EMP_NAME
  from (
    with aps as (select /*+ RESULT_CACHE */ APPLICATION_ID,APPLICATION_NAME,USERNAME,ROLE_NAME,CREATED_BY,CREATED,UPDATED_BY,UPDATED from aps_intg_users_and_roles_v)
    select /*+ RESULT_CACHE */
       vv.APPLICATION_ID
     , vv.APPLICATION_NAME
     , vv.USERNAME
     , vv.ROLE_NAME
     , vv.CREATED_BY
     , vv.CREATED
     , vv.UPDATED_BY
     , vv.UPDATED
       , ( select listagg(r.application_id||'-'||r.ROLE_NAME,',') WITHIN GROUP (ORDER BY r.application_id,r.ROLE_NAME) as other_roles from aps r where application_id != '20377' and vv.username = r.username group by USERNAME) OTHER_ROLES
    from aps vv where APPLICATION_ID = '20377'
union all
    select 20377
    , 'GPAT Form'
    , ut.USERNAME
    , ut.ROLE_NAME
    , uh.PCGH_LOAD_USER as CREATED_BY
    , uh.PCGH_LOAD_TIME as CREATED
    , uh.PCGH_LOAD_USER as UPDATED_BY
    , uh.PCGH_LOAD_TIME as UPDATED
    , null as OTHER_ROLES
    from MD_TEST_USERS ut
    , ( select DISTINCT 
          USERNAME,
          FIRST_VALUE(PCGH_LOAD_TIME) OVER (ORDER BY PCGH_LOAD_TIME DESC, PCGH_LOAD_USER ASC) as PCGH_LOAD_TIME,
          FIRST_VALUE(PCGH_LOAD_USER) OVER (ORDER BY PCGH_LOAD_TIME DESC, PCGH_LOAD_USER ASC) as PCGH_LOAD_USER
        from MD_TEST_USERS_H ) uh
    where ut.USERNAME = uh.USERNAME
    ) v;
  commit;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end update_md_users_v;
 
procedure daily_job is
/** run this job daily.
2018.08.02 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'daily_job';
  v_pct_used number;
  v_name varchar2(30 char);
  v_bytes number;
  v_free number;
  v_used number;
begin
  wwv_flow_api.set_security_group_id;
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'procedure called...',null,c_Debug);
 
  -- putting tablespace storage daily statistics:
  select NAME,BYTES,FREE,USED,PCT_USED into v_NAME,v_BYTES,v_FREE,v_USED,v_PCT_USED from apex_workspace_tablespaces;
  insert into PCG_STORAGE_STATS (QUERY_DATE,NAME,BYTES,FREE,USED,PCT_USED) values (sysdate,v_NAME,v_BYTES,v_FREE,v_USED,v_PCT_USED);
  commit;
 
/* get Stats:
  with stores as (select * from PCG_STORAGE_STATS)
  select s1.QUERY_DATE, s1.BYTES as available_storage, round(s1.PCT_USED,2) as usage_percentage, s2.BYTES as available_storage_previous, round(s2.PCT_USED,2) as usage_percentage_previous,
  s1.BYTES-s2.BYTES storage_gain, round(s1.PCT_USED - s2.PCT_USED,3) usage_percentage_increase
  from stores s1, stores s2
  where trim(s1.QUERY_DATE) = trim(s2.QUERY_DATE + 1)
  order by s1.QUERY_DATE desc
*/
 
  -- email notification in case of running out of space:
  if v_pct_used > 95 then
    for i in (
      -- TODO: Get this from a parameter in the future:
      select 'rohit.bq.kumar@oracle.com' as email_to from dual union all -- Bhuvi's comment - added rohit here
      select 'marek.szwarczewski@oracle.com' as email_to from dual union all
      select 'heather.fryters@oracle.com' as email_to from dual
    ) loop
      sendmail(i.email_to , null, 'pcg.daily_job', 'Storage Shortage in APEX Workspace', 'The workspace '||c_WS_NAME||' is running on '||to_char(v_pct_used,'999.99')||'% storage used up.');
    end loop;
  end if;
 
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end daily_job;
 
-------------
procedure tree_dup(p_tree_id in number, p_new_name in varchar2, p_new_description in varchar2) is
/** Duplicate a tree
2018.10.08 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'tree_dup';
  v_ret number;
begin
  v_ret := tree_dup(p_tree_id, p_new_name, p_new_description);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end tree_dup;
 
-------------
function tree_dup(p_tree_id in number, p_new_name in varchar2, p_new_description in varchar2) return number is
/** Duplicate a tree and return the id of the new tree
2018.10.08 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'tree_dup';
  v_ret number;
  v_new_tree_id number;
  v_old_roots PCG_number_LIST;
begin
  v_new_tree_id := tree_create(p_new_name, p_new_description);
  commit;
  select id bulk collect into v_old_roots from md_tree_leaves where p_tree_id = tree_id and parent_id is null;
  for i in 1..v_old_roots.count loop
    tree_leaf_deep_copy(v_old_roots(i), v_new_tree_id, null);
  end loop;
  return v_new_tree_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end tree_dup;
 
function tree_leaf_deep_copy(p_in_leaf_id number, p_out_tree_id in number, p_out_root_id in number) return number is
/** Duplicate a leaf and return the id of the new leaf
2018.10.08 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'tree_leaf_deep_copy';
  v_children PCG_number_LIST;
  v_leaf number;
  v_tmp number;
  v_ln varchar2(100 char);
begin
  v_ln := 1;
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'p_in_leaf_id='||to_char(p_in_leaf_id)||', p_out_tree_id='||to_char(p_out_tree_id)||', p_out_root_id='||to_char(p_out_root_id),null,c_Debug);
  v_ln := 2;
  v_leaf := tree_leaf_create(p_out_tree_id,p_out_root_id, get_tree_leaf_name(p_in_leaf_id));
  v_ln := 3;
  commit;
  select distinct id bulk collect into v_children from md_tree_leaves where parent_id = p_in_leaf_id and DELETED_SIGN is null;
  v_ln := 4;
  for i in 1..v_children.count loop
    v_ln := 5;
    v_tmp := tree_leaf_deep_copy(v_children(i), p_out_tree_id, v_leaf);
    v_ln := 6;
  end loop;
  v_ln := 7;
  return v_leaf;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version
    ,get_sqlerrm(sqlcode)||' - p_in_leaf_id='||to_char(p_in_leaf_id)||', p_out_tree_id='||to_char(p_out_tree_id)||', p_out_root_id='||to_char(p_out_root_id)||', v_ln='||v_ln
    ,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end tree_leaf_deep_copy;
 
-------------
procedure tree_leaf_deep_copy(p_in_leaf_id number, p_out_tree_id in number, p_out_root_id in number) is
/** Duplicate a leaf
2018.10.08 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'tree_leaf_deep_copy';
  v_ret number;
begin
  v_ret := tree_leaf_deep_copy(p_in_leaf_id, p_out_tree_id, p_out_root_id);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end tree_leaf_deep_copy;
 
-------------
function get_country_subregion_id (p_sub_region in varchar2) return number deterministic is
/** return the country_id for the geo unit
2019.05.27 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - raise error instead of returning with null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_subregion_id';
  v_id number;
begin
  if p_sub_region is null then return null; end if;
  select id into v_id from md_countries where deleted_sign is null and sub_region = p_sub_region and country is null;
  return v_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_sub_region,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_subregion_id;
 
-------------
function get_country_subregion_id (p_country_id in number) return number deterministic is
/** return the country_id for the geo unit
2019.05.27 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - return null in case the input is negative or null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_subregion_id';
  v_sub_region varchar2(4000);
begin
  if nvl(p_country_id, -1) < 0 then return null; end if;
  select sub_region into v_sub_region from md_countries where id = p_country_id;
  return  get_country_subregion_id(v_sub_region);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||to_char(p_country_id),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_subregion_id;
 
-------------
function get_country_hub_id (p_hub in varchar2) return number deterministic is
/** return the country_id for the geo unit
2019.05.27 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - raise error instead of returning with null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_hub_id';
  v_id number;
begin
  if p_hub is null then return null; end if;
  select id into v_id from md_countries where deleted_sign is null and hub = trim(p_hub) and sub_region is null;
  return v_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_hub,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_hub_id;
 
-------------
function get_country_hub_id (p_country_id in number) return number deterministic is
/** return the country_id for the geo unit
2019.05.27 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - return null in case the input is negative or null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_hub_id';
  v_hub varchar2(4000);
begin
  if nvl(p_country_id, -1) < 0 then return null; end if;
  select hub into v_hub from md_countries where id = p_country_id;
  return get_country_hub_id(v_hub);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||to_char(p_country_id),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_hub_id;
 
-------------
function get_country_region_id (p_region in varchar2) return number deterministic is
/** return the country_id for the geo unit
2019.05.27 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - raise error instead of returning with null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_region_id';
  v_id number;
begin
  if p_region is null then return null; end if;
  select id into v_id from md_countries where deleted_sign is null and region = p_region and hub is null;
  return v_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_region,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_region_id;
 
-------------
function get_country_region_id (p_country_id in number) return number deterministic is
/** return the country_id for the geo unit
2019.05.27 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - return null in case the input is negative or null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_region_id';
  v_region varchar2(4000);
begin
  if nvl(p_country_id, -1) < 0 then return null; end if;
  select region into v_region from md_countries where id = p_country_id;
  return get_country_region_id(v_region);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||to_char(p_country_id),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_region_id;
 
-------------
function get_country_company_id (p_company in varchar2) return number deterministic is
/** return the country_id for the geo unit
2019.05.30 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - raise error instead of returning with null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_company_id';
  v_id number;
begin
  if p_company is null then return null; end if;
  select id into v_id from md_countries where deleted_sign is null and company = p_company and region is null;
  return v_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_company,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_company_id;
 
-------------
function get_country_company_id (p_country_id in number) return number deterministic is
/** return the country_id for the geo unit
2019.05.30 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - return null in case the input is negative or null.
*/
  c_proc_version constant varchar2(5 char) := '1.1';
  c_proc_name constant varchar2(30 char) := 'get_country_company_id';
  v_company varchar2(4000);
begin
  if nvl(p_country_id, -1) < 0 then return null; end if;
  select company into v_company from md_countries where id = p_country_id;
  return get_country_company_id(v_company);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||to_char(p_country_id),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_company_id;
 
-------------
function get_hub_id_from_country_code2 (p_cc2 in varchar2) return number deterministic is
/** return the country_id for the geo unit
2019.06.26 - 1.0 - András Tóth - create procedure
2019.09.24 - 1.1 - András Tóth - return null in case, the input is null
2020.01.31 - 1.2 - András Tóth - bug: error when branch is not null - corrected.
*/
  c_proc_version constant varchar2(5 char) := '1.2';
  c_proc_name constant varchar2(30 char) := 'get_hub_id_from_country_code2';
  v_hub varchar2(4000);
begin
  if p_cc2 is null then return null; end if;
  select hub into v_hub from md_countries where country_code2 = p_cc2 and branch is null;
  return get_country_hub_id(v_hub);
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_cc2,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hub_id_from_country_code2;
 
-------------
function get_country_id_of_entity (p_entity_id in number) return number deterministic is
/** return the country_id of the Entity.
2020.02.20 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'get_country_id_of_entity';
  v_country_id number;
begin
  select c.id into v_country_id
  from md_entities e, md_countries c
  where e.COUNTRY_ID2 = c.id and e.ID_ENTITY = p_entity_id;
  return v_country_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - p_entity_id='||to_char(p_entity_id),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_id_of_entity;
 
-------------
function get_country_entity_name (p_entity_id in number) return varchar2 deterministic is
/** return the name of the Entity.
2020.02.26 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'get_country_entity_name';
  v_entity_name varchar2(4000 char);
begin
  select c.country|| case when c.branch is not null then ' - '||c.branch end || ' -- ' || e.entity_name into v_entity_name
  from md_entities e, md_countries c
  where e.COUNTRY_ID2 = c.id and e.ID_ENTITY = p_entity_id;
  return v_entity_name;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - p_entity_id='||to_char(p_entity_id),sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_country_entity_name;
 
-------------
function get_hr_business_group_id (p_email in varchar2 default v('APP_USER'), p_attempt_number in number default 1) return number deterministic is
/** return the business group ID of the employee
2020.04.01 - 1.0 - András Tóth - create procedure
2020.04.24 - 1.1 - András Tóth - adding cache
2022.01.10 - 1.2 - András Tóth - adding attempts.
2024.06.18 - 1.3 - Bhuvi Chauhan - Using PAAS insted of HR sec views
2025.05.27 - 1.4 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.
*/
  c_proc_version constant varchar2(5 char) := '1.4';
  c_proc_name constant varchar2(30 char) := 'get_hr_business_group_id';
  c_hv number := 4189071584/*ORA_HASH('get_hr_business_group_id')*/;
  v_ret number;
begin
 
  if trim(p_email) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
 
--   v_ret := cache_get_s(c_hv,p_email,sysdate-c_cache_ldap_expire_days);
--   if v_ret is not null then return v_ret; end if;

  select businessUnitId as col_1 into v_ret
  from JSON_TABLE(pcg.get_hr_paas_data(p_email), '$.data[*]'
                         COLUMNS (
                                    businessUnitId    VARCHAR2(100) PATH '$.businessUnitId',
                                    effectiveEndDate VARCHAR2(100) PATH '$.effectiveEndDate'
                                 )
                 ) 
   where effectiveEndDate > sysdate;
 
--   SELECT to_number(col_1) into v_ret FROM table(bug_java_util.query_remote_table(case when is_prod_env = c_YES then c_GCW_PROD else c_GCW_TEST end,
--     'SELECT
--       max(emp.business_group_id)
--     FROM HR_PEOPLE_L1_L2_L3_DATA_V_GCW emp, HR_ASSIGNMENT_L1_L2_DATA_V_GCW asg
--     WHERE
--       lower(emp.email_address) = TRIM(lower('''|| p_email ||''' )) AND
--       SYSDATE BETWEEN emp.effective_start_date AND emp.effective_end_date AND
--       emp.current_employee_flag = ''Y'' AND
--       SYSDATE BETWEEN asg.effective_start_date AND asg.effective_end_date AND
--       emp.person_id = asg.person_id AND
--       asg.primary_flag = ''Y'' AND
--       asg.payroll_id IS NOT NULL AND
--       asg.assignment_type = ''E'' AND
--       asg.primary_flag = ''Y'' and
--       1=1 '
--   ));
 
 -- cache_put_s(c_hv,p_email,v_ret);
  return v_ret;
 
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||get_sqlerrm(sqlcode)||' - p_email='||p_email,sqlcode);
  if upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then
    return get_hr_business_group_id(p_email, p_attempt_number + 1);
  else
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
  end if;
end get_hr_business_group_id;
 
-------------
function get_hr_bg_country_code2 (p_business_group_id in number, p_attempt_number in number default 1) return varchar2 deterministic is
/** return the country code for the business group.
2020.04.01 - 1.0 - András Tóth - create procedure
2020.04.24 - 1.1 - András Tóth - adding cache
2022.01.10 - 1.2 - András Tóth - adding attempts.
2024.06.18 - 1.3 - Bhuvi Chauhan - Using PAAS insted of HR sec views
2025.05.27 - 1.4 - Bhuvi Chauhan - Changes to use md_employees_oauth2 table to get data.

*/
  c_proc_version constant varchar2(5 char) := '1.3';
  c_proc_name constant varchar2(30 char) := 'get_hr_bg_country_code2';
  c_hv number := 572373488/*ORA_HASH('get_hr_bg_country_code2')*/;
  v_ret varchar2(4000);
begin
 
  if trim(p_business_group_id) is null then return null; end if;
  if p_attempt_number > 1 then sys.dbms_session.sleep(c_retry_sleep_time); end if;
 
  --v_ret := cache_get_s(c_hv,p_business_group_id,sysdate-c_cache_ldap_expire_days);
  --if v_ret is not null then return v_ret; end if;

  select country as col_1 into v_ret
  from JSON_TABLE(pcg.get_hr_paas_cmbnd_data(p_business_group_id), '$.data[*]'
                         COLUMNS (
                                    country    VARCHAR2(25) PATH '$.country',
                                    effectiveEndDate VARCHAR2(100) PATH '$.effectiveEndDate'
                                 )
                 ) 
   where effectiveEndDate > sysdate
   and rownum = 1;
 
--   SELECT col_1 into v_ret FROM table(bug_java_util.query_remote_table(case when is_prod_env = c_YES then c_GCW_PROD else c_GCW_TEST end,
--     ' SELECT loc.country
--     FROM HR_BUSINESS_GROUPS_LOOKUP_V bus , HR_ORGANIZATION_LOOKUP_V org , HR_LOCATIONS loc
--     WHERE
--       bus.business_group_id = '||to_char(p_business_group_id)||' AND
--       bus.business_group_id = org.business_group_id AND
--       org.location_id IS NOT NULL AND
--       org.organization_id = org.business_group_id AND
--       SYSDATE BETWEEN bus.date_from AND NVL(bus.date_to,TO_DATE(''31-12-4712'',''DD-MM-YYYY'')) AND
--       loc.location_id = org.location_id AND
--       loc.inactive_date IS NULL '
--   ));
 
  --cache_put_s(c_hv,p_business_group_id,v_ret);
  return v_ret;
 
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,'(attempt_#: '||to_char(p_attempt_number)||') '||get_sqlerrm(sqlcode)||' - p_business_group_id='||to_char(p_business_group_id),sqlcode);
  if upper(SQLERRM) like '%JAVA%' and p_attempt_number < c_retry_threshold + 1 then
    return get_hr_bg_country_code2(p_business_group_id, p_attempt_number + 1);
  else
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
  end if;
end get_hr_bg_country_code2;
 
-------------
function is_valid_email (p_email_input in varchar2) return char deterministic is
/** return if the email seems to be a balid email address
2020.11.09 - 1.0 - András Tóth - create procedure
*/
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'is_valid_email';
begin
  return case
    when
    regexp_like(p_email_input, '^[A-Za-z0-9][A-Za-z0-9._%+-]*@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$')
    --   regexp_like(p_email_input, '^[A-Za-z]+[A-Za-z0-9.]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$')
      and length(p_email_input) <= 254 /* https://www.rfc-editor.org/errata/eid1690 */
    then 'Y'
    else 'N'
  end;
end is_valid_email;
 
-------------------
function clob_to_blob(p_clob_in in clob) return blob deterministic is
  v_ln varchar2(32767 char);
  v_blob_file blob;
  v_lob_length pls_integer := dbms_lob.getlength(p_clob_in);
  v_position pls_integer := 1;
  v_buffer_size raw(32767);
begin
  v_ln := '1';
  dbms_lob.createtemporary(v_blob_file, true);
  v_ln := '2';
  dbms_lob.open(v_blob_file, dbms_lob.lob_readwrite);
  v_ln := '3';
  loop
    v_ln := '4-#'||to_char(v_position);
    v_buffer_size := utl_raw.cast_to_raw(dbms_lob.substr(p_clob_in, 16000, v_position));
    v_ln := '5-#'||to_char(v_position);
    if utl_raw.length(v_buffer_size) > 0 then
        v_ln := '6-#'||to_char(v_position);
        dbms_lob.writeappend(v_blob_file, utl_raw.length(v_buffer_size), v_buffer_size);
        v_ln := '7-#'||to_char(v_position);
    end if;
    v_ln := '8-#'||to_char(v_position);
    v_position := v_position + 16000;
    v_ln := '9-#'||to_char(v_position);
    exit when v_position > v_lob_length;
    v_ln := '10-#'||to_char(v_position);
  end loop;
  v_ln := '11-#'||to_char(v_position);
  return v_blob_file;
exception when others then raise_application_error(-20001, 'clob_to_blob['||v_ln||'] '||sqlerrm);
end clob_to_blob;
 
-------------------
function blob_to_clob(p_blob_in in blob) return clob deterministic as
   v_chunk varchar2(32767);
   v_position pls_integer := 1;
   v_buffer_size pls_integer := 32767;
   v_clob_text clob;
   v_ln varchar2(32767 char);
begin
   v_ln := '0';
   dbms_lob.createtemporary(v_clob_text, true);
   v_ln := '1a';
   if p_blob_in is null then return v_clob_text; end if;
   v_ln := '1b';
   if dbms_lob.compare(p_blob_in, empty_blob()) = 0 then return v_clob_text; end if;
   v_ln := '2';
   for i in 1 .. ceil(dbms_lob.getlength(p_blob_in) / v_buffer_size)
   loop
      v_ln := '3-#'||to_char(i);
      v_chunk := utl_raw.cast_to_varchar2(dbms_lob.substr(p_blob_in, v_buffer_size, v_position));
      v_ln := '4-#'||to_char(i);
      dbms_lob.writeappend(v_clob_text, length(v_chunk), v_chunk);
      v_ln := '5-#'||to_char(i);
      v_position := v_position + v_buffer_size;
      v_ln := '6-#'||to_char(i);
   end loop;
   v_ln := '7';
   return v_clob_text;
exception when others then raise_application_error(-20001, 'blob_to_clob['||v_ln||'] '||sqlerrm);
end blob_to_clob;

--------------------
function get_hr_paas_data(p_email varchar2 default v('APP_USER')) return clob deterministic is
/** Returns the whole data set for employee.
2023.10.24 - 1.0 - Marek Szwarczewski - create function
2023.12.01 - 1.1 - Bhuvi Chauhan - Added p_employee_number as parameter and added case for p_employee_number getting data via gsiemployeenumber
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_data';
    l_clob      clob;
begin

    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?emailAddress=' || lower(p_email)
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    return l_clob;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_email,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_data;

--------------------
function get_hr_paas_hcm_id(p_data clob) return varchar2 deterministic is
/** Parse JSON PaaS answer and returns HCM_ID.
2023.10.24 - 1.0 - Marek Szwarczewski - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_hcm_id';
    l_hcm_id    varchar2(255);
begin
  select * into l_hcm_id
        from JSON_TABLE(p_data, '$.data[*]'
        COLUMNS (
                hcm_Person_Number    VARCHAR2(255) PATH '$.hcmPersonNumber'
                )
    ) ;
  
    return l_hcm_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_data,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_hcm_id;

----------------------
function get_hr_paas_gsi_id(p_data clob) return varchar2 deterministic is
/** Parse JSON PaaS answer and returns HCM_ID.
2023.10.24 - 1.0 - Marek Szwarczewski - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_gsi_id';
    l_gsi_id    varchar2(255);
begin
  select * into l_gsi_id
        from JSON_TABLE(p_data, '$.data[*]'
        COLUMNS (
                gsi_Employee_Number    VARCHAR2(255) PATH '$.gsiEmployeeNumber'
                )
    ) ;
  
    return l_gsi_id;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_data,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_gsi_id;

----------------------
function get_hr_paas_user_type(p_data clob) return varchar2 deterministic is
/** Parse JSON PaaS answer and returns HCM_ID.
2023.10.24 - 1.0 - Marek Szwarczewski - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_user_type';
    l_user_type    varchar2(255);
begin
  select * into l_user_type
        from JSON_TABLE(p_data, '$.data[*]'
        COLUMNS (
                user_Type    VARCHAR2(255) PATH '$.userPersonType'
                )
    ) ;
  
    return l_user_type;
exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_data,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_user_type;

-------------------------
procedure set_hr_paas_collection(p_c_name in varchar2, p_data clob, p_app_user varchar2 default v('APP_USER'), p_app_session varchar2 default v('APP_SESSION')) is

    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'set_hr_paas_collection';
    l_query   clob ;

begin
    if  apex_collection.collection_exists( p_collection_name => p_c_name ) then
        apex_collection.delete_collection( p_collection_name => p_c_name ) ;
    end if ;

l_query := '
    select ''' || p_app_session || ''' as session_id,''' || p_app_user || ''' as apex_user
         , email_Address, gsi_Employee_Number, first_Name, last_Name, legislation_Code, country, legal_Entity_Name, company_Code
         , person_Id, location_Id, location_Name, effective_Start_Date, effective_End_Date
         , regexp_substr(legacy_Cost_Center, ''-[^-]+$'' ) as CC_Code
         , regexp_substr(legacy_Cost_Center, ''^.{4}'' ) as CC_Name
         , department_Name
    from (
          select * from JSON_TABLE( ''' || p_data || ''', ''$.data[*]''
            COLUMNS ( email_Address      VARCHAR2(255) PATH ''$.emailAddress''
                , gsi_Employee_Number    VARCHAR2(255) PATH ''$.gsiEmployeeNumber''
                , first_Name             VARCHAR2(255) PATH ''$.firstName''
                , last_Name              VARCHAR2(255) PATH ''$.lastName''
                , legislation_Code       VARCHAR2(255) PATH ''$.legislationCode''
                , country                VARCHAR2(255) PATH ''$.country''
                , legal_Entity_Name      VARCHAR2(255) PATH ''$.legalEntityName''
                , business_Unit_Name     VARCHAR2(255) PATH ''$.businessUnitName''
                , company_Code           VARCHAR2(255) PATH ''$.companyCode''
                , person_Id              VARCHAR2(255) PATH ''$.personId''
                , location_Id            VARCHAR2(255) PATH ''$.locationId''
                , location_Name          VARCHAR2(255) PATH ''$.locationName''
                , effective_Start_Date   VARCHAR2(255) PATH ''$.effectiveStartDate''
                , effective_End_Date     VARCHAR2(255) PATH ''$.effectiveEndDate''
                , legacy_Cost_Center     VARCHAR2(255) PATH ''$.legacyCostCenter''
                , hcm_Person_Number      VARCHAR2(255) PATH ''$.hcmPersonNumber''
                , hire_Date              VARCHAR2(255) PATH ''$.hireDate''
                , user_Person_Type       VARCHAR2(255) PATH ''$.userPersonType''
                , department_Name        VARCHAR2(255) PATH ''$.departmentName''
                )
            )
         )
    ' ; 

-- dbms_output.put_line(l_query);

apex_collection.create_collection_from_query
    ( p_collection_name => p_c_name
    , p_query           => l_query ) ;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_data,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;

end set_hr_paas_collection;

-----------------------------

function get_hr_paas_data_eid(p_employee_number number) return clob deterministic is
/** Returns the whole data set for employee.
2023.12.01 - 1.0 - Bhuvi Chauhan - Create function and getting data via gsiemployeenumber
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_data_eid';
    l_clob      clob;
begin

    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?gsiEmployeeNumber=' || p_employee_number
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    return l_clob;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_employee_number,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_data_eid;
-----------------------------

function get_hr_paas_data_pid(p_person_id number) return clob deterministic is
/** Returns the whole data set for employee.
2024.06.12 - 1.0 - Bhuvi Chauhan - Create function and getting data via hcmPersonNumber
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_data_pid';
    l_clob      clob;
begin

    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?hcmPersonNumber=' || p_person_id
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    return l_clob;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_person_id,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_data_pid;
---------------------------

function get_region_aria(p_sso varchar2 default v('APP_USER')) return varchar2 deterministic is
/** returns the user's Region from Aria.
2024.09.02 - 1.0 - Bhuvi Chauhan - create
2025.06.06 - 1.1 - Bhuvi Chauhan - Change in query
*/
  c_proc_name constant varchar2(61 char) := 'get_region_aria';
  c_proc_version constant varchar2(5 char) := '1.0';
--  l_country_code varchar2(10) := pcg.get_hr_country_code2(p_sso);
  l_region_name  varchar2(255);
begin

--   select nvl(region,'Employee left ORACLE') into l_region_name
--   from md_countries 
--   where l_country_code = country_code2 and rownum = 1;

--   select nvl(region,'Employee left ORACLE') into l_region_name
--   from md_countries c , md_employees e
--   where c.country_code2 = e.country 
--   and e.EMP_EMAIL_ADDRESS = lower(p_sso) 
--   --and is_active = 'Y' -- bhuvi added this as for payroll training tracker all ongoing report this employee is shoeing active but it is inactive -- 06-JUNE-2025
--   and rownum = 1;

-- -- bhuvi added this as for payroll training tracker all ongoing report this employee is showing active but it is inactive and change this query as coalesce because if no data found then nvl won't work -- 06-JUNE-2025
  SELECT COALESCE((
    SELECT region
     FROM md_countries c, md_employees e
        WHERE c.country_code2 = e.country 
        AND e.EMP_EMAIL_ADDRESS = lower(p_sso) 
        AND e.is_active = 'Y'
        AND ROWNUM = 1
    ), 'Employee left ORACLE') AS region_status into l_region_name
FROM DUAL;
  
  return l_region_name;
  
exception when others then
  --log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_data,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_region_aria;
--------------------------------

--------------------------------
function get_hr_paas_cmbnd_data(p_busniess_group_id varchar2) return clob deterministic is
/** Returns the whole data set for employee for a particular business group id.
2024.03.26 - 1.0 - Bhuvi Chauhan - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_cmbnd_data';
    l_clob      clob;
begin

    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?businessUnitId=' || p_busniess_group_id
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    return l_clob;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_busniess_group_id,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_cmbnd_data;
--------------------------------

function get_hr_paas_country_data(p_country varchar2) return clob deterministic is
/** Returns the whole data set of all employees belonging to a particular country.
2024.06.20 - 1.0 - Bhuvi Chauhan - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_country_data';
    l_clob      clob;
begin

    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?country=' || upper(p_country)
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    return l_clob;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_country,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_country_data;

--------------------------------

function get_hr_paas_dept_data(p_dept_name varchar2) return clob deterministic is
/** Returns the whole data set for employee for a particular department name (basically only for ).
2024.06.24 - 1.0 - Bhuvi Chauhan - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_dept_data';
    l_clob      clob;
begin

    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?departmentName=' || (p_dept_name)
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    return l_clob;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_dept_name,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_dept_data;
--------------------------------

function get_hr_paas_company_data(p_company_code varchar2) return clob deterministic is
/** Returns the whole data set for employee for a particular entity code.
2024.07.16 - 1.0 - Bhuvi Chauhan - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_hr_paas_company_data';
    l_clob      clob;
begin

    l_clob := apex_web_service.make_rest_request
        ( p_url => 'https://gxpap.oracle.com/oracle/oal/hcm/hrsecureview/hrdataservice/hrdata/hractivedataservice?companyCode=' || (p_company_code)
        , p_http_method => 'GET'
        , p_credential_static_id => 'hr_paas_cred'
        );
    return l_clob;

exception when others then
  log($$PLSQL_UNIT||'.'||c_proc_name,c_version,c_proc_version,get_sqlerrm(sqlcode)||' - '||p_company_code,sqlcode);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,get_SQLERRM(SQLCODE)); else raise; end if;
end get_hr_paas_company_data;
--------------------------------

FUNCTION get_reporting_mails (p_mail_id IN VARCHAR2) 
RETURN email_list_type is
/** Returns the emails of all employees who is reporting to the p_mail_id.
2024.12.19 - 1.0 - Rohit Kumar - create function
*/
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(30 char) := 'get_reporting_mails';

    v_mail_list email_list_type := email_list_type();
    
    
    CURSOR c_direct_reports IS
        SELECT EMP_EMAIL_ADDRESS
        FROM MD_EMPLOYEES
        WHERE upper(MANAGER_EMAIL_ADDRESS) = upper(p_mail_id);
    
BEGIN
  
    FOR i IN c_direct_reports LOOP
      
        v_mail_list.EXTEND;
        v_mail_list(v_mail_list.COUNT) := i.EMP_EMAIL_ADDRESS;
        
      
        FOR j IN (
            SELECT EMP_EMAIL_ADDRESS
            FROM MD_EMPLOYEES
            WHERE upper(MANAGER_EMAIL_ADDRESS) = upper(i.EMP_EMAIL_ADDRESS)
        ) LOOP
         
            v_mail_list.EXTEND;
            v_mail_list(v_mail_list.COUNT) := j.EMP_EMAIL_ADDRESS;
        END LOOP;
    END LOOP;
    
    RETURN v_mail_list;
END get_reporting_mails;
-----------------------------------
-- 1.0 - Bhuvi - 03-NOV-2025
-- Procedure to fix the temporary folders issue is shraepoint PPM migration
PROCEDURE fix_temp_entity_folders (
  p_site_id  IN VARCHAR2,
  p_drive_id IN VARCHAR2,
  p_user     IN VARCHAR2 DEFAULT v('APP_USER')
) IS
  c_proc_name CONSTANT VARCHAR2(30) := 'fix_temp_entity_folders';
  l_ln        VARCHAR2(32767);

  l_url       VARCHAR2(4000);
  l_body      CLOB;
  l_resp      CLOB;
  l_status    PLS_INTEGER;

  l_new_entity_id VARCHAR2(200);
  l_new_folder_name VARCHAR2(400);
  l_new_folder_path VARCHAR2(2000);

BEGIN
  l_ln := 'start';
  pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
          'Start fix_temp_entity_folders for site='||NVL(p_site_id,'?')||' drive='||NVL(p_drive_id,'?'),
          NULL, 'INFO');

  IF p_site_id IS NULL OR p_drive_id IS NULL THEN
    RAISE_APPLICATION_ERROR(-20090, 'Site or Drive not provided.');
  END IF;

  -- iterate sp_files rows that look like temporary entity ids (leading hyphen)
  FOR r IN (
    SELECT id,
           site_id,
           drive_id,
           folder_id,
           folder_path,
           filename,
           entity_name,
           entity_id
    FROM sp_files
    WHERE entity_id IS NOT NULL
      AND REGEXP_LIKE(entity_id, '^\-')   -- entity_id starts with '-'
    ORDER BY id
  ) LOOP
    BEGIN
      l_ln := 'processing sp_files.id=' || r.id || ' entity_id=' || r.entity_id;
      -- Look up the application attachment row which references this sp_files.id
      DECLARE
        l_bug_id     pay_attachments.bug_id%TYPE;
        l_project_id pay_attachments.project_id%TYPE;
      BEGIN
        SELECT bug_id, project_id
        INTO   l_bug_id, l_project_id
        FROM   pay_attachments
        WHERE  sp_file_id = r.id
        AND    ROWNUM = 1;  -- only need one mapping row

        -- Determine new name and new entity id
        IF l_bug_id IS NOT NULL THEN
          l_new_entity_id := TO_CHAR(l_bug_id);
          l_new_folder_name := 'SR ' || l_new_entity_id;
        ELSIF l_project_id IS NOT NULL THEN
          l_new_entity_id := 'PROJECT ' || TO_CHAR(l_project_id); -- keep entity_id consistent as text
          l_new_folder_name := 'PROJECT ' || TO_CHAR(l_project_id);
        ELSE
          -- both null (unlikely) — log and skip
          pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
                  'SKIP: sp_files.id='||r.id||' no bug_id or project_id found in pay_attachments',
                  NULL, 'WARN');
          CONTINUE;
        END IF;

        -- Build PATCH body to rename the folder (DriveItem)
        l_body := '{"name": "' || REPLACE(l_new_folder_name, '"', '\"') || '"}';

        -- PATCH URL for the item
        IF r.folder_id IS NULL THEN
          pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
                  'SKIP: sp_files.id='||r.id||' folder_id is NULL', NULL, 'WARN');
          CONTINUE;
        END IF;

        l_url := 'https://graph.microsoft.com/v1.0/sites/'||p_site_id||
                 '/drives/'||p_drive_id||'/items/'||r.folder_id;

        -- Call helper to do the REST PATCH
        l_resp := PRL_MS_GRAPH_UTL_PK.make_rest_request(l_url, 'PATCH', l_body);

        -- check status code set by helper (consistent with other functions)
        l_status := APEX_WEB_SERVICE.g_status_code;

        IF l_status NOT IN (200, 201) THEN
          pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
                  'FAILED PATCH: sp_files.id='||r.id||' url='||l_url||' HTTP='||l_status||' resp='||NVL(SUBSTR(l_resp,1,500),'<null>'),
                  NULL, 'ERROR');
          CONTINUE;
        END IF;

        -- compute new folder_path on DB side: replace last segment after final '/' with new folder name
        l_new_folder_path := REGEXP_REPLACE(r.folder_path, '/[^/]+$', '/' || l_new_folder_name);

        -- update sp_files metadata
        UPDATE sp_files
           SET entity_id   = l_new_entity_id,
               folder_path = l_new_folder_path,
               updated_by  = p_user,
               updated_at  = SYSTIMESTAMP
         WHERE id = r.id;

        COMMIT;

        pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
                'OK: sp_files.id='||r.id||' renamed to "'||l_new_folder_name||'" entity_id set to '||l_new_entity_id,
                NULL, 'INFO');

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
                  'NO_MAPPING: sp_files.id='||r.id||' entity_id='||r.entity_id||' - no pay_attachments row with sp_file_id',
                  NULL, 'WARN');
          -- CONTINUE;
      END;

    EXCEPTION
      WHEN OTHERS THEN
        -- Log and continue
        pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
                'ERROR processing sp_files.id='||r.id||' msg='||SQLERRM||' back='||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                SQLCODE, 'ERROR');
        ROLLBACK;
        CONTINUE;
    END;
  END LOOP;

  pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
          'Completed fix_temp_entity_folders', NULL, 'INFO');

EXCEPTION
  WHEN OTHERS THEN
    pcg.log(c_pkg_name||'.'||c_proc_name, c_version, '1.0',
            'FATAL: '||SQLERRM||' back='||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, SQLCODE, 'ERROR');
    RAISE;
END fix_temp_entity_folders;

-----------------------------------

-----------------------------------------------------------------------------
----HR Secure Views using oAuth2 authentication -----------------------------
-----------------------------------------------------------------------------

function get_bearer_token return varchar2 is
/** Returns authentication token (HR Secure Views with oAuth2).
    See also: https://einstein.oracle.com/q/rest-oauth-doesn-t-work-with-grant-type-password-1687
*/
   l_request_body   clob;
   l_token_json     clob;
   l_clob_response  clob;
   l_username       varchar2(500);
   l_password       varchar2(500);
   l_client_id      varchar2(500);
   l_clinet_secret  varchar2(500);
   l_token_url      varchar2(500);
   l_oal_ws_url     varchar2(500);   
   l_token          varchar2(4000);
   l_expiry         number;
   l_error          exception;
   PRAGMA EXCEPTION_INIT(l_error, -20002);
begin
   /* -- disabled for tests, can be accordingly configured later 
   select username, password, client_id, clinet_secret, TOKEN_URL, OAL_WS_URL
   into l_username, l_password, l_client_id, l_clinet_secret, l_token_url, l_oal_ws_url
   from OAL_HR_WS_DETAILS
   where ENVIRONMENT = 'GXPDT';
   */
   l_username      := 'payroll-apex_ww@oracle.com' ;
   l_password      := 'TK2vwhWU59Wy7j3D' ;
   l_client_id     := 'b91c8a1522c345a193485d94d0ef62e7' ;
   l_clinet_secret := '0a0becee-ef12-4f76-b9d7-ddfb68f30a52' ;
   l_token_url     := 'https://idcs-ae5270dfd3df46d9b4ba8427662a3e32.identity.oraclecloud.com/oauth2/v1/token' ;

   -- To call the authorization token from IDCS as explained in the OAL HR Confluence page, set the WS Headers as below
   apex_web_service.g_request_headers.delete;
   apex_web_service.g_request_headers( 1 ).name := 'Content-Type';
   apex_web_service.g_request_headers( 1 ).value := 'application/x-www-form-urlencoded';
   -- Calling the IDCS WS needs the below HTTP tequest body
   l_request_body := 'grant_type=password&scope=gxp/hrsecureviews&username=' || l_username || '&password=' || l_password;
   
   -- To Generate the authorization token call as below
   l_token_json := apex_web_service.make_rest_request(
       p_url         => l_token_url,
       p_http_method => 'POST',
       p_username    => l_client_id,
       p_password    => l_clinet_secret,
       p_body        => l_request_body );
   -- If WS call is successful and we are able to generate the authorization token from IDCS, then move ahead to call the OLA HR WS to fetch the data as JSON response
   if apex_web_service.g_status_code = 200 then
       l_token := json_value ( l_token_json, '$.access_token' );
       -- dbms_output.put_line(l_expiry);
       -- dbms_output.put_line(l_token);
        return l_token;
   else
       --
       -- HTTP Request failed; raise error or return NULL
       raise l_error;
       -- dbms_output.put_line(apex_web_service.g_status_code);

       return null;
   end if;
exception
   when others then
      log($$PLSQL_UNIT||'.get_bearer_token',c_version,'1',get_sqlerrm(sqlcode)||' - '||apex_web_service.g_status_code,sqlcode);
   raise;
end get_bearer_token;

-------------

begin
  c_ldap_key := read_sec_blob('Mail1');
  c_is_prod_env := is_prod_env;
  if trim(c_WS_ID) is null or trim(c_WS_ID) = '0' then
    wwv_flow_api.set_security_group_id;
    c_WS_NAME := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
    c_WS_ID := v('WORKSPACE_ID');
  end if;
end PCG_Payroll_Common_Good_pkg;
/