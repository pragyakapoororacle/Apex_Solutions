create or replace package body BUGT_pkg as
/** Oracle Global Payroll; Bug Template
Created: 2017.03.14
Developer: andras.a.toth@oracle.com
Modifications:
2017.03.14 - 1.0 - András Tóth - create
2017.03.30 - 1.1 - András Tóth - redesign of bug data and region/manager/GPO member associations.
2017.04.03 - 1.2 - András Tóth - adding the business approval process needs
2017.04.18 - 1.3 - András Tóth - redesign of email sending.
2017.04.21 - 1.4 - András Tóth - email sending and process review; bug-link generator
2017.05.08 - 1.5 - András Tóth - business logic changes; validation correction.
2017.05.10 - 1.6 - András Tóth - Modifying status names, Adding new Statuses: Rejected by GPO, Rejected by Manager. Added commit before copiing to PPM.
2017.07.11 - 1.7 - András Tóth - modifying email messages; adding the audit_log too to compliance with the CSARB completely.
2017.07.17 - 1.8 - András Tóth - Adding Operations, M&A workflow, Changing GPO workflow to approve SRs corresponding regional GPO too b4 going to Heather. Correcting Audit_Log; Changing to MD_COUNTRIES. Removing BUGT_TEST_USERS,bugt_gpat_roles_v  replaced by MD_TEST_USERS, md_users_v.
2018.03.20 - 1.9 - András Tóth - Changing approval workflow for quick response issues; updates to detect prod/test environment for the new stage.
2018.07.10 - 2.0 - András Tóth - optimization of SR loading...
2018.07.13 - 2.1 - András Tóth - adding direct status indication to the copy_2_Project_tracker function.
2021.03.29 - 2.2 - András Tóth - Updating for adding Access-type SRs, workflow update, cosmetics
2021.09.03 - 2.3 - András Tóth - PPM Project_ID-34924 Innovation Tracker enhancement
2021.09.03 - 2.4 - András Tóth - notification emails updating
2022.02.21 - 2.5 - András Tóth - Enhancements: Project_id = 38292, SR-37952, Project_id = 37112, Project_id = 38693, SR-39395, SR-37377, SR-37036, SR-47125. adding security Warn-Checks.
2022.07.08 - 2.6 - Marek Szwarczewski - Enhancements: SME can see bugs in their regions.
2023.02.02 - 2.7 - Bhuvi Chauhan - Enhancement: User comments in PPM #SR - 55097.
2023.03.29 - 2.8 - Bhuvi Chauhan - Enhacement: added and condition as souzan is on maternity leave and can't approve the requests so to not include her added this condition.
2023.07.17 - 2.9 - Bhuvi Chauhan - SR #81767 - For recdocs change the access administration from Jay to Karthik.   
2023.08.11 - 3.0 - Bhuvi Chauhan - SR #84765 - Most recent user comments are not visible in the PPM app and export report.
2024.05.15 - 3.1 - Bhuvi Chauhan - For jose requirement.
2024.07.01 - 3.2 - Bhuvi Chauhan - Adding two new items to the SR and removing annual cost indiciator (Project id - 68450)
2024.08.09 - 3.3 - Bhuvi Chauhan - Added new if conditionfor JOSE, as he has multiple region and in his case we don't want to call pcg.get_region just pick whaterver region he has selected in the SR so that correct manager can approve/reject the SR.
2024.08.12 - 3.4 - Rohit Kumar   - revert changes in "is_editable" function 
2024.08.21 - 3.5 - Bhuvi Chauhan - Added my initial changes to "is_editable function" as reverting the changes is not a solution and affect other users and other functionality, also added if clause in "is_approvable" to check the id, as for new sr with negative id this condition should not execute.
2024.11.15 - 3.6 - Bhuvi Chauhan - Changes in c_system_id__gpo_webpage function as it was impacting the GPO SR(s) insertion to PPM. Solved for SR - 127449
2025.02.04 - 3.7 - Bhuvi Chauhan - Change in copy_2_project_tracker
2025.02.26 - 3.8 - Bhuvi Chauhan - Added new system (AoR) for access and added maurice as repsonsible person for that.
2025.05.02 - 3.9 - Bhuvi Chauhan - See changes in approve_bug and reject_bug
2025.09.09 - 4.0 - Bhuvi Chauhan - Added att_upload_sp, att_update_sp,att_delete_sp,att_dowload_sp for sharepoint and apex integration.
2025.09.11 - 4.1 - Bhuvi Chauhan - Updated the att_update_sp for cases where user edit their prev attachment and upload a replacement (new attachment) for the existing one.
2025.08.10 - 4.2 - Bhuvi Chauhan - Added migrate_ppm_files_to_sp to move files from PPM to SharePoint
2025.12.22 - 4.3 - Bhuvi Chauhan - Added Rohit now for APEX Solution as Bhuvi is leaving Oracle

*/
 
c_version constant varchar2(5 char) := '4.3';
 
function c_INNO_SLACK_CHANNEL return varchar2 deterministic as
begin
  return '#global-payroll-innovation-ideas';
end;
 
procedure user_warn_check(p_user in varchar2) is
/** Check if user is the same as APP_USER in APEX Context.
  2022.03.17 - 1.0 - András Tóth - Create
*/
pragma autonomous_transaction;
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'user_warn_check';
  l_ln varchar2(c_32k char);
begin
  l_ln := 0;
  if p_user != v('APP_USER') then
    l_ln := 1;
    pcg.log(c_pkg_name||'.'||c_proc_name,c_version,c_proc_version,'[p_user='||p_user||', APP_USER='||v('APP_USER')|| '] '||DBMS_UTILITY.FORMAT_CALL_STACK,null, 'W');
    l_ln := 2;
  end if;
  l_ln := 3;
exception when others then
  pcg.log(c_pkg_name||'.'||c_proc_name,c_version,c_proc_version,'['||l_ln||'] '||SQLERRM,SQLCODE,'ERROR');
end user_warn_check;
 
function custom_test_auth (p_username in varchar2, p_password in varchar2) return boolean as
/** This function returns true if the package is installed on the test environment.
2017.04.28 - 1.0 - András Tóth - create
*/
begin
  return case when c_Test_WS_NAME = c_WS_NAME then true else false end;
end custom_test_auth;
 
FUNCTION cvv (p_constant IN VARCHAR2) RETURN varchar2 deterministic AS
/** returns varchar value of a package constant.
2017.03.14 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'cvv';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_res varchar2(4000 char);
BEGIN
  pcg.test_sql_free(p_constant);
  execute immediate 'begin :res := bugt_pkg.c_'||p_constant||'; end;' using out v_res;
  RETURN v_res;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END cvv;
 
FUNCTION cvn (p_constant IN VARCHAR2) RETURN number deterministic AS
/** returns numeric value of a package constant.
2017.03.14 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'cvn';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_res number;
BEGIN
  pcg.test_sql_free(p_constant);
  execute immediate 'begin :res := bugt_pkg.c_'||p_constant||'; end;' using out v_res;
  RETURN v_res;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END cvn;
 
function country_id_2_country_name(p_id number) return varchar2 deterministic as
/** returns the name of the country.
Developer comments: never refer to bugt_bugs_v or this will create a deadlock!
2017.03.20 - 1.0 - András Tóth - create
2017.04.04 - 1.1 - András Tóth - sub_region, country not shown, branch separator is - instead of /
2018.07.10 - 1.2 - András Tóth - deprecated; use the pcg.get_country_name_branch_c instead of this
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'country_id_2_country_name';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_ret varchar2(200 char);
  v_tmp number;
begin
  -- checks if the given country exists - if not, return null
  select count(*) into v_tmp from md_countries where id = p_id;
  if nvl(v_tmp,0) = 0 then return null; end if;
 
  -- creates the name of the country out of the hierarchy tree dimension table.
  select coalesce(country/*,sub_region,hub*/,region,company) || case when branch is not null then ' - '|| branch end into v_ret from md_countries where id = p_id;
  return v_ret;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END country_id_2_country_name;
 
function country_ids_2_country_names(p_ids varchar2) return varchar2 deterministic as
/** convert list of country ids to a list of country names;
Developer comments: never reference to the bugt_bugs_v view, or it is causing deadlock!
2017.03.20 - 1.0 - András Tóth - create
2018.07.13 - 1.1 - András Tóth - adding spaces for more confortable display
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'country_ids_2_country_names';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(4000 char) := '';
  v_id_list PCG_number_LIST;
begin
  -- checks if the list is not empty:
  if replace(trim(p_ids),' ','') is null then return null; end if;
  -- creates a collection (table) in the memory out of the list given.
  v_id_list := pcg.id_string_2_id_list(p_ids);
 
  -- adds country names to the string one by one from the country IDs.
  for i in 1..v_id_list.last loop
   v_ret := v_ret || case when v_ret is not null then ', ' end || country_id_2_country_name(v_id_list(i));
  end loop;
 
  return v_ret;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END country_ids_2_country_names;
 
-- TODO: attachment actions validations.
 
 
--procedure draw_country_tree as
--/** returns html as drawing all the countries in a tree
--2017.03.21 - 1.0 - András Tóth - create
--2017.03.27 - 1.1 - András Tóth - change levels
--*/
--  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'draw_country_tree';
--  c_proc_version constant varchar2(5 char) := '1.1';
--begin
--  htp.tableopen;
--  for i in (
--   select  t.*,
--   '<tr>'||
--   case when leaf is null then regexp_replace(regexp_replace(tree||'/', '[^/]+/','<td />'), '^<td />','' )||'<td>'|| substr(tree,length(tree)+2 - case when instr(reverse(tree),'/') = 0 then length(tree)+1 else instr(reverse(tree),'/') end ) ||'</td>'
--   else regexp_replace(tree||'/', '[^/]+/','<td />') || '<td><a onclick="document.getElementById(''P101_REGION_AFFECTED_ID'').value = document.getElementById(''P101_REGION_AFFECTED_ID'').value + ( (!!( document.getElementById(''P101_REGION_AFFECTED_ID'').value )) ? '','' : '''' ) + '''||to_char(id)||''';">'|| leaf ||'</a></td>'
--   end
--   ||'</tr>' col
--   from
--   (select tree, leaf, id from bugt_country_trees_V
--   union all select distinct substr(tree||'/', 1,instr(tree||'/','/',1,lev)-1 ), null, null
--       from bugt_country_trees_V, (select 1 lev from dual union all select 2 lev from dual union all select 3 lev from dual union all select 4 lev from dual union all select 5 lev from dual union all select 6 lev from dual)
--   ) t
--   order by tree||'/'||leaf nulls first
--  ) loop
--   htp.prn(i.col);
--  end loop;
--  htp.tableclose;
--exception when others then
--  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
--  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
--END draw_country_tree;
 
procedure mod_bug(p_id in out number, p_manager_email varchar2,p_system_id number,p_issue_type_id number,p_issue_subject varchar2,p_issue_description clob, -- earlier it was varchar2
    p_roles_used varchar2,p_workaround_sign char,p_workaround_details varchar2,p_workaround_hour_id number,p_headcount_id number,p_legally_required_sign char,
    p_after_workaround_hour_id number,p_legislated_change_date date,p_required_by_date date, p_regions varchar2, p_status_id number, p_eee_sign char, p_ee_pt_imp_sign char, p_hr_plcy_sign char, p_comments varchar2 default null,
    p_inno_type_id in number default null, p_inno_contributors in varchar2 default null, p_email varchar2 default v('APP_USER')) as
/** creates a bug
2017.03.21 - 1.0 - András Tóth - create
2017.03.28 - 1.1 - András Tóth - adding status and submit, update capabilities;
2017.03.31 - 1.2 - András Tóth - redesign of bugs.
2017.04.27 - 1.3 - András Tóth - when the SR is new, the bug id will be updated in attachments.
2018.07-13 - 1.4 - András Tóth - the "bugt bug countries" table is decommissioned; modify stakeholders first! Generating the ID from the sequence by hand, instead of letting the trigger.
2021.09.07 - 1.5 - András Tóth - Saving Innovation Tracker data also
2021.09.29 - 1.6 - András Tóth - adding the new EEE Sign.
2024.07.01 - 1.7 - Bhuvi Chauhan - adding the new EE impact and HR policy sign.
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'mod_bug';
  c_proc_version constant varchar2(5 char) := '1.6';
  v_id number;
  v_id_list PCG_number_LIST;
  v_row_id number;
begin
  -- checks if the bug is in editable status by the application user
  test_editable(p_id);
  user_warn_check(p_email);
 
  v_id:= case when nvl(p_id,-1) < 0 then BUGT_ID_SEQ.nextval else p_id end;
 
  -- TODO: Validation of input texts - no HTML injection attempt - especially with comments!!!
 
  -- notes who made the modification:
  insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (v_id,p_email,null,systimestamp,'EDIT');
  --merge into bugt_bug_stakeholders using dual on (bug_id=v_id and employee_email=p_email)
  --   when not matched then insert (bug_id,employee_email) values (v_id,p_email);
 
  if nvl(p_id,-1) < 0 then
  -- if it is a new bug, then inserts it
  insert into bugt_Bugs (
    id,
    employee_email,manager_email,system_id,issue_type_id,issue_subject,issue_description,
    roles_used,workaround_sign,workaround_details,workaround_hour_id,headcount_id,legally_required_sign,
    after_workaround_hour_id,legislated_change_date,required_by_date,status_id,raised_date,
    comments,country_ids,eee_sign,ee_pt_imp_sign,hr_plcy_sign
  ) values (
    v_id,
    p_email,upper(p_manager_email),p_system_id,p_issue_type_id,p_issue_subject,p_issue_description,
    p_roles_used,p_workaround_sign,p_workaround_details,p_workaround_hour_id,p_headcount_id,p_legally_required_sign,
    p_after_workaround_hour_id,p_legislated_change_date,p_required_by_date,p_status_id,systimestamp,
    p_comments,replace(p_regions,':',','),p_eee_sign,p_ee_pt_imp_sign,p_hr_plcy_sign
  );
 
  -- Insert/Update Innovation Type
  select max(id) into v_row_id from bugt_bug_inno_types where bug_id = v_id;
  if v_row_id is not null then
    update bugt_bug_inno_types t set type_id = p_inno_type_id where id = v_row_id;
  else
    insert into bugt_bug_inno_types t (id, bug_id, type_id) values (BUGT_ID_SEQ.nextval, v_id, p_inno_type_id);
  end if;
  ----
 
  -- Insert/Update Innovation Contributors
  select max(id) into v_row_id from bugt_bug_inno_contributors where bug_id = v_id;
  if v_row_id is not null then
    update bugt_bug_inno_contributors set employee_emails = p_inno_contributors where id = v_row_id;
  else
    insert into bugt_bug_inno_contributors (id, bug_id, employee_emails) values (BUGT_ID_SEQ.nextval, v_id, p_inno_contributors);
  end if;
  ----
 
  -- Setting attachments to the new bug id.
  update pay_attachments set bug_id = v_id where bug_id = p_id;
  update pay_links set bug_id = v_id where bug_id = p_id;
 
  -- return the new ID of the SR:
  p_id := v_id;
 
  else
  -- if it is an existing one then update it
  update bugt_Bugs
  set manager_email = upper(p_manager_email),
	  system_id = p_system_id,
	  issue_type_id = p_issue_type_id,
	  issue_subject = p_issue_subject,
	  issue_description = p_issue_description,
      roles_used = p_roles_used,
	  workaround_sign = p_workaround_sign,
	  workaround_details = p_workaround_details,
	  workaround_hour_id = p_workaround_hour_id,
	  headcount_id = p_headcount_id,
	  legally_required_sign = p_legally_required_sign,
     -- annual_cost_id = p_annual_cost_id,
	  after_workaround_hour_id = p_after_workaround_hour_id,
	  legislated_change_date = p_legislated_change_date,
	  required_by_date = p_required_by_date,
	  status_id = p_status_id,
	  comments = p_comments,
    country_ids = replace(p_regions,':',','),
    eee_sign = p_eee_sign,
    ee_pt_imp_sign = p_ee_pt_imp_sign,
    hr_plcy_sign = p_hr_plcy_sign
  where id = v_id;
 
  -- Insert/Update Innovation Type
  select max(id) into v_row_id from bugt_bug_inno_types where bug_id = v_id;
  if v_row_id is not null then
    update bugt_bug_inno_types t set type_id = p_inno_type_id where id = v_row_id;
  else
    insert into bugt_bug_inno_types t (id, bug_id, type_id) values (BUGT_ID_SEQ.nextval, v_id, p_inno_type_id);
  end if;
  ----
 
  -- Insert/Update Innovation Contributors
  select max(id) into v_row_id from bugt_bug_inno_contributors where bug_id = v_id;
  if v_row_id is not null then
    update bugt_bug_inno_contributors set employee_emails = p_inno_contributors where id = v_row_id;
  else
    insert into bugt_bug_inno_contributors (id, bug_id, employee_emails) values (BUGT_ID_SEQ.nextval, v_id, p_inno_contributors);
  end if;
  ----
 
  end if;
 
  insert into audit_log values (p_email,v('SESSION'),'Payroll Service Requests Template','SAVE','USER',systimestamp,c_application_id);
 
  commit;
exception when others then
  rollback;
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END mod_bug;
 
function status_name_2_status_id(p_status_name varchar2) return number deterministic as
/** finds id for a status name
2017.03.21 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'status_name_2_status_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret number;
begin
  -- checks if the status exists
  select nvl(count(*),0) into v_ret from bugt_Statuses where status_name = p_status_name;
  if v_ret=0 then return null; end if;
  -- retrieve the status id from the table
  select id into v_ret from bugt_Statuses where status_name = p_status_name;
  return v_ret;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END status_name_2_status_id;
 
function status_id_2_status_name(p_status_id number) return varchar2 deterministic as
/** finds name for a status id
2017.04.07 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'status_id_2_status_name';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret varchar2(4000 char);
begin
  -- checks if the status id exists
  select nvl(count(*),0) into v_ret from bugt_Statuses where id = p_status_id;
  if v_ret=0 then return null; end if;
  -- retrieve the status name from the table
  select status_name into v_ret from bugt_Statuses where id = p_status_id;
  return v_ret;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end status_id_2_status_name;
 
function get_score(p_id number) return number deterministic is
/** count the score of a bug
2017.03.22 - 1.0 - András Tóth - create
2018.07.10 - 1.1 - András Tóth - let it be deterministic; and autonomous
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_score';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret number := 0;
  v_exp clob;
begin
  -- checks if the bug exists
  select count(*) into v_ret from bugt_bugs where id = p_id;
  if nvl(v_ret,0) = 0 then return null; end if;
 
  -- create an SQL for score summing
  v_exp := 'select sum(0';
  -- collecting all the expressions (column of the bugt_bugs_v and conditions) and what score they represent
  for i in (select expression, score from bugt_Scores) loop
   -- security check of the expression:
   if i.expression||i.score like '%;%' then raise pcg.sql_injection; end if;
   -- adding the value of the score if the expression is true:
   v_exp := v_exp || '+nvl(case when '||i.expression||' then '||i.score||' end,0)';
  end loop;
  -- closing the SQL:
  v_exp := v_exp ||') scoresum from bugt_bugs_v where id = '||p_id;
  -- runs the created SQL and returning the counted sum.
  execute immediate v_exp into v_ret;
  return v_ret;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END get_score;
 
function get_severity_id(p_id number) return number deterministic is
/** count the severity ID of a bug
2017.03.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_severity_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret number;
begin
  -- checks if the bug score is in a given severity's limits
  select id into v_ret from bugt_Severities where get_score(p_id) >= score_from and get_score(p_id) <= score_to;
  return v_ret;
exception
  when no_data_found then return null;
  when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END get_severity_id;
 
function get_severity_name(p_id number) return varchar2 deterministic is
/** returns a severity name of a given bug
2017.03.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_severity_name';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret varchar2(4000 char);
begin
  -- checks if the bug score is in a given severity's limits
  select severity into v_ret from bugt_Severities where get_score(p_id) >= score_from and get_score(p_id) <= score_to;
  return v_ret;
exception
  when no_data_found then return null;
  when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END get_severity_name;
 
function get_BTS_country_id(p_country_id in number) return number deterministic is
/** returns the upper level country ID where a BTS exists for the input country.
-- Note: This function is not optimized for speed; use only few times.
2021.09.09 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bts_country_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_bts_country_id number;
  v_owner_country_id number;
begin
  if p_country_id is null then return null; end if;
  select max(country_id) into v_bts_country_id from bugt_inno_btses where country_id = p_country_id;
  if v_bts_country_id is null then
    for curr_country in (select * from md_countries where id = p_country_id) loop
      if curr_country.branch is not null then
        select id into v_owner_country_id from md_countries ac where ac.branch is null and ac.country = curr_country.country;
      elsif curr_country.country is not null then
        select id into v_owner_country_id from md_countries ac where ac.country is null and ac.sub_region = curr_country.sub_region;
      elsif curr_country.sub_region is not null then
        select id into v_owner_country_id from md_countries ac where ac.sub_region is null and ac.hub = curr_country.hub;
      elsif curr_country.hub is not null then
        select id into v_owner_country_id from md_countries ac where ac.hub is null and ac.region = curr_country.region;
      elsif curr_country.region is not null then
        select id into v_owner_country_id from md_countries ac where ac.region is null and ac.company = curr_country.company;
      elsif curr_country.company is not null then
        return null;
      end if;
      v_bts_country_id := get_BTS_country_id(v_owner_country_id);
    end loop;
  end if;
  return v_bts_country_id;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END get_BTS_country_id;
 
 
function get_bug_hierarchy_country_id(p_id in number, p_country_ids in varchar2 default null) return MD_COUNTRIES%ROWTYPE deterministic is
/** Returns the minimum commmon country-level of all countries of a Bug.
2021.09.21 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_hierarchy_country_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_country_ids varchar2(4000);
  v_minimum_required_country MD_COUNTRIES%ROWTYPE;
begin
  if p_id is null and p_country_ids is null then return null; end if;
  -- getting the Country what level of approval is needed.
  if p_country_ids is null then
    select COUNTRY_IDS into v_country_ids from bugt_bugs where id = p_id;
  else
    v_country_ids := p_country_ids;
  end if;
 
  for bug_country in ( select * from md_countries where id in (select column_value as country_id from table(pcg.id_string_2_id_list(v_country_ids))) ) loop
    if v_minimum_required_country.id is null
      then v_minimum_required_country := bug_country;
    elsif v_minimum_required_country.country = bug_country.country
      then select * into v_minimum_required_country from md_countries where branch is null and country = bug_country.country;
    elsif v_minimum_required_country.sub_region = bug_country.sub_region
      then select * into v_minimum_required_country from md_countries where country is null and sub_region = bug_country.sub_region;
    elsif v_minimum_required_country.hub = bug_country.hub
      then select * into v_minimum_required_country from md_countries where sub_region is null and hub = bug_country.hub;
    elsif v_minimum_required_country.region = bug_country.region
      then select * into v_minimum_required_country from md_countries where hub is null and region = bug_country.region;
    elsif v_minimum_required_country.company = bug_country.company
      then select * into v_minimum_required_country from md_countries where region is null and company = bug_country.company;
    end if;
  end loop;
 
  return v_minimum_required_country;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_hierarchy_country_id;
 
 
function get_bug_sum_likes_and_dislikes(p_bug_id in number) return number deterministic is
/** returns the calculated likes number of a given bug
-- Note: This function is not optimized for speed; use only few times.
2021.09.21 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_sum_likes_and_dislikes';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_likes number;
begin
  select sum(case YES_OR_NO_SIGN when 'Y' then 1 when 'N' then -1 end) into v_likes from bugt_bug_inno_likes l where bug_id = p_bug_id;
  return nvl(v_likes, 0);
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_sum_likes_and_dislikes;
 
 
function get_HUB_Leaders return PCG_string_LIST deterministic is
/** returns the list of HUB Leaders
2021.09.21 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_hub_leaders';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_hub_leaders_text varchar2(c_32k);
  v_hub_leaders PCG_string_LIST;
begin
 
  select listagg(payroll_manager,':') payroll_managers into v_hub_leaders_text from (
  with cs as (select payroll_manager, region, hub, sub_region from MD_COUNTRIES where deleted_sign is null)
    select c.payroll_manager from cs c where c.region is not null and c.hub is null union all
    select c.payroll_manager from cs c where c.hub is not null and c.sub_region is null
  );
 
  select distinct column_value bulk collect into v_hub_leaders from table(pcg.string_2_list(v_hub_leaders_text,':'));
 
  return v_hub_leaders;
 
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_HUB_Leaders;
 
 
function get_bug_BTSes(p_id in number, p_country_ids in varchar2 default null) return PCG_string_LIST deterministic is
/** returns a BTSes of a given bug
-- Note: This function is not optimized for speed; use only few times.
2021.09.08 - 1.0 - András Tóth - create
2021.09-17 - 1.1 - András Tóth - adding the p_country_ids parameter for optimizations
2021.09.21 - 1.2 - András Tóth - use the common function to get the Country ID.
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_btses';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_minimum_required_country MD_COUNTRIES%ROWTYPE;
  v_ret PCG_string_LIST;
begin
  if p_id is null and p_country_ids is null then return null; end if;
  -- getting the Country what level of approval is needed.
  v_minimum_required_country := get_bug_hierarchy_country_id(p_id, p_country_ids);
 
  /*** TEST: ***
  select
    to_char(v_minimum_required_country.id)||'-'||v_minimum_required_country.company||'-'||v_minimum_required_country.region||'-'||v_minimum_required_country.hub
    ||'-'||v_minimum_required_country.sub_region||'-'||v_minimum_required_country.country||'-'||v_minimum_required_country.branch
  bulk collect into v_ret from dual;
  return v_ret;
  **************/
 
  select lower(EMPLOYEE_EMAIL) bulk collect into v_ret
  from bugt_inno_btses where country_id = get_BTS_country_id(v_minimum_required_country.id);
  --and lower(EMPLOYEE_EMAIL) != 'souzan.al.bahra@oracle.com';
 -- added and condition as souzan is on maternity leave and can't approve the requests so to not include her added this condition.
 
  return v_ret;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_BTSes;
 
 
procedure submit_bug(p_id number, p_email varchar2 default v('APP_USER')) as
/** Submit a bug
2017.03.28 - 1.0 - András Tóth - create
2017.04.04 - 1.1 - András Tóth - adding team_member business process route.
2017.04.10 - 1.2 - András Tóth - adding email sending
2017.04.19 - 1.3 - András Tóth - redesign email sending
2017.07.17 - 1.4 - András Tóth - adding M&A, OP; change GPO approval chain.
2018.03.21 - 1.5 - András Tóth - updates on "removal of workflow" topic.
2018.07.13 - 1.6 - András Tóth - first we upload the stakeholders table, then make the update on the bug. use the base table instead of the view where possible.
2021.09.08 - 1.7 - András Tóth - Submitting an Innovation Idea SR.
2021.09.22 - 1.8 - András Tóth - adding Slack-messages.
2021.09.29 - 1.9 - András Tóth - adding Manager also to the loop for INNO-type requests.
2021.10.04 - 2.0 - András Tóth - adding more slack messages.
2022.03.08 - 2.1 - András Tóth - adding GPO Process issue_type; adding some more logs
2022.03.11 - 2.2 - Andr  s Tóth - correcting GPO Process workflow
2022.03.16 - 2.3 - András Tóth - correcting GPO Process workflow, adding Admin and Systems Tean cases.
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'submit_bug';
  c_proc_version constant varchar2(5 char) := '2.3';
  v_employee_email varchar2(256 char);
  v_role varchar2(256 char);
  v_title varchar2(4000 char);
  v_message_text varchar2(4000 char);
  v_to_notify PCG_string_LIST;
  v_gpo_team_member_id_of_sr number;
  v_gpo_team_member_of_sr varchar2(256 char);
  v_issue_type_id number;
  v_system_id number;
  v_ln varchar2(32767 char);
begin
  -- test if the bug is submitable, and the bug is valid
  v_ln := 'security testing';
  test_submissible(p_id);
  test_valid_bug(p_id);
  user_warn_check(p_email);
 
  -- collecting additional info for SR
  v_ln := 'collecting info';
  v_gpo_team_member_id_of_sr := get_team_member_id(p_id);
  v_gpo_team_member_of_sr := get_email(v_gpo_team_member_id_of_sr);
  v_issue_type_id := get_bug_issue_type_id(p_id);
  v_system_id := get_bug_system_id(p_id);
  bhu_logs('111',p_id||'-'||v_gpo_team_member_id_of_sr||'-'||v_gpo_team_member_of_sr||'-'||v_issue_type_id||'-'||v_system_id);
  v_ln := 'submission cases';
    --== when Innovation Idea is being submitted:
  if v_issue_type_id = c_issue_type_id__inno then
    -- was it a manager or analyst?
    bhu_logs('1','1 if');
    v_role := case when is_manager(p_email) = c_yes then 'MANAGER' when is_analyst(p_email) = c_yes then 'ANALYST' else null end;
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status will be submitted
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_submitted) where id = p_id returning employee_email into v_employee_email;
    -- get the BTSes to notify
    v_to_notify := get_bug_BTSes(p_id);
 
    --== when GPO Process is being submitted:
  elsif v_issue_type_id = c_issue_type_id__gpo_process then
    -- was it a manager or analyst?
   
    bhu_logs('2','2 elsif');
    v_ln := 'GPO Process - get role';
    v_role := case when is_manager(p_email) = c_yes then 'MANAGER' when is_analyst(p_email) = c_yes then 'ANALYST' else null end;
    -- save who made the submission:
    v_ln := 'GPO Process - save stakeholders';
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
 
    v_ln := 'GPO Process - checking affected system';
    --pcg.log(c_proc_name, c_version, c_proc_version, '(bug_id='||to_char(p_id)||') v_system_id='||to_char(v_system_id)||' c_system_id__gpo_webpage='||to_char(c_system_id__gpo_webpage)||' v_gpo_team_member_id_of_sr='||to_char(v_gpo_team_member_id_of_sr)||' get_op_manager_team_member_id='||to_char(get_op_manager_team_member_id)||' v_issue_type_id='||to_char(v_issue_type_id)||' c_issue_type_id__gpo_process='||to_char(c_issue_type_id__gpo_process), null, 'DEBUG');
    if v_system_id = c_system_id__gpo_webpage and ( p_email != get_email(get_op_manager_team_member_id) and nvl(is_admin(p_email),'N') = 'N' and nvl(is_team_member(p_email),'N') = 'N' ) then
      -- status will be submitted
      bhu_logs('3','3 if');
      v_ln := 'GPO Process - Webpage - update status';
      update bugt_Bugs set status_id = status_name_2_status_id(c_status_submitted) where id = p_id returning employee_email into v_employee_email;
      -- get the Manager to notify
      v_ln := 'GPO Process - Webpage - to notify';
      select manager_email bulk collect into v_to_notify from bugt_bugs where id = p_id;
    else
      -- status will be fully Approved:
      bhu_logs('4','4 else');
      v_ln := 'GPO Process - update status';
      update bugt_Bugs set status_id = status_name_2_status_id(c_status_director_approved) where id = p_id returning employee_email into v_employee_email;
      -- get Operations Manager to notify:
      v_ln := 'GPO Process - to notify';
      select v_gpo_team_member_of_sr bulk collect into v_to_notify from dual;
    end if;
 
    --== when submitor is a GPO Team Member and submittiong to own region or Qrc ==--
  elsif is_team_member(p_email) = c_yes  and  (p_email = v_gpo_team_member_of_sr or is_qrc(p_id) = c_yes ) then
    -- the requester was a team member:
    bhu_logs('5','5 elsif');
    v_role := 'GPO_TEAM_MEMBER';
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status to "approved by GPO"
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_gpo_approved) where id = p_id returning employee_email into v_employee_email;
    -- get the list of directors to notify
    select s.email bulk collect into v_to_notify from bugt_directors_v dv, bugt_director_notification s where s.email = dv.email;
 
    --== when submitor is a GPO Team Member, but the region is different and no Qrc ==--
  elsif is_team_member(p_email) = c_yes  and  p_email != v_gpo_team_member_of_sr  then
    -- the requester was a team member:
    bhu_logs('6','6 elsif');
    v_role := 'GPO_TEAM_MEMBER';
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status to "Approved by Manager" - waiting for GPO Approval
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_manager_approved) where id = p_id returning employee_email into v_employee_email;
    -- get the GPO Team Member to Notify:
    select v_gpo_team_member_of_sr bulk collect into v_to_notify from dual;
 
    --== when submitor is a payroll manager or analyst and not Qrc ==--
  elsif (is_manager(p_email) = c_yes or is_analyst(p_email) = c_yes) and is_qrc(p_id) = c_no then
  bhu_logs('7','7 elsif');
    -- was it a manager or analyst?
    v_role := case when is_manager(p_email) = c_yes then 'MANAGER' when is_analyst(p_email) = c_yes then 'ANALYST' else null end;
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status will be submitted
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_submitted) where id = p_id returning employee_email into v_employee_email;
    -- get the manager email to notify
    select manager_email bulk collect into v_to_notify from bugt_bugs where id = p_id;
 
    --== when submitor is a payroll manager or analyst and Qrc ==--
  elsif (is_manager(p_email) = c_yes or is_analyst(p_email) = c_yes) and is_qrc(p_id) = c_yes then
    -- was it a manager or analyst?
    bhu_logs('8','8 elsif');
    v_role := case when is_manager(p_email) = c_yes then 'MANAGER' when is_analyst(p_email) = c_yes then 'ANALYST' else null end;
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status will be manager-approved
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_manager_approved) where id = p_id returning employee_email into v_employee_email;
    -- get the GPO email to notify:
    select v_gpo_team_member_of_sr bulk collect into v_to_notify from dual;
 
    --== when submitor is an M&A or OP Analyst and no Qrc ==--
  elsif (is_ma_analyst(p_email) = c_yes or is_op_analyst(p_email) = c_yes) and is_qrc(p_id) = c_no then
  bhu_logs('9','9 elsif');
    -- the requester was an MA/OP Analyst:
    v_role := case when is_ma_analyst(p_email) = c_yes then 'M&A' else 'OPERATIONS' end || ' ANALYST';
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status will be submitted
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_submitted) where id = p_id returning employee_email into v_employee_email;
    -- get the manager email to notify
    select manager_email bulk collect into v_to_notify from bugt_bugs where id = p_id;
 
    --== when submitor is an M&A or OP Analyst and Qrc ==--
  elsif (is_ma_analyst(p_email) = c_yes or is_op_analyst(p_email) = c_yes) and is_qrc(p_id) = c_yes then
  bhu_logs('10','10 elsif');
    -- the requester was an MA/OP Analyst:
    v_role := case when is_ma_analyst(p_email) = c_yes then 'M&A' else 'OPERATIONS' end || ' ANALYST';
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status will be manager-approved
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_manager_approved) where id = p_id returning employee_email into v_employee_email;
    -- get the GPO to notify
    select v_gpo_team_member_of_sr bulk collect into v_to_notify from dual;
 
    --== when submitor is an M&A or OP Manager, Qrc and no-Qrc ==--
  elsif is_ma_manager(p_email) = c_yes or is_op_manager(p_email) = c_yes then
  bhu_logs('11','11 elsif');
    -- the requester was an MA/OP Manager:
    v_role := case when is_ma_manager(p_email) = c_yes then 'M&A' else 'OPERATIONS' end || ' MANAGER';
    -- save who made the submission:
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'SUBMIT');
    -- status will be manager-approved
    update bugt_Bugs set status_id = status_name_2_status_id(c_status_manager_approved) where id = p_id returning employee_email into v_employee_email;
    -- get the GPO team member to notify
    select bugt_pkg.get_email(v_gpo_team_member_of_sr) bulk collect into v_to_notify from dual;
    /*select TEAM_MEMBER_EMAIL bulk collect into v_to_notify from bugt_bugs where id = p_id;*/
 
  end if;
 
 
  v_ln := 'notifications';
  -- Get the submission email message template:
  ret_email_msg ('submit', v_title, v_message_text);
  -- sending out the messages to ones must be notified:
  for i in ( select column_value as manager from table(v_to_notify) ) loop
    sendmail(i.manager, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
     bhu_logs('112',p_id||'-'||i.manager);
  end loop;
  -- Get the submission Slack message template:
  ret_email_msg ('submit-slack', v_title, v_message_text);
  -- sending out the messages to ones must be notified:
  for i in ( select column_value as manager from table(v_to_notify) ) loop
    begin
      sendslack(i.manager, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
    exception when others then null;
    end;
  end loop;
 
 
  if v_issue_type_id = c_issue_type_id__inno then
    -- notify direct manager also:
    ret_email_msg ('submitnoaction', v_title, v_message_text);
    sendmail(pcg.get_manager(p_email), v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
 
    ret_email_msg ('submitnoaction-slack', v_title, v_message_text);
    begin
      sendslack(pcg.get_manager(p_email), pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
    exception when others then null;
    end;
 
    -- Notify Slack channel
    ret_email_msg ('submit-channel-slack', v_title, v_message_text);
    begin
      sendslack(null, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), c_INNO_SLACK_CHANNEL);
    exception when others then null;
    end;
  end if;
 
  -- Adjustments:  Auto-Approval for GPO Process requests:
  v_ln := 'adjust for auto-approval';
  bhu_logs('999','999 before entry to copy2project tracker v_issue_type_id '||v_issue_type_id||' c_issue_type_id__gpo_process '||c_issue_type_id__gpo_process||' v_system_id '||v_system_id||' c_system_id__gpo_webpage '||c_system_id__gpo_webpage
  ||' p_email '||p_email||' get_email(get_op_manager_team_member_id) '||get_email(get_op_manager_team_member_id)||' is_admin(p_email) '||is_admin(p_email)||' is_team_member(p_email) '||is_team_member(p_email));
  --999 before entry to copy2project tracker v_issue_type_id 50223 c_issue_type_id__gpo_process 50223 v_system_id 50226 c_system_id__gpo_webpage 
  --p_email WENDY.FAN@ORACLE.COM get_email(get_op_manager_team_member_id) CIPRIAN.ANTONESCU@ORACLE.COM is_admin(p_email) N is_team_member(p_email) N

  if v_issue_type_id = c_issue_type_id__gpo_process and (v_system_id != c_system_id__gpo_webpage or p_email = get_email(get_op_manager_team_member_id) or is_admin(p_email) = 'Y' or is_team_member(p_email) = 'Y') then
  bhu_logs('1000','1000 elsif');
    v_ln := 'move to PPM...';
    copy_2_Project_tracker(p_id, c_PPM_approved, p_email);
  end if;
 
  -- Audit Log for CSSAP compliance
  v_ln := 'audit log';
  insert into audit_log values (p_email,v('SESSION'),'Payroll Service Requests Template','SUBMIT',v_role,systimestamp,c_application_id);
  commit;
exception when others then
  rollback;
  pcg.log(c_proc_name, c_version, c_proc_version, '(bug_id='||to_char(p_id)||') '||case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END submit_bug;
 
function is_valid_bug(p_id number) return char as
-- returns yes when bug is valid.
begin
  test_valid_bug(p_id);
  return c_yes;
exception when others then if SQLCODE = -20900 then return c_no; else raise; end if;
end is_valid_bug;
 
procedure test_valid_bug(p_id number) as
/** Testing the validation cases of a Service Request
2017.03.28 - 1.0 - András Tóth - create
2017.07.17 - 1.2 - András Tóth - manager email is not required when gpo, m&A or OP manager submits it.
2018.03.21 - 1.3 - András Tóth - updates on "removal of workflow" topic.
2018.04.16 - 1.4 - András Tóth - "removal of workflow" validation correction
2018.07.13 - 1.5 - András Tóth - the "bugt bug countries" table is decommissioned; get data from bugt_bugs, instead of the bugt_bugs_v, what is more accurate :-)
2021.09.08 - 1.6 - András Tóth - Innovation Tracker updates
2021.09.29 - 1.7 - András Tóth - Adding EEE Sign
2022.03.16 - 1.8 - András Tóth - adding GPO Process validations
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_valid_bug';
  c_proc_version constant varchar2(5 char) := '1.8';
 
-- checks if the bug mets all requirements
  v_tmp number;
  v_inno_type_id number;
begin
  for i in (select
  manager_email, system_id, employee_email,issue_type_id,issue_subject,issue_description,workaround_sign,workaround_details,after_workaround_hour_id,headcount_id,
  legally_required_sign,legislated_change_date,required_by_date,workaround_hour_id,country_ids,eee_sign
  from bugt_bugs where id = p_id) loop
   if
     is_admin(i.employee_email) != c_yes and
     is_qrc(p_id) = c_no and
     i.MANAGER_EMAIL is null and not(
       is_team_member(i.employee_email) = c_yes or
       is_ma_manager(i.employee_email) = c_yes or
       is_op_manager(i.employee_email) = c_yes
     ) then raise_application_error(-20900,'no manager selected'); end if;
   if i.SYSTEM_ID is null then raise_application_error(-20900,'no affected system selected'); end if;
   if i.ISSUE_TYPE_ID is null then raise_application_error(-20900,'no issue type selected'); end if;
   if trim(i.issue_subject) is null then raise_application_error(-20900,'no issue subject provided'); end if;
   if i.ISSUE_DESCRIPTION is null then raise_application_error(-20900,'no issue description provided'); end if;
   if i.WORKAROUND_SIGN is null then raise_application_error(-20900,'no workaround sign provided'); end if;
   if i.WORKAROUND_SIGN = c_yes and i.WORKAROUND_DETAILS is null then raise_application_error(-20900,'no workaround details provided'); end if;
   if i.WORKAROUND_SIGN = c_yes and i.WORKAROUND_HOUR_ID is null then raise_application_error(-20900,'no workaround hours provided'); end if;
   if i.WORKAROUND_SIGN = c_yes and i.AFTER_WORKAROUND_HOUR_ID is null then raise_application_error(-20900,'no workaround hours after solution provided'); end if;
   if i.HEADCOUNT_ID is null then raise_application_error(-20900,'no affected headcount provided'); end if;
   if i.LEGALLY_REQUIRED_SIGN is null then raise_application_error(-20900,'no legally required sign provided'); end if;
   if i.LEGALLY_REQUIRED_SIGN = c_yes and i.LEGISLATED_CHANGE_DATE is null then raise_application_error(-20900,'no legislated change date provided'); end if;
  -- if i.ANNUAL_COST_ID is null then raise_application_error(-20900,'no annual cost provided'); end if;
   if i.REQUIRED_BY_DATE is null then raise_application_error(-20900,'no required by date provided'); end if;
   if nvl(i.manager_email,'-1') = nvl(i.employee_email,'-2') then raise_application_error(-20900,'The selected manager cannot be equal to the requester.'); end if;
   if trim(i.country_ids) is null then raise_application_error(-20900,'no countries/regions selected'); end if;
   if i.ISSUE_TYPE_ID = c_issue_type_id__inno then
     select max(id) into v_inno_type_id from bugt_bug_inno_types where bug_id = p_id;
     if v_inno_type_id is null then raise_application_error(-20900,'no Innovation Type selected'); end if;
   end if;
  end loop;
end test_valid_bug;
 
function c_issue_type_id__inno return number deterministic is
  v_issue_type_id__inno number;
begin
   select min(id) into v_issue_type_id__inno from BUGT_ISSUE_TYPE where ISSUE_TYPE_NAME = 'Innovation Idea';
   return v_issue_type_id__inno;
end;
 
function c_issue_type_id__gpo_process return number deterministic is
  v_issue_type_id__inno number;
begin
   select min(id) into v_issue_type_id__inno from BUGT_ISSUE_TYPE where ISSUE_TYPE_NAME = 'GPO Process';
   return v_issue_type_id__inno;
end c_issue_type_id__gpo_process;
 
function c_issue_type_id__M_and_A return number deterministic is
  v_issue_type_id__M_and_A number;
begin
   --select min(id) into v_issue_type_id__M_and_A from BUGT_ISSUE_TYPE where ISSUE_TYPE_NAME = 'M&A'; -- TODO: Not Implemented yet !!!!
   v_issue_type_id__M_and_A := -9999999999;
   return v_issue_type_id__M_and_A;
end c_issue_type_id__M_and_A;

--Bhuvi Chauhan - 15.11.2024 - Changed this condition SHOW_IN_GPO_PROCESS = c_yes to c_no as now the website doesn't fall under GPO Process. Also this has an impact in submit_bug where the code copy_2_project tracker is not running as this condition was failing earlier, beacuse this function was returning numm as SHOW_IN_GPO_PROCESS = c_yes this condition doesn't makes sense.
function c_system_id__gpo_webpage return number deterministic is
  v_system_id__gpo_webpage number;
begin
  select min(id) into v_system_id__gpo_webpage from bugt_systems where system_name = 'Website' and SHOW_IN_GPO_PROCESS = c_NO and ACTIVE_SIGN = c_yes;
  return v_system_id__gpo_webpage;
end c_system_id__gpo_webpage;
 
procedure del_bug(p_id number, p_email varchar2 default v('APP_USER')) as
/** delete a bug
2017.03.29 - 1.0 - András Tóth - create
2018.07.13 - 1.1 - András Tóth - "bugt bug countries" is decommissioned.
2021.09.10 - 1.2 - András Tóth - adding bugt_bug_* tables to be also deleted.
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'del_bug';
  c_proc_version constant varchar2(5 char) := '1.2';
begin
  -- test if the bug in editable status
  test_deletable(p_id);
  user_warn_check(p_email);
 
  -- save who made the deletion:
  insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,null,systimestamp,'DELETE');
 
  -- delete the bug itself
  delete from bugt_bugs where id = p_id;
  delete from bugt_bug_inno_approvals where id = p_id;
  delete from bugt_bug_comments where id = p_id;
  delete from bugt_bug_inno_contributors where id = p_id;
  delete from bugt_bug_inno_types where id = p_id;
  delete from bugt_bug_inno_likes where id = p_id;
  delete from bugt_bug_stakeholders where id = p_id;
 
  insert into audit_log values (p_email,v('SESSION'),'Payroll Service Requests Template ('||to_char(p_id)||')','DEL','USER',systimestamp,c_application_id);
  commit;
exception when others then
  rollback;
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END del_bug;
 
function get_bug_region(p_bug_id number) return varchar2 deterministic as
/** returns the bug region of the bug; if multiple regions affected then "GLOBAL" returned
2017.04.03 - 1.0 - András Tóth - create
2018.07.10 - 1.1 - András Tóth - let it be deterministic
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_region';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(4000 char);
begin
  -- select the affected countries regions.
  select distinct get_region(c.column_value) into v_ret from table(pcg.id_string_2_id_list(get_country_ids(p_bug_id))) c;
  return v_ret;
exception
when no_data_found then return null; -- null if no region found
when TOO_MANY_ROWS then return 'GLOBAL'; -- global if multiple regions found
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_region;
 
function get_team_member_id_byc(p_country_ids in varchar2, p_system_id in number, p_issue_type_id in number) return number deterministic as
/** gives back the team member's id who is responsible for the countries
2017.04.26 - 1.0 - András Tóth - create
2018.07.10 - 1.1 - András Tóth - let it be deterministic
2021.03.29 - 1.2 - András Tóth - adding the Affected System ID into the calculation.
2021.09.23 - 1.3 - András Tóth - handling `Oracle` company as Global-HUB, adding some debug log
2022.03.08 - 1.4 - András Tóth - Adding GPO Process type to the game.
2024.12.16 - 1.5 - Bhuvi Chauhan - Adjusting the workflow for APEX, Macros, Automation and Osvc Issues. Now Systems team will act as GOP Team member as will Approve/Reject these SR(s).
2025.02.26 - 1.5 - Bhuvi Chauhan - Added new system (AoR) for access and added maurice as repsonsible person for that.
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_team_member_id_byc';
  c_proc_version constant varchar2(5 char) := '1.6';
  v_ln varchar2(4000 char);
  v_tmp number;
  v_team_member_id number;
  v_region varchar2(4000 char);
  v_selected_system_name varchar2(4000 char);
begin
  v_ln := 1;
  select max(SYSTEM_NAME) into v_selected_system_name from BUGT_SYSTEMS where p_system_id = id;
  v_ln := 2;
  if p_issue_type_id = c_issue_type_id__gpo_process then 
    v_ln:=2.2;
    v_team_member_id := get_op_manager_team_member_id();
    v_ln:=2.3;
    return v_team_member_id;
  end if;
 
 --bhuvi making changes here for SR 81767
  if v_selected_system_name = 'Internal SharePoint' -- on 25 th aug changes this system name to Internal SharePoint from SecureSites for SR 153158
  --v_selected_system_name in ('SecureSites', 'RecDocs')
  then -- return the global manager
  -- bhuvi changing the region is null to region = GLOBAL , so sr's goes to Milagro as earlier it goes to JAY . Change for SR 142256
      v_ln := 3;
      select max(tr.team_member_id) into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region = 'GLOBAL'/*hub = 'GLOBAL_HUB'*/;
      v_ln := 4;
      return v_team_member_id;
  elsif v_selected_system_name = 'ADP' then
      -- return the EMEA manager:
      v_ln := 5;
      select max(tr.team_member_id) into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region = 'EMEA' and hub is null;
      v_ln := 6;
      return v_team_member_id;
  elsif v_selected_system_name = 'External SharePoint' then -- on 25 th aug changes this system name to External SharePoint from Recdocs for SR 153158
  v_ln := 7;
      select max(tr.team_member_id) into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region = 'Global'/*hub = 'GLOBAL_HUB'*/;
      v_ln := 8;
      return v_team_member_id;
      --Added AoR and affeced person code for SR 136439
  elsif v_selected_system_name = 'AoR' then -- Maurice
  v_ln := 9;
      return 4126821501;
  elsif v_selected_system_name = 'APEX Solution' then  --bhuvi before, rohit now
    v_ln := 10;
    --return 2535908246;
    return 3038786186; -- Bhuvi added rohit for APEX, Bhuvi leaving Oracle. 
  elsif v_selected_system_name in ('Macro','Automation (i.e. RPA)') then --anupam
    v_ln := 11;
    return 1724386920;
  elsif v_selected_system_name = 'OSvC (Right Now CX Tool)' then  --marek
    v_ln := 12;
    return 4269972627;
  
  end if;
 
  v_ln := 12;
  select count(distinct tr.team_member_id) into v_tmp
    from table(pcg.id_string_2_id_list(p_country_ids)) c, bugt_team_respons_v tr where c.column_value = tr.country_id;
  v_ln := 13;
  if nvl(v_tmp,0) = 0 then return null; -- if no countries found.
  elsif v_tmp = 1 then -- if one team member found, then return the team member id
   v_ln := 14;
   select distinct tr.team_member_id into v_team_member_id from table(pcg.id_string_2_id_list(p_country_ids)) c, bugt_team_respons_v tr where c.column_value = tr.country_id;
   return v_team_member_id;
  else -- when multiple team members found:
    -- are the countries in the same region?
    v_ln := 15;
    select count (distinct region) into v_tmp from md_countries cd,bugt_team_respons_v tr, table(pcg.id_string_2_id_list(p_country_ids)) c where c.column_value = tr.country_id and cd.id = tr.country_id;
    v_ln := 16;
    if nvl(v_tmp,0) = 1 then -- if the countries are in the same region
        -- return the region manager
        v_ln := 17;
        select distinct region into v_region from md_countries cd,bugt_team_respons_v tr, table(pcg.id_string_2_id_list(p_country_ids)) c where c.column_value = tr.country_id and cd.id = tr.country_id;
        v_ln := 18;
        select distinct tr.team_member_id into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region = v_region and hub is null and sub_region is null;
        return v_team_member_id;
    else -- when the countries are not in the same region (multiple regions returned)
        -- return the global manager
        v_ln := 19;
        select tr.team_member_id into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region is null/*hub = 'GLOBAL_HUB'*/;
        return v_team_member_id;
    end if;
  end if;
  v_ln := 20;
  return '-1'; -- on error
exception when others then
    pcg.log(c_proc_name, c_version, c_proc_version, '('||v_ln||') '||case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
    if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_team_member_id_byc;
 
function get_bug_system_id(p_bug_id number) return number deterministic is
/** givs back the System ID of the bug
2022.03.08 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_system_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_system_id number;
begin
  select min(system_id) into v_system_id from bugt_bugs where id = p_bug_id;
  return v_system_id;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_system_id;
 
function get_bug_issue_type_id(p_bug_id number) return number deterministic as
/** givs back the Issue Type ID of the bug
2021.09.08 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_issue_type_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_issue_type_id number;
begin
  select min(issue_type_id) into v_issue_type_id from bugt_bugs where id = p_bug_id;
  return v_issue_type_id;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_issue_type_id;
 
function get_op_manager_team_member_id return number deterministic is
/** gives back the team member id of the Operations Team's manager.
2022.03.09 - 1.0 - András Tóth - create --> currently it is Ciprian Antonescu
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_op_manager_team_member_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ln varchar2(4000 char);
  v_team_member_id number := 1365690674; -- bhuvi making this change to make ciprian get all GPO SR's
begin
  v_ln := 1;
 -- select max(id) into v_team_member_id from md_users_v where role = 'OPERATIONS_MANAGER';
  v_ln := 2;
  return v_team_member_id;
exception when others then
    pcg.log(c_proc_name, c_version, c_proc_version, '('||v_ln||') '||case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
    if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_op_manager_team_member_id;
 
function get_team_member_id(p_bug_id number) return number deterministic as
/** gives back the team member's id who is responsible for the bug
2017.03.31 - 1.0 - András Tóth - create
2018.07.10 - 1.1 - András Tóth - let it be deterministic
2021.03.29 - 1.2 - András Tóth - adding the Affected System ID into the calculation.
2021.09.23 - 1.3 - András Tóth - handling `Oracle` company as Global-HUB, adding some debug log
2022.03.08 - 1.4 - András Tóth - adding GPO Process-type.
2024.12.16 - 1.5 - Bhuvi Chauhan - Adjusting the workflow for APEX, Macros, Automation Production Issues. Now Systems team will act as GOP Team member as will Approve/Reject these SR(s).
2025.02.26 - 1.5 - Bhuvi Chauhan - Added new system (AoR) for access and added maurice as repsonsible person for that.
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_team_member_id';
  c_proc_version constant varchar2(5 char) := '1.6';
  v_ln varchar2(4000 char);
  v_tmp number;
  v_team_member_id number;
  v_region varchar2(4000 char);
  v_selected_system_name varchar2(4000 char);
  v_system_id number;
  v_issue_type_id number;
begin
  v_ln:=1;
  -- System ID checking:
  select max(system_id), max(issue_type_id) into v_system_id, v_issue_type_id from bugt_bugs where id = p_bug_id;
  v_ln:=2;
  select max(SYSTEM_NAME) into v_selected_system_name from BUGT_SYSTEMS where v_system_id = id;
 
  v_ln:=2.1;
  if v_issue_type_id = c_issue_type_id__gpo_process then
    v_ln:=2.2;
    v_team_member_id := get_op_manager_team_member_id();
    v_ln:=2.3;
    return v_team_member_id;
  end if;
 
  v_ln:=3;
  if v_selected_system_name = 'Internal SharePoint' -- on 25 th aug changes this system name to Internal SharePoint from SecureSites for SR 153158
  --v_selected_system_name in ('SecureSites', 'RecDocs')
  then -- return the global manager
  -- bhuvi changing the region is null to region = GLOBAL , so sr's goes to Milagro as earlier it goes to JAY . Change for SR 142256
      v_ln:=4;
      select max(tr.team_member_id) into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region = 'GLOBAL';
      return v_team_member_id;
  elsif v_selected_system_name = 'ADP' then
      -- return the EMEA manager:
      v_ln:=5;
      select max(tr.team_member_id) into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and nvl(region,'GLOBAL') = 'EMEA' and hub is null;
      return v_team_member_id;
  elsif v_selected_system_name = 'External SharePoint' then -- on 25 th aug changes this system name to External SharePoint from Recdocs for SR 153158
      v_ln := 7;
      select max(tr.team_member_id) into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region = 'Global'/*hub = 'GLOBAL_HUB'*/;
      v_ln := 8;
      return v_team_member_id;
        --Added AoR and affeced person code for SR 136439
  elsif v_selected_system_name = 'AoR' then -- Maurice
  v_ln := 9;
      return 4126821501;
  elsif v_selected_system_name = 'APEX Solution' then  --bhuvi
    v_ln := 10;
    return 2535908246; 
   -- return 3038786186; -- moved back the responsibility to bhuvi
  elsif v_selected_system_name in ('Macro','Automation (i.e. RPA)') then --anupam
    v_ln := 11;
    return 1724386920;
  elsif v_selected_system_name = 'OSvC (Right Now CX Tool)' then  --marek
    v_ln := 12;
    return 4269972627;
  end if;
 
  -- do the countries have the same team member responsers?
  v_ln:=6;
  select count(distinct tr.team_member_id) into v_tmp
    from table(pcg.id_string_2_id_list(get_country_ids(p_bug_id))) c, bugt_team_respons_v tr where c.column_value = tr.country_id;
  v_ln:=7;
  if nvl(v_tmp,0) = 0 then return null; -- if no countries found.
  elsif v_tmp = 1 then -- if one team member found, then return the team member id
   v_ln:=8;
   select distinct tr.team_member_id into v_team_member_id from table(pcg.id_string_2_id_list(get_country_ids(p_bug_id))) c, bugt_team_respons_v tr where c.column_value = tr.country_id;
   return v_team_member_id;
 else -- when multiple team members found:
    -- are the countries in the same region?
    v_ln:=9;
    select count (distinct nvl(region,'GLOBAL')) into v_tmp from md_countries cd,bugt_team_respons_v tr, table(pcg.id_string_2_id_list(get_country_ids(p_bug_id))) c where c.column_value = tr.country_id and cd.id = tr.country_id;
    if nvl(v_tmp,0) = 1 then -- if the countries are in the same region
        -- return the region manager
        v_ln:=10;
        select distinct nvl(region,'GLOBAL') into v_region from md_countries cd,bugt_team_respons_v tr, table(pcg.id_string_2_id_list(get_country_ids(p_bug_id))) c where c.column_value = tr.country_id and cd.id = tr.country_id;
        v_ln:=11;
        select distinct tr.team_member_id into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and nvl(region,'GLOBAL') = nvl(v_region,'GLOBAL') and hub is null and sub_region is null;
        return v_team_member_id;
    else -- when the countries are not in the same region (multiple regions returned)
        -- return the global manager
        v_ln:=12;
        select tr.team_member_id into v_team_member_id from md_countries cd,bugt_team_respons_v tr where cd.id = tr.country_id and region is null;
        return v_team_member_id;
    end if;
  end if;
  return '-1'; -- on error
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, '('||v_ln||') '||case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END get_team_member_id;
 
function get_country_ids(p_bug_id number) return varchar2 is
/** gives back the country ids for the bug
2017.03.31 - 1.0 - András Tóth - create
2018.07.10 - 1.1 - András Tóth - not to use the "bugt bug countries v"; because it can cause deadlocks!
2018.07.13 - 1.2 - András Tóth - the "bugt bug countries" table is also decommissioned
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_country_ids';
  c_proc_version constant varchar2(5 char) := '1.2';
  v_country_ids varchar2(4000 char);
begin
  select country_ids into v_country_ids from bugt_bugs where id = p_bug_id;
  return v_country_ids;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END get_country_ids;
 
function get_user_id(p_email varchar2) return number deterministic is
/** returns the user id for an sso email address.
2017.03.31 - 1.0 - András Tóth - create
2024.05.20 - 1.1 - Bhuvi Chauhan - modified the query to select the user id by adding p_region as a parameter
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_user_id';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin
  -- returns user id from the roles view. (it is a hash value based on email_address)
  --select distinct id into v_tmp from md_users_v where username = upper(p_email) group by id;
  -- Bhuvi/Marek Changes  
    select id into v_tmp from( select id
                                , row_number() over (partition by id order by region) rn
                             from md_users_v
                            where username = upper(p_email)
                         ) where rownum = 1;
  return v_tmp;
exception
when no_data_found then return null; -- return null if not exists
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_user_id;
 
function get_email(p_id number) return varchar2 deterministic is
/** returns the SSO email address of a user
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_email';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp varchar2(256 char);
begin
  select username into v_tmp from md_users_v where id = p_id group by username;
  return v_tmp;
exception
when no_data_found then return null; -- return null if not exists
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_email;
 
procedure test_payroll_org_member(p_email varchar2) is
/** tests if user has role payroll roles
2021.09.07 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_payroll_org_member';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin select distinct 1 into v_tmp from bugt_payroll_org_members_v where email = upper(p_email);
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_payroll_org_member;
 
procedure test_analyst(p_email varchar2, p_region varchar2 default null) is
/** tests if user has role payroll analyst
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_analyst';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin select 1 into v_tmp from bugt_analysts_v where email = upper(p_email) and (upper(region) = upper(p_region) or p_region is null);
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_analyst;
 
procedure test_director(p_email varchar2) is
/** tests if user has role
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_director';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin select 1 into v_tmp from bugt_directors_v where email = upper(p_email);
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_director;
 
procedure test_manager(p_email varchar2, p_region varchar2 default null) is
/** tests if user has role payroll manager
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_manager';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin select distinct 1 into v_tmp from bugt_managers_v where email = upper(p_email) and (upper(region) = upper(p_region) or p_region is null);
bhu_logs(12101,'is_manager','clob12101 p_email '||p_email||' p_region '||p_region||' v_tmp '||v_tmp);
exception
when no_data_found then raise pcg.not_authorized;
bhu_logs(1210,'is_manager in exception','clob1210 p_email '||p_email||' p_region '||p_region);
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_manager;
 
procedure test_team_member(p_email varchar2) is
/** tests if user has role
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_team_member';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin select 1 into v_tmp from bugt_team_members_v where email = upper(p_email);
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_team_member;
 
procedure test_admin(p_email varchar2) is
/** tests if user has role
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_admin';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin select 1 into v_tmp from md_users_v where USERNAME = upper(p_email) and role_name = 'ADMINISTRATOR';
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_admin;
 
function is_payroll_org_member(p_email varchar2) return char deterministic is
begin
 test_payroll_org_member(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_payroll_org_member;
 
function is_analyst(p_email varchar2, p_region varchar2 default null) return char deterministic is
begin
bhu_logs(11,'is_analyst ','clob11');
 test_analyst(p_email,p_region);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_analyst;
 
function is_director(p_email varchar2) return char deterministic is
begin
 test_director(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_director;
 
function is_manager(p_email varchar2, p_region varchar2 default null) return char deterministic is
begin
bhu_logs(12,'is_manager ','clob12 p_email '||p_email||' p_region '||p_region);
 test_manager(p_email,p_region);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_manager;
 
function is_team_member(p_email varchar2) return char deterministic is
begin
 test_team_member(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_team_member;
 
function is_admin(p_email varchar2) return char deterministic as
begin
 test_admin(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_admin;
 
function get_region(p_country_id number) return varchar2 deterministic as
/** returns the  given country's region it is in.
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_region';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp varchar2 (4000 char);
begin
  -- returns the region from the countries' dimension table
  select nvl(region,'GLOBAL') into v_tmp from md_countries where id = p_country_id;
  return v_tmp;
exception
when no_data_found then return null;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_region;
 
function get_managers(p_region varchar2 default null) return PCG_number_LIST deterministic as
/** returns the managers of a given region, or all regions.
2017.03.31 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_managers';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp PCG_number_LIST;
begin
  select distinct id bulk collect into v_tmp from bugt_managers_v m where (region = p_region or p_region is null);
  return v_tmp;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_managers;
 
function get_user_region(p_id number, p_role varchar2 default 'MANAGER ANALYST' ) return varchar2 deterministic is
/** returns the region name of the given user by id; specify if manager or analyst region required
2017.07.11 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_user_region';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp varchar2 (4000 char) := null;
begin
  select trim(region) into v_tmp from (select region from bugt_managers_v where id = p_id and p_role like '%MANAGER%'
  	                       union select region from bugt_analysts_v where id = p_id and p_role like '%ANALYST%');
  return v_tmp;
exception when no_data_found then return null;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_user_region;
 
function is_submissible (p_id number, p_email varchar2 default v('APP_USER')) return char is
/** A given bug can be submitted by the given user or not
2017.04.04 - 1.0 - András Tóth - create
2017.04.27 - 1.1 - András Tóth - when id<0 then it is a new bug and we return yes.
2017.05.10 - 1.2 - András Tóth - status changes
2017.07.17 - 1.3 - András Tóth - M&A, OP can also submit
2018.07.13 - 1.4 - András Tóth - use the basic table instead of the view where possible
2021.09.08 - 1.5 - András Tóth - optimizations
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_submissible';
  c_proc_version constant varchar2(5 char) := '1.5';
begin
  -- check user roles:
  if
    is_payroll_org_member(p_email) = c_Yes
  then
  -- checks if it is a new bug without valid id:
  if nvl(p_id,-1) < 0 then return c_yes; end if;
  -- checks the status of a bug to be new, and the app_user is the same as the creator of the bug.
  for i in (select employee_email,status_id from bugt_bugs where id  = p_id) loop
     if i.status_id in(status_name_2_status_id(c_status_new),status_name_2_status_id(c_status_manager_rejected), status_name_2_status_id(c_status_gpo_rejected)) and p_email = i.employee_email then return c_yes; end if;
  end loop;
  end if;
  return c_no;
exception
  when no_data_found then return null;
  when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_submissible;
 
procedure test_submissible (p_id number, p_email varchar2 default v('APP_USER')) as
begin
  if nvl(is_submissible(p_id, p_email), c_no) = c_no then raise pcg.not_authorized; end if;
end test_submissible;
 
procedure test_editable(p_id number, p_email varchar2 default v('APP_USER')) as
begin
  if nvl(is_editable(p_id, p_email), c_no) = c_no then raise pcg.not_authorized; end if;
end test_editable;
 
function is_editable (p_id number, p_email varchar2 default v('APP_USER')) return char as
/** A given bug is editable by user or not
2017.04.03 - 1.0 - András Tóth - create
2017.04.04 - 1.1 - András Tóth - correcting manager: adding not own.
2017.04.05 - 1.2 - András Tóth - adding director and GPO editing.
2017.04.07 - 1.3 - András Tóth - manager cannot edit GPO Team Member requests
2017.04.25 - 1.4 - András Tóth - rejected by Director is editable by GPO again.
2017.04.27 - 1.5 - András Tóth - new bug when id < 0
2017.05.10 - 1.6 - András Tóth - status changes
2017.07.17 - 1.7 - András Tóth - GPO Submitted request; M&A, OP roles addon
2017.08.03 - 1.8 - András Tóth - Director do not see anything
2018.07.12 - 1.9 - András Tóth - user region is deprecated, use the one from the pcg; using base table instead of the view
2021.09.08 - 2.0 - András Tóth - adjusting access rights for Innovation Tracker
2021.09.17 - 2.1 - András Tóth - optimizations
2024.05.21 - 2.2 - Bhuvi Chauhan - get_user_region(get_user_id(p_email),'MANAGER') replaced with :G_USER_REGION
2024.08.09 - 2.3 - Bhuvi Chauhan - Added new if conditionfor JOSE, as he has multiple region and in his case we don't want to call pcg.get_region just pick whaterver region he has selected in the SR so that correct manager can approve/reject the SR.
2024.08.21 - 2.4 - Bhuvi Chauhan - Added if condition to handle negative p_id as when new sr is created the id is negative only, so at that time executing this condtion won't make sense.  
 
***********
** Note: **
if you update the procedure, update  P100 - `Action Required` region also in APEX  !!!!!
***********
 
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_editable';
  c_proc_version constant varchar2(5 char) := '2.4';
  v_is_bts_of_the_bug char;
  v_inno_approval_id number;
  v_country_ids varchar2(100);
  v_region varchar2(256 char);
begin

bhu_logs(13,'is_editable ','clob13');

-- Bhuvi added if condition to handle negative p_id as when new sr is created the id is negative only, so at that time executing this condtion won't make sense.
 if nvl(p_id,-1) > 0 then 
  select country_ids into v_country_ids from bugt_bugs where id = p_id;
  bhu_logs(1,'p_id '||p_id||' v_country_ids '||v_country_ids,'clob1');
  -- Execute dynamic SQL to get the max region
  EXECUTE IMMEDIATE 'SELECT MAX(region) FROM md_countries WHERE id IN (' || v_country_ids || ')' INTO v_region;

    bhu_logs(2,' v_country_ids '||v_country_ids||' v_region '||v_region,'clob2');
 end if;
  -- check the user roles who can edit at all:
  if is_payroll_org_member(p_email) = c_Yes
  then
  -- new is always editable
  if nvl(p_id,-1) < 0 then return c_yes; end if;
  for i in (select employee_email,status_id,issue_type_id,country_ids from bugt_bugs where id = p_id) loop
    -- any emloyee can edit own requests when New or Rejected by Manager / by GPO
    if i.employee_email = p_email and i.status_id in(status_name_2_status_id(c_status_new),status_name_2_status_id(c_status_manager_rejected), status_name_2_status_id(c_status_gpo_rejected)) then return c_yes; end if;
    -- manager can edit submitted request in own region, but not own request, and not the GPO-member's requests:
      


    if i.employee_email = 'JOSE.BUSTAMANTE@ORACLE.COM' then
    bhu_logs(70,'is_manager call from is editable','clob70');
     if i.issue_type_id != c_issue_type_id__inno and i.employee_email != p_email and is_team_member(i.employee_email) = c_no and is_manager(p_email) = c_yes and i.status_id = status_name_2_status_id (c_status_submitted) and v('G_USER_REGION') = v_region then return c_yes; end if;
    else
    bhu_logs(71,'is_manager call from is editable','clob71 else');
     if i.issue_type_id != c_issue_type_id__inno and i.employee_email != p_email and is_team_member(i.employee_email) = c_no and is_manager(p_email) = c_yes and i.status_id = status_name_2_status_id (c_status_submitted) and v('G_USER_REGION') = pcg.get_region(i.employee_email) then return c_yes; end if;
    end if;
    -- GPO team member can edit manager-approved and Director-rejected requests, but not own requests:
    if i.issue_type_id != c_issue_type_id__inno and i.employee_email != p_email and is_team_member(p_email) = c_yes and i.status_id in ( status_name_2_status_id(c_status_manager_approved), status_name_2_status_id(c_status_director_rejected) ) then return c_yes; end if;
   -- bhuvi adding this - GPO team member/ admin as per new workflow for production issue type can edit manager-approved and Director-rejected requests, but not own requests:
    if i.issue_type_id != c_issue_type_id__inno and i.employee_email != p_email and is_admin(p_email) = c_yes and i.status_id in ( status_name_2_status_id(c_status_manager_approved), status_name_2_status_id(c_status_director_rejected) ) then return c_yes; end if;
    -- Director can edit GPO Approved requests
    if is_director(p_email) = c_yes and i.status_id = status_name_2_status_id (c_status_gpo_approved) then return c_yes; end if;
    -- MA Manager can edit MA Analysts requests when submitted
    if i.issue_type_id != c_issue_type_id__inno and is_ma_manager(p_email) = c_yes and is_ma_analyst(i.employee_email) = c_yes and i.status_id = status_name_2_status_id (c_status_submitted) then return c_yes; end if;
    -- OP Manager can edit OP Analysts requests when submitted
    if i.issue_type_id != c_issue_type_id__inno and is_op_manager(p_email) = c_yes and is_op_analyst(i.employee_email) = c_yes and i.status_id = status_name_2_status_id (c_status_submitted) then return c_yes; end if;
    -- BTS can edit Submitted Inno-type requests while not approved it:
    select max(c_Yes) into v_is_bts_of_the_bug from table(get_bug_BTSes(null,i.country_ids)) where lower(p_email) = column_value;
    select max(id) into v_inno_approval_id from bugt_bug_inno_approvals where employee_email = p_email and bug_id = p_id;
    if i.issue_type_id = c_issue_type_id__inno and is_bts(p_email) = c_yes and v_is_bts_of_the_bug = c_Yes and i.status_id = status_name_2_status_id (c_status_submitted) and v_inno_approval_id is null then return c_yes; end if;
    --
  end loop;
  end if;
  return c_no;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_editable;

---2024.08.12 - Rohit Kumar - revert changes in is_editable function 
-- function is_editable (p_id number, p_email varchar2 default v('APP_USER')) return char as
-- /** A given bug is editable by user or not
-- 2017.04.03 - 1.0 - András Tóth - create
-- 2017.04.04 - 1.1 - András Tóth - correcting manager: adding not own.
-- 2017.04.05 - 1.2 - András Tóth - adding director and GPO editing.
-- 2017.04.07 - 1.3 - András Tóth - manager cannot edit GPO Team Member requests
-- 2017.04.25 - 1.4 - András Tóth - rejected by Director is editable by GPO again.
-- 2017.04.27 - 1.5 - András Tóth - new bug when id < 0
-- 2017.05.10 - 1.6 - András Tóth - status changes
-- 2017.07.17 - 1.7 - András Tóth - GPO Submitted request; M&A, OP roles addon
-- 2017.08.03 - 1.8 - András Tóth - Director do not see anything
-- 2018.07.12 - 1.9 - András Tóth - user region is deprecated, use the one from the pcg; using base table instead of the view
-- 2021.09.08 - 2.0 - András Tóth - adjusting access rights for Innovation Tracker
-- 2021.09.17 - 2.1 - András Tóth - optimizations
 
 
-- ***********
-- ** Note: **
-- if you update the procedure, update  P100 - `Action Required` region also in APEX  !!!!!
-- ***********
 
-- */
--   c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_editable';
--   c_proc_version constant varchar2(5 char) := '2.1';
--   v_is_bts_of_the_bug char;
--   v_inno_approval_id number;
-- begin
--   -- check the user roles who can edit at all:
--   if is_payroll_org_member(p_email) = c_Yes
--   then
--   -- new is always editable
--   if nvl(p_id,-1) < 0 then return c_yes; end if;
--   for i in (select employee_email,status_id,issue_type_id,country_ids from bugt_bugs where id = p_id) loop
--     -- any emloyee can edit own requests when New or Rejected by Manager / by GPO
--     if i.employee_email = p_email and i.status_id in(status_name_2_status_id(c_status_new),status_name_2_status_id(c_status_manager_rejected), status_name_2_status_id(c_status_gpo_rejected)) then return c_yes; end if;
--     -- manager can edit submitted request in own region, but not own request, and not the GPO-member's requests:
--     if i.issue_type_id != c_issue_type_id__inno and i.employee_email != p_email and is_team_member(i.employee_email) = c_no and is_manager(p_email) = c_yes and i.status_id = status_name_2_status_id (c_status_submitted) and v('G_USER_REGION') = pcg.get_region(i.employee_email) then return c_yes; end if;
--     -- GPO team member can edit manager-approved and Director-rejected requests, but not own requests:
--     if i.issue_type_id != c_issue_type_id__inno and i.employee_email != p_email and is_team_member(p_email) = c_yes and i.status_id in ( status_name_2_status_id(c_status_manager_approved), status_name_2_status_id(c_status_director_rejected) ) then return c_yes; end if;
--     -- Director can edit GPO Approved requests
--     if is_director(p_email) = c_yes and i.status_id = status_name_2_status_id (c_status_gpo_approved) then return c_yes; end if;
--     -- MA Manager can edit MA Analysts requests when submitted
--     if i.issue_type_id != c_issue_type_id__inno and is_ma_manager(p_email) = c_yes and is_ma_analyst(i.employee_email) = c_yes and i.status_id = status_name_2_status_id (c_status_submitted) then return c_yes; end if;
--     -- OP Manager can edit OP Analysts requests when submitted
--     if i.issue_type_id != c_issue_type_id__inno and is_op_manager(p_email) = c_yes and is_op_analyst(i.employee_email) = c_yes and i.status_id = status_name_2_status_id (c_status_submitted) then return c_yes; end if;
--     -- BTS can edit Submitted Inno-type requests while not approved it:
--     select max(c_Yes) into v_is_bts_of_the_bug from table(get_bug_BTSes(null,i.country_ids)) where lower(p_email) = column_value;
--     select max(id) into v_inno_approval_id from bugt_bug_inno_approvals where employee_email = p_email and bug_id = p_id;
--     if i.issue_type_id = c_issue_type_id__inno and is_bts(p_email) = c_yes and v_is_bts_of_the_bug = c_Yes and i.status_id = status_name_2_status_id (c_status_submitted) and v_inno_approval_id is null then return c_yes; end if;
--     --
--   end loop;
--   end if;
--   return c_no;
-- exception when others then
--   pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
--   if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
-- end is_editable;


procedure test_deletable(p_id number, p_email varchar2 default v('APP_USER')) as
begin
  if nvl(is_deletable(p_id, p_email), c_no) = c_no then raise pcg.not_authorized; end if;
end test_deletable;
 
function is_deletable (p_id number, p_email varchar2 default v('APP_USER')) return char is
/** A given bug can be deleted by the given user or not
2017.04.04 - 1.0 - András Tóth - create
2017.05.10 - 1.1 - András Tóth - status changes
2018.07.13 - 1.2 - András Tóth - use the basic table instead of the view where possible
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_deletable';
  c_proc_version constant varchar2(5 char) := '1.2';
begin
  -- own bug can be deleted and only in status "new", "manager-rejected", "gpo-rejected"
  for i in (select employee_email,status_id from bugt_bugs where id  = p_id) loop
        if i.employee_email = p_email and i.status_id in(status_name_2_status_id(c_status_new),status_name_2_status_id(c_status_manager_rejected), status_name_2_status_id(c_status_gpo_rejected)) then return c_yes; end if;
  end loop;
  return c_no;
exception
  when no_data_found then return c_yes;
  when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_deletable;
 
function is_reject_commentable (p_id number, p_email varchar2 default v('APP_USER')) return char is
/** A given bug can be commentd by the given GPO Member or not
2017.04.19 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_reject_commentable';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret char := c_no;
begin
  for i in (select employee_email, status_id from bugt_bugs where id = p_id) loop
    -- when not own bug, user is GPO, and the status is director-rejected.
    if i.employee_email != p_email and is_team_member(p_email) = c_yes and i.status_id = status_name_2_status_id(c_status_director_rejected) then v_ret := c_yes; end if;
  end loop;
  return v_ret;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_reject_commentable;
 
procedure test_reject_commentable (p_id number, p_email varchar2 default v('APP_USER')) is
begin
  if nvl(is_reject_commentable(p_id, p_email), c_no) = c_no then raise pcg.not_authorized; end if;
end test_reject_commentable;
 
procedure test_approvable(p_id number, p_email varchar2 default v('APP_USER')) as
begin
  if nvl(is_approvable(p_id, p_email), c_no) = c_no then raise pcg.not_authorized; end if;
end test_approvable;
 
function is_approvable (p_id number, p_email varchar2 default v('APP_USER')) return char is
/** A given bug can be approved/rejected by the given user or not
2017.04.04 - 1.0 - András Tóth - create
2017.04.05 - 1.1 - András Tóth - GPO team approval, Director Approval
2017.07.17 - 1.2 - András Tóth - M&A, OP can also send in requests.
2018.07.12 - 1.3 - András Tóth - get_user_region is deprecated in most cases.
2018.07.13 - 1.4 - András Tóth - use the basic table instead of the view where possible
2021.09.10 - 1.5 - András Tóth - Innovation Tracker updates
2021.09.17 - 1.6 - András Tóth - optimizations.
2024.08.09 - 1.7 - Bhuvi Chauhan - Added new if conditionfor JOSE, as he has multiple region and in his case we don't want to call pcg.get_region just pick whaterver region he has selected in the SR so that correct manager can approve/reject the SR.
2024.08.21 - 1.8 - Bhuvi Chauhan - Added if clause to check the id, as for new sr with negative id this condition should not execute.
2024.12.16 - 1.9 - Bhuvi Chauhan - Adjusting the workflow for APEX, Macros, Automation and Osvc Issues. Now Systems team will act as GOP Team member as will Approve/Reject these SR(s).
*/

  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_approvable';
  c_proc_version constant varchar2(5 char) := '1.9';
  v_inno_approval_id number;
  v_bug_bts_email varchar2(256 char);
  v_region varchar2(256 char);
  v_country_ids varchar2(100);
begin
  
-- Added if clause to check id as without if clause the buttons are visible when a new sr is created which doesn't make sense
if nvl(p_id,-1) > 0 then  
  select country_ids into v_country_ids from bugt_bugs where id = p_id;
  -- Execute dynamic SQL to get the max region
  EXECUTE IMMEDIATE 'SELECT MAX(region) FROM md_countries WHERE id IN (' || v_country_ids || ')' INTO v_region;
  --select max(region) into v_region from md_countries where id in v_country_ids;
end if;

  for i in (select employee_email,status_id,issue_type_id,country_ids from bugt_bugs where id  = p_id) loop
   -- status=submitted, user is a manager of the requester's region, requester is not GPO-team-member, and not own request
    if i.employee_email = 'JOSE.BUSTAMANTE@ORACLE.COM' then
    bhu_logs(72,'is_manager call from is approvable','clob72');
    if i.issue_type_id != c_issue_type_id__inno and i.status_id = status_name_2_status_id(c_status_submitted) and is_team_member(i.employee_email) = c_no and is_manager(p_email, v_region) = c_yes and i.employee_email != p_email then return c_yes; end if;
    else
    if i.issue_type_id != c_issue_type_id__inno and i.status_id = status_name_2_status_id(c_status_submitted) and is_team_member(i.employee_email) = c_no and is_manager(p_email, pcg.get_region(i.employee_email)) = c_yes and i.employee_email != p_email then return c_yes; 
     bhu_logs(725,'is_manager call from is approvable c_yes '||c_yes,'clob725');
     end if;
     bhu_logs(73,'is_manager call from is approvable','clob73');
    end if;
    -- status=manager_approved, user is team member, not own request (requestor can be GPO or anyone)
   -- bhuvi adding this - is_admin condition for new workflow where system team is approver
    if i.issue_type_id != c_issue_type_id__inno and i.status_id = status_name_2_status_id(c_status_manager_approved) and (is_team_member(p_email) = c_yes or is_admin(p_email) = c_yes) and i.employee_email != p_email then 
    bhu_logs(74,'is_manager call from is approvable 74','clob74');return c_yes; 
     end if;   
    -- status=GPO_approved, user is director
    if i.status_id = status_name_2_status_id(c_status_gpo_approved) and is_director(p_email) = c_yes then bhu_logs(75,'is_manager call from is approvable 75','clob75');
    return c_yes; 
    end if;  
    -- status=submitted, user is a MA manager, requester is a MA analyst, and not own request
    if i.issue_type_id != c_issue_type_id__inno and i.status_id = status_name_2_status_id(c_status_submitted) and is_ma_manager(p_email) = c_yes and is_ma_analyst(i.employee_email) = c_yes and i.employee_email != p_email then 
    bhu_logs(76,'is_manager call from is approvable 76','clob76');return c_yes; 
    end if;  
    -- status=submitted, user is a OP manager, requester is a OP analyst, and not own request
    if i.issue_type_id != c_issue_type_id__inno and i.status_id = status_name_2_status_id(c_status_submitted) and is_op_manager(p_email) = c_yes and is_op_analyst(i.employee_email) = c_yes and i.employee_email != p_email then 
    bhu_logs(77,'is_manager call from is approvable 77','clob77');return c_yes; 
    end if;  
    -- status=submitted, user is BTS, Innovation-type, yet not approved by user.
    select max(id) into v_inno_approval_id from bugt_bug_inno_approvals where employee_email = p_email and bug_id = p_id;
    select max(column_value) into v_bug_bts_email from table(get_bug_BTSes(null,i.country_ids)) where column_value = lower(p_email);
    if i.issue_type_id = c_issue_type_id__inno and i.status_id = status_name_2_status_id(c_status_submitted) and is_BTS(p_email) = c_yes and v_inno_approval_id is null and v_bug_bts_email = lower(p_email) then return c_yes; end if;
 
  end loop;
  return c_no;
exception
  when no_data_found then return c_yes;
  when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_approvable;
 
procedure approve_bug(p_id number, p_email varchar2 default v('APP_USER')) as
/** approve the bug.
2017.03.21 - 1.0 - András Tóth - create
2017.04.06 - 1.1 - András Tóth - approval of all roles
2017.04.19 - 1.2 - András Tóth - approval process changed
2017.05.08 - 1.3 - András Tóth - Validation test added also.
2017.07.11 - 1.4 - András Tóth - Notification message also to the requester when Director (Senior Systems Manager) approves.
2017.08.03 - 1.5 - András Tóth - OP/MA Manager approves a Service Request.
2018.03.21 - 1.6 - András Tóth - updates on "removal of workflow" topic.
2018.07.12 - 1.7 - András Tóth - get_user_region is deprecated in most cases, there is an easier way of doing this.
2018.07.13 - 1.8 - András Tóth - stakehoders is updated before modifying the bug. use the base table instead of the view where possible. Firstly copy the project to PPM, then setting the status.
2018.07.13 - 1.9 - András Tóth - copy_2_Project_tracker - extra parameter
2021-09-10 - 2.0 - András Tóth - Innovation Tracker updates.
2021.09.17 - 2.1 - András Tóth - optimizations
2021.09.22 - 2.2 - András Tóth - updating notifications
2021.10.04 - 2.3 - András Tóth - updating notifications again
2021.11.10 - 2.4 - András Tóth - updating notifications again
2022.03.09 - 2.5 - András Tóth - GPO Process approval addon
2025.05.02 - 2.6 - Bhuvi Chauhan - See comment below in is_manager and clause
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'approve_bug';
  c_proc_version constant varchar2(5 char) := '2.6';
  v_ln varchar2(4000);
  v_status_id number;
  v_employee_email varchar2(256 char);
  v_EMPLOYEE_EMAILS varchar2(c_32k);
  v_role varchar2(256 char);
  v_title varchar2(4000 char);
  v_message_text varchar2(4000 char);
  v_gpo_team_member_email varchar2(256 char);
  v_manager_email varchar2(256 char);
  v_issue_type_id number;
  v_approval_waiting_for1 varchar2(256 char);
  v_country_ids varchar2(4000 char);
  v_bug_affect_region varchar2 (256 char);
begin
  v_ln := 0;
  -- test if the user can approve the given bug
  test_approvable(p_id,p_email);
 
  v_ln := 1;
  test_valid_bug(p_id);
 
  -- get the basic information on the bug needed for approval
  v_ln := 2;
  --select issue_type_id, status_id, employee_email, bugt_pkg.get_email(bugt_pkg.get_team_member_id(p_id)), country_ids into v_issue_type_id, v_status_id, v_employee_email, v_gpo_team_member_email, v_country_ids from bugt_bugs where id = p_id;
  bhu_logs(1223,'1223 approve_bug v_employee_email '||v_employee_email);

   -- bhuvi added on 02 may 2025, why not collecting from bugt_bugs_v
    select issue_type_id, status_id, employee_email, TEAM_MEMBER_EMAIL, BUG_AFFECT_REGION into v_issue_type_id, v_status_id, v_employee_email, v_gpo_team_member_email, v_bug_affect_region from bugt_bugs_v where id = p_id;

  v_ln := 3;
  --== Innovation Tracker - BTS approval ==--
  if v_status_id = status_name_2_status_id(c_status_submitted) and is_BTS(p_email) = c_yes and v_issue_type_id = c_issue_type_id__inno
  then
    -- Logging who did the approval:
    v_ln := 4;
    v_role := 'BTS';
    v_ln := 5;
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
 
    v_ln := 6;
    insert into bugt_bug_inno_approvals (id, bug_id, employee_email, approval_datetime) values (BUGT_ID_SEQ.nextval, p_id, p_email, systimestamp);
 
    v_ln := 7;
    select min(emails) into v_approval_waiting_for1 from (
      select column_value emails from (get_bug_BTSes(null, v_country_ids)) minus
      select lower(employee_email) emails from bugt_bug_inno_approvals where bug_id = p_id
    );
 
    v_ln := 8;
    if v_approval_waiting_for1 is null then
      -- saving the approval
      v_ln := 9;
      update bugt_bugs set status_id = status_name_2_status_id(c_status_gpo_approved) where id = p_id;
       -- sending out email to Director:
       v_ln := 10;
       ret_email_msg ('submit', v_title, v_message_text);
       v_ln := 11;
       for i in (select s.email from bugt_directors_v dv, bugt_director_notification s where s.email = dv.email) loop
         v_ln := 12;
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
       v_ln := 13;
       -- Get the submission Slack message template:
       ret_email_msg ('submit-slack', v_title, v_message_text);
       -- sending out the messages to Directors:
       for i in (select s.email from bugt_directors_v dv, bugt_director_notification s where s.email = dv.email) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
       -- Notify Submitter, Manager and HUB Managers
       ret_email_msg ('btsapproved', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       sendmail(pcg.get_manager(v_employee_email), v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       for i in (select column_value as email from table(get_hub_leaders)) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
       select EMPLOYEE_EMAILS into v_EMPLOYEE_EMAILS from bugt_bug_inno_contributors where bug_id = p_id;
       for i in (select column_value as email from table(pcg.string_2_list(v_EMPLOYEE_EMAILS,','))) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
 
       ret_email_msg ('btsapproved-slack', v_title, v_message_text);
       begin
         sendslack(null, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), c_INNO_SLACK_CHANNEL);
       exception when others then null;
       end;
       begin
         sendslack(v_employee_email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
       exception when others then null;
       end;
       begin
         sendslack(pcg.get_manager(v_employee_email), pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
       exception when others then null;
       end;
       for i in (select column_value as email from table(get_hub_leaders)) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
       for i in (select column_value as email from table(pcg.string_2_list(v_EMPLOYEE_EMAILS,','))) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
 
    end if;
    v_ln := 14;
    --== Payroll Manager Approval ==--
      -- bhuvi added on 02 may 2025, changed this and clause as in case of jose pcg.get-region gives LAD and for LAD there is no approver (highere than jose) in bugt_managers_v, so for julia reilly I can create her as LAD APPROVER, 
  -- so she will also have two roles like jose but then in front end also she will get two region selection and everything, so for her this can be confusing. So I am adding this change in the codition that for jose pick the bug_affect_region.
  elsif v_status_id = status_name_2_status_id(c_status_submitted) and is_team_member(v_employee_email) = c_no and  is_manager(p_email,CASE WHEN v_employee_email = 'JOSE.BUSTAMANTE@ORACLE.COM' 
                                                                                                                                            THEN v_bug_affect_region
                                                                                                                                            ELSE pcg.get_region(v_employee_email)
                                                                                                                                            END
                                                                                                                            ) = c_yes
  then
    bhu_logs(1212,'1212 elsif');
    if -- GPO Process request: 
      v_issue_type_id = c_issue_type_id__gpo_process
    then
      -- Logging who did the approval:
      v_role := 'MANAGER';
      insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
      bhu_logs('1001','1001 elsif');
       -- copiing the bug to Project Manager (former Project Tracker)
       copy_2_Project_tracker(p_id, c_PPM_approved, p_email);
       commit;
       -- saving the approval
       update bugt_bugs set status_id = status_name_2_status_id(c_status_director_approved) where id = p_id;
       commit;
       -- Sending out email to the Requester:
       ret_email_msg ('approval', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- sending out email to the GPO Operations Manager of the bug:
       ret_email_msg ('submit', v_title, v_message_text);
       sendmail(v_gpo_team_member_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
    else -- regular SR request:
      -- Logging who did the approval:
      v_role := 'MANAGER';
      insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
      -- saving the approval
      update bugt_bugs set status_id = status_name_2_status_id(c_status_manager_approved) where id = p_id;
       -- sending out email to the GPO Team Member of the bug's region:
       ret_email_msg ('submit', v_title, v_message_text);
       sendmail(v_gpo_team_member_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- bhuvi 3 march debugging code for jay request
       -- sending out slack notifiication to the GPO Team Member of the bug's region:
       ret_email_msg ('submit_GPO_notify-slack', v_title, v_message_text);
       sendslack(v_gpo_team_member_email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
    end if;
    --== MA Manager Approval ==--
  elsif v_status_id = status_name_2_status_id(c_status_submitted) and is_ma_manager(p_email) = c_yes and is_ma_analyst(v_employee_email) = c_yes
  then
      -- Logging who did the approval:
      v_role := 'M&A MANAGER';
      insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
      -- saving the approval
      update bugt_bugs set status_id = status_name_2_status_id(c_status_manager_approved) where id = p_id;
       -- sending out email to the GPO Team Member of the bug's region:
       ret_email_msg ('submit', v_title, v_message_text);
       sendmail(v_gpo_team_member_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- bhuvi 3 march debugging code for jay request
       -- sending out slack notifiication to the GPO Team Member of the bug's region:
       ret_email_msg ('submit_GPO_notify-slack', v_title, v_message_text);
       sendslack(v_gpo_team_member_email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
    --== OP Manager Approval ==--
  elsif v_status_id = status_name_2_status_id(c_status_submitted) and is_op_manager(p_email) = c_yes and is_op_analyst(v_employee_email) = c_yes
  then
       -- Logging who did the approval:
       v_role := 'OPERATIONS MANAGER';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
       -- saving the approval
       update bugt_bugs set status_id = status_name_2_status_id(c_status_manager_approved) where id = p_id;
       -- sending out email to the GPO Team Member of the bug's region:
       ret_email_msg ('submit', v_title, v_message_text);
       sendmail(v_gpo_team_member_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- bhuvi 3 march debugging code for jay request
       -- sending out slack notifiication to the GPO Team Member of the bug's region:
       ret_email_msg ('submit_GPO_notify-slack', v_title, v_message_text);
       sendslack(v_gpo_team_member_email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
    --== GPO Approval, no Qrc ==--
    -- bhuvi changing this is_team_member to or is_admin
  elsif v_status_id = status_name_2_status_id(c_status_manager_approved) and (is_team_member(p_email) = c_yes or is_admin(p_email) = c_yes) and v_employee_email != p_email and is_qrc(p_id) = c_no
  then
       -- Logging who did the approval:
       v_role := 'GPO_TEAM_MEMBER';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
       -- saving the approval
       update bugt_bugs set status_id = status_name_2_status_id(c_status_gpo_approved) where id = p_id;
       -- sending out email to the Directors subscribed to the service request emails
       ret_email_msg ('submit', v_title, v_message_text);
       for i in (select s.email from bugt_directors_v dv, bugt_director_notification s where s.email = dv.email) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
       --== GPO Approval, Qrc ==--
       -- bhuvi changing this is_team_member to or is_admin
  elsif v_status_id = status_name_2_status_id(c_status_manager_approved) and (is_team_member(p_email) = c_yes or is_admin(p_email) = c_yes) and v_employee_email != p_email and is_qrc(p_id) = c_yes
  then
       -- Logging who did the approval:
       v_role := 'GPO_TEAM_MEMBER';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
       bhu_logs('1002','1002 elsif');
       -- copiing the bug to Project Manager (former Project Tracker)
       copy_2_Project_tracker(p_id, c_PPM_approved, p_email);
       commit;
       -- saving the approval
       update bugt_bugs set status_id = status_name_2_status_id(c_status_director_approved) where id = p_id;
       commit;
       -- Sending out email to the Requester:
       ret_email_msg ('approval', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
    --== Director Approval ==--
  elsif v_status_id = status_name_2_status_id(c_status_gpo_approved) and is_director(p_email) = c_yes
  then
       -- Logging who did the approval:
       v_role := 'DIRECTOR';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'APPROVE');
       bhu_logs('1003','1003 elsif');
       -- copiing the bug to Project Manager (former Project Tracker)
       copy_2_Project_tracker(p_id, c_PPM_approved, p_email);
       commit;
       -- saving the approval
       update bugt_bugs set status_id = status_name_2_status_id(c_status_director_approved) where id = p_id;
       commit;
 
       -- Sending out email to the GPO Team Member:
       ret_email_msg ('approval_GPO_notify', v_title, v_message_text);
       sendmail(v_gpo_team_member_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       begin
         ret_email_msg ('approval_GPO_notify-slack', v_title, v_message_text);
         sendslack(v_gpo_team_member_email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
       exception when others then null;
       end;
 
       select EMPLOYEE_EMAILS into v_EMPLOYEE_EMAILS from bugt_bug_inno_contributors where bug_id = p_id;
 
       for i in (
           select distinct trim(upper(email)) as email from (
             -- Sending out email to the manager:
             select max(employee_email) email from bugt_bug_stakeholders where bug_id = p_id and employee_role = 'MANAGER' and action = 'APPROVE'
                    and action_time = ( select max(action_time) from bugt_bug_stakeholders where bug_id = p_id and employee_role = 'MANAGER' and action = 'APPROVE' )
             union
             -- Sending out email to the Requester:
             select v_employee_email from dual
             union
             -- Sending out email to HUB Leaders
             select column_value as email from table(get_hub_leaders) where v_issue_type_id = c_issue_type_id__inno
             union
             --Sending out email to Contributors
             select column_value as email from table(pcg.string_2_list(v_EMPLOYEE_EMAILS,',')) where v_issue_type_id = c_issue_type_id__inno
             union
             -- Sending out email to BTSes:
             select column_value as email from table(get_bug_BTSes(null, v_country_ids)) where v_issue_type_id = c_issue_type_id__inno
           ) where trim(email) is not null
       ) loop
         ret_email_msg ('approval', v_title, v_message_text);
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
         ret_email_msg ('approval-slack', v_title, v_message_text);
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
 
       -- sending out to Slack Channel if Innovation type request was approved:
       if v_issue_type_id = c_issue_type_id__inno then
         ret_email_msg ('approval-slack', v_title, v_message_text);
         begin
           sendslack(null, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), c_INNO_SLACK_CHANNEL);
         exception when others then null;
         end;
       end if;
 
  end if;
 
  insert into audit_log values (p_email,v('SESSION'),'Payroll Service Requests Template','APPROVE',v_role,systimestamp,c_application_id);
  commit;
exception when others then
 bhu_logs('1233','1233 exception');
  pcg.log(c_proc_name, c_version, c_proc_version, '('||v_ln||') '||case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END approve_bug;
 
procedure reject_bug(p_id number, p_reason varchar2, p_email varchar2 default v('APP_USER')) as
/** reject a bug.
2017.03.21 - 1.0 - András Tóth - create
2017.04.19 - 1.1 - András Tóth - approval process changed
2017.05.10 - 1.2 - András Tóth - new Statuses.
2017.07.11 - 1.3 - András Tóth - Manager will not receive notification at all when GPO rejects the Request.
2017.08.03 - 1.4 - András Tóth - M&A or Operations workflow rejection
2018.03.22 - 1.5 - András Tóth - updates on "removal of workflow" topic.
2018.07.12 - 1.6 - András Tóth - get_user_region is deprecated, use pcg.get_region instead.
2018.07.13 - 1.7 - András Tóth - stakehoders is updated before modifying the bug. use the base table instead of the view where possible. firstly copy to PPM, then updating the SR status.
2018.07.13 - 1.8 - András Tóth - copy_2_Project_tracker - extra parameter
2021.09.10 - 1.9 - András Tóth - adding the Innovation Tracker enhancements
2021.10.04 - 2.0 - András Tóth - updating notifications
2025.05.02 - 2.1 - Bhuvi Chauhan - See comment below in is_manager and clause
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'reject_bug';
  c_proc_version constant varchar2(5 char) := '2.1';
  v_status_id number;
  v_employee_email varchar2(256 char);
  v_role varchar2(256 char);
  v_title varchar2(4000 char);
  v_message_text varchar2(4000 char);
  v_manager_email varchar2(256 char);
  v_team_member_email varchar2(256 char);
  v_issue_type_id number;
  v_EMPLOYEE_EMAILS varchar2(c_32k);
  v_bug_affect_region varchar2(256 char);
begin
  -- test if app_user is eligable to approve/reject the SR
  test_approvable(p_id,p_email);
 
  -- collectiong data
 -- select issue_type_id, status_id, employee_email, bugt_pkg.get_email(bugt_pkg.get_team_member_id(p_id)) into v_issue_type_id, v_status_id, v_employee_email, v_team_member_email from bugt_bugs where id = p_id;

 -- bhuvi added on 02 may 2025, why not collecting from bugt_bugs_v
    select issue_type_id, status_id, employee_email, TEAM_MEMBER_EMAIL, BUG_AFFECT_REGION into v_issue_type_id, v_status_id, v_employee_email, v_team_member_email, v_bug_affect_region from bugt_bugs_v where id = p_id;
 
  -- Innovation Idea - BTS rejection
  if v_status_id = status_name_2_status_id(c_status_submitted) and is_BTS(p_email) = c_yes and v_issue_type_id = c_issue_type_id__inno
  then
       -- Logging who did the rejection
       v_role := 'BTS';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_gpo_rejected) where id = p_id;
       delete from bugt_bug_inno_approvals where bug_id = p_id;
 
       ret_email_msg ('reject', v_title, v_message_text);
       -- notifying original requester
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
 
       ret_email_msg ('btsrejected', v_title, v_message_text);
       -- notify manager of the requestor
       sendmail(pcg.get_manager(v_employee_email), v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- notify contributors
       select EMPLOYEE_EMAILS into v_EMPLOYEE_EMAILS from bugt_bug_inno_contributors where bug_id = p_id;
       for i in (select column_value as email from table(pcg.string_2_list(v_EMPLOYEE_EMAILS,','))) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
       -- notify HUB Leaders
       for i in (select column_value as email from table(get_hub_leaders)) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
 
       -- Notify Slack Channel about the rejection
       ret_email_msg ('btsrejected-slack', v_title, v_message_text);
       begin
         sendslack(null, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), c_INNO_SLACK_CHANNEL);
       exception when others then null;
       end;
       -- notifying original requester
       begin
         sendslack(v_employee_email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
       exception when others then null;
       end;
       -- notify manager of the requestor
       begin
         sendslack(pcg.get_manager(v_employee_email), pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
       exception when others then null;
       end;
       -- notify contributors
       select EMPLOYEE_EMAILS into v_EMPLOYEE_EMAILS from bugt_bug_inno_contributors where bug_id = p_id;
       for i in (select column_value as email from table(pcg.string_2_list(v_EMPLOYEE_EMAILS,','))) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
       -- notify HUB Leaders
       for i in (select column_value as email from table(get_hub_leaders)) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
 
  -- Innovation Idea - Director rejection:
  elsif v_status_id = status_name_2_status_id(c_status_gpo_approved) and is_director(p_email) = c_yes and v_issue_type_id = c_issue_type_id__inno
  then
       -- Logging who did the rejection
       v_role := 'DIRECTOR';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       bhu_logs('1004','1004 elsif');
       -- copiing the bug to Project Manager (former Project Tracker)
       copy_2_Project_tracker(p_id, c_PPM_rejected, p_email);
       commit;
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_permanently_rejected) where id = p_id;
       -- notification of Requestor
       ret_email_msg ('strong_reject_commented', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- notify requestor's direct manager
       sendmail(pcg.get_manager(v_employee_email), v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- notify contributors
       select EMPLOYEE_EMAILS into v_EMPLOYEE_EMAILS from bugt_bug_inno_contributors where bug_id = p_id;
       for i in (select column_value as email from table(pcg.string_2_list(v_EMPLOYEE_EMAILS,','))) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
       -- notify BTSes
       for i in (select column_value as email from table(get_bug_BTSes(p_id))) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
       -- notify HUB Leaders
       for i in (select column_value as email from table(get_HUB_Leaders)) loop
         sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       end loop;
 
       ret_email_msg ('strong_reject_noreason-slack', v_title, v_message_text);
       -- Notify Slack Channel about the rejection
       begin
         sendslack(null, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)), c_INNO_SLACK_CHANNEL);
       exception when others then null;
       end;
       -- notify Requestor
       begin
         sendslack(v_employee_email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
       exception when others then null;
       end;
       -- notify Requestor's manager
       begin
         sendslack(pcg.get_manager(v_employee_email), pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
       exception when others then null;
       end;
       -- notify contributors
       select EMPLOYEE_EMAILS into v_EMPLOYEE_EMAILS from bugt_bug_inno_contributors where bug_id = p_id;
       for i in (select column_value as email from table(pcg.string_2_list(v_EMPLOYEE_EMAILS,','))) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
       -- notify BTSes
       for i in (select column_value as email from table(get_bug_BTSes(p_id))) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
       -- notify HUB Leaders
       for i in (select column_value as email from table(get_HUB_Leaders)) loop
         begin
           sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
         exception when others then null;
         end;
       end loop;
 
  -- Manager Rejection:
  -- bhuvi added on 02 may 2025, changed this and clause as in case of jose pcg.get-region gives LAD and for LAD there is no approver (highere than jose) in bugt_managers_v, so for julia reilly I can create her as LAD APPROVER, 
  -- so she will also have two roles like jose but then in front end also she will get two region selection and everything, so for her this can be confusing. So I am adding this change in the codition that for jose pick the bug_affect_region.
  -- similar change in approval procedure
  elsif v_status_id = status_name_2_status_id(c_status_submitted) and is_team_member(v_employee_email) = c_no and is_manager(p_email,CASE WHEN v_employee_email = 'JOSE.BUSTAMANTE@ORACLE.COM' 
                                                                                                                                            THEN v_bug_affect_region
                                                                                                                                            ELSE pcg.get_region(v_employee_email)
                                                                                                                                            END
                                                                                                                            ) = c_yes
  then
       -- Logging who did the rejection
       v_role := 'MANAGER';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_manager_rejected) where id = p_id;
       -- notifying original requester
       ret_email_msg ('reject', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
 
  -- MA Manager Rejection:
  elsif v_status_id = status_name_2_status_id(c_status_submitted) and is_ma_manager(p_email) = c_yes and is_ma_analyst(v_employee_email) = c_yes
  then
       -- Logging who did the rejection
       v_role := 'M&A MANAGER';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_manager_rejected) where id = p_id;
       -- sending out reject to the GPO Team Member of the bug's region:
       ret_email_msg ('reject', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
  -- OP Manager Rejection:
  elsif v_status_id = status_name_2_status_id(c_status_submitted) and is_op_manager(p_email) = c_yes and is_op_analyst(v_employee_email) = c_yes
  then
       -- Logging who did the rejection
       v_role := 'OPERATIONS MANAGER';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_manager_rejected) where id = p_id;
       -- sending out email to the GPO Team Member of the bug's region:
       ret_email_msg ('reject', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
  -- GPO Rejection:
  -- bhuvi added is_admin with or condition along with is_team_member
  elsif v_status_id = status_name_2_status_id(c_status_manager_approved) and (is_team_member(p_email) = c_yes or is_admin(p_email) = c_yes) and v_employee_email != p_email
  then
       -- Logging who did the rejection
       v_role := 'GPO_TEAM_MEMBER';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_gpo_rejected) where id = p_id;
       -- notifying original requester
       ret_email_msg ('reject', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- notify the Manager:
/*       select max(employee_email) into v_manager_email from bugt_bug_stakeholders where bug_id = p_id and employee_role = 'MANAGER' and action = 'APPROVE'
              and action_time = ( select max(action_time) from bugt_bug_stakeholders where bug_id = p_id and employee_role = 'MANAGER' and action = 'APPROVE' );
       sendmail(v_manager_email,  v_title, pcg.decode_regexp_replace(v_message_text,'#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
*/
  -- Director rejection of no-Qrc:
  elsif v_status_id = status_name_2_status_id(c_status_gpo_approved) and is_director(p_email) = c_yes and is_qrc(p_id) = c_no
  then
       -- Logging who did the rejection
       v_role := 'DIRECTOR';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       -- copiing the bug to Project Manager (former Project Tracker)
       bhu_logs('1005','1005 elsif');
       copy_2_Project_tracker(p_id, c_PPM_rejected, p_email);
       commit;
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_director_rejected) where id = p_id;
       -- notification of GPO Team Member(s)
       if
         v_team_member_email != v_employee_email
       then -- if the Requestor is not the GPO Team Member of the region:
         ret_email_msg ('strong_reject', v_title, v_message_text);
         sendmail(v_team_member_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       else -- If the Requestor is the GPO Team Member of the region:
         ret_email_msg ('strong_reject_GPO', v_title, v_message_text);
         for i in (select email from bugt_team_members_v where v_team_member_email != email) loop
           sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
         end loop;
       end if;
       -- Director rejection Qrc:
  elsif v_status_id = status_name_2_status_id(c_status_gpo_approved) and is_director(p_email) = c_yes and is_qrc(p_id) = c_yes
  then
       -- Logging who did the rejection
       v_role := 'DIRECTOR';
       insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,v_role,systimestamp,'REJECT');
       bhu_logs('1006','1006 elsif');
       -- copiing the bug to Project Manager (former Project Tracker)
       copy_2_Project_tracker(p_id, c_PPM_rejected, p_email);
       commit;
       -- Updating the bug status:
       update bugt_bugs set status_id = status_name_2_status_id(c_status_permanently_rejected) where id = p_id;
       -- notification of Requestor
       ret_email_msg ('strong_reject_commented', v_title, v_message_text);
       sendmail(v_employee_email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
       -- Saving to the Project Manager also:
       commit;
  end if;
 
  insert into audit_log values (p_email,v('SESSION'),'Payroll Service Requests Template','REJECT',v_role,systimestamp,c_application_id);
  commit;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END reject_bug;
 
function get_project_tracker_link (p_id number, p_dummy varchar2 default null) return varchar2 deterministic is
/** returns the Project Tracker ID of the bug, if available - for creating a link.
2017.04.10 - 1.0 - András Tóth - create
2018.07.13 - 1.1 - András Tóth - dummy parameter is added for materialized view updating.
*/
  v_ret varchar2(4000 char) := null;
begin
  -- returns the project_manager_id if it is referencing to the bug
  select max(PROJECT_ID) into v_ret from PAY_PROJECTS where bugt_id = p_id;
  return v_ret;
exception when no_data_found then return null;
end get_project_tracker_link;
 
 
function get_project_tracker_link_a (p_id number) return varchar2 deterministic is
/** returns the Project Tracker <a> element link of the bug, if available.
2017.05.03 - 1.0 - András Tóth - create
*/
  v_ret varchar2(4000 char) := null;
begin
  select '<a href="'||c_APEX_LINK||'f?p='||c_application_id||':13:'||V('APP_SESSION')||'::NO:RP,13:P13_PROJECT_ID:'||max(PROJECT_ID)||'">'||max(PROJECT_ID)||'</a>' into v_ret from PAY_PROJECTS where bugt_id = p_id;
  return v_ret;
exception when no_data_found then return null;
end get_project_tracker_link_a;
 
procedure set_test_role(p_email varchar2,
    p_ADMINISTRATOR char default null
  , p_DIRECTOR char default null
  , p_SUPPORT char default null
  , p_AMERICAS_APPROVER char default null
  , p_EMEA_APPROVER char default null
  , p_JAPAC_APPROVER char default null
  , p_LAD_APPROVER char default null
  , p_AMERICAS_PAYROLL_ANALYST char default null
  , p_EMEA_PAYROLL_ANALYST char default null
  , p_JAPAC_PAYROLL_ANALYST char default null
  , p_LAD_PAYROLL_ANALYST char default null
  , p_OPERATIONS_ANALYST char default null
  , p_OPERATIONS_MANAGER char default null
  , p_MA_ANALYST char default null
  , p_MA_MANAGER char default null
  , p_AMERICAS_FINANCIAL_CONTROLLE char default null
  , p_EMEA_FINANCIAL_CONTROLLER char default null
  , p_JAPAC_FINANCIAL_CONTROLLER char default null
  , p_LAD_FINANCIAL_CONTROLLER char default null
) as
/** Testing purposes only; changes the test roles of a given user of the application. Users are identified by SSO email address.
2017.04.10 - 1.0 - András Tóth - create
2017.08.02 - 1.1 - András Tóth - adding of new roles for M&A, Operations, Financial Controllers
*/
  pragma autonomous_transaction;
begin
  -- delete all roles of the user
  delete from MD_TEST_USERS where p_email = username;
  -- adding the selected roles one by one
  if p_ADMINISTRATOR = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'ADMINISTRATOR'); end if;
  if p_DIRECTOR = c_yes then
    insert into MD_TEST_USERS (username,role_name) values (p_email,'DIRECTOR');
    delete from bugt_director_notification where email = p_email;
    insert into bugt_director_notification (email) values (p_email);
  end if;
  if p_SUPPORT = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'SUPPORT'); end if;
  if p_AMERICAS_APPROVER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'AMERICAS APPROVER'); end if;
  if p_EMEA_APPROVER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'EMEA APPROVER'); end if;
  if p_JAPAC_APPROVER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'JAPAC APPROVER'); end if;
  if p_LAD_APPROVER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'LAD APPROVER'); end if;
  if p_AMERICAS_PAYROLL_ANALYST = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'AMERICAS PAYROLL ANALYST'); end if;
  if p_EMEA_PAYROLL_ANALYST = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'EMEA PAYROLL ANALYST'); end if;
  if p_JAPAC_PAYROLL_ANALYST = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'JAPAC PAYROLL ANALYST'); end if;
  if p_LAD_PAYROLL_ANALYST = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'LAD PAYROLL ANALYST'); end if;
 
  if p_OPERATIONS_ANALYST = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'OPERATIONS_ANALYST'); end if;
  if p_OPERATIONS_MANAGER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'OPERATIONS_MANAGER'); end if;
  if p_MA_ANALYST = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'M&A_ANALYST'); end if;
  if p_MA_MANAGER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'M&A_MANAGER'); end if;
 
  if p_AMERICAS_FINANCIAL_CONTROLLE = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'AMERICAS FINANCIAL CONTROLLER'); end if;
  if p_EMEA_FINANCIAL_CONTROLLER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'EMEA FINANCIAL CONTROLLER'); end if;
  if p_JAPAC_FINANCIAL_CONTROLLER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'JAPAC FINANCIAL CONTROLLER'); end if;
  if p_LAD_FINANCIAL_CONTROLLER = c_yes then insert into MD_TEST_USERS (username,role_name) values (p_email,'LAD FINANCIAL CONTROLLER'); end if;
 
  commit;
end set_test_role;
 
function get_status (p_bug_id number) return number as
/** returns the status_id of a given bug.
2017.04.06 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_status';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret number;
begin
  select status_id into v_ret from bugt_bugs where id = p_bug_id;
  return v_ret;
exception
when no_data_found then return null;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_status;
 
procedure copy_2_Project_tracker (p_id number, p_with_status in varchar2, p_email varchar2 default v('APP_USER')) as
/** copy a bug into the project tracker.
2017.04.10 - 1.0 - András Tóth - create
2017.04.24 - 1.1 - András Tóth - update attachments
2017.04.24 - 1.2 - András Tóth - update attached links
2017.05.08 - 1.3 - András Tóth - rejected also can be uploaded to the Project Manager. Turning off Validation.
2017.05.12 - 1.4 - András Tóth - for rejection adding the close date
2018.03.21 - 1.5 - András Tóth - updates on "removal of workflow" topic.
2018.07.10 - 1.6 - András Tóth - Score and Severity are not in the view anymore :-( - as they are calculated from the view values. but we have employee name :-) .
2018.07.13 - 1.7 - András Tóth - use the basic table instead of the view where possible
2018.07.13 - 1.8 - András Tóth - adding the status to set the project as parameter
2018.07.25 - 1.9 - András Tóth - pending status now has the ID = 1
2021.09.29 - 2.0 - András Tóth - adding the EEE Sign
2022.03.09 - 2.1 - András Tóth - allow copiing for everybody for auto-approval of GPO Process Requests
2024.12.16 - 2.2 - Bhuvi Chauhan - adding condition is_admin as per the workflow adjustment
*/
    pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'copy_2_project_tracker';
  c_proc_version constant varchar2(5 char) := '2.1';
  v_team_member_email number;
  v_project_id number;
  v_ppm_status number;
  v_ppm_close_date date;
  v_issue_type_id number;
begin
bhu_logs('1007','1007 copy_2_Project_tracker start');
  user_warn_check(p_email);
  bhu_logs('1008','1008 copy_2_Project_tracker start1');
  if p_with_status = c_PPM_rejected then
    v_ppm_status := 6 /*Rejected*/;
    v_ppm_close_date := sysdate;
    bhu_logs('1009','1009 copy_2_Project_tracker start2');
  elsif p_with_status = c_PPM_approved then
    v_ppm_status := 1 /* Pending */;
    v_ppm_close_date := null;
    bhu_logs('1010','1010 copy_2_Project_tracker start3');
  end if;
 
  v_issue_type_id := get_bug_issue_type_id(p_id);
 
  -- only director can perform on a valid approved or a rejected SR; or GPO, when Qrc and not own SR, and anybody on GPO Process requests.
  if not(
      is_director(p_email) = c_yes or 
      -- bhuvi added is_admin with or condition along with is_team_member
      (is_team_member(p_email) = c_yes or is_admin(p_email) = c_yes) and is_qrc(p_id) = c_yes and p_email != get_requester(p_id) or
      v_issue_type_id = c_issue_type_id__gpo_process
    ) then 
    bhu_logs('1011','1011 copy_2_Project_tracker start4 v_issue_type_id '||v_issue_type_id);
    raise pcg.not_authorized; 
  end if;
 
  for i in (select * from bugt_bugs where id = p_id) loop
  bhu_logs('1012','1012 copy_2_Project_tracker start5');
  select max(paylead_id) into v_team_member_email from PAY_DIC_PAYLEAD where upper(paylead) = upper(bugt_pkg.get_email(bugt_pkg.get_team_member_id(p_id)))/*i.team_member_email*/;
  insert into PAY_PROJECTS(
       BUGT_ID,OBJECTIVE_ID,STATUS_ID,PHASE_ID,TEAM_ID,PAYLEAD_ID,SYSTEM_ID,NEB_ID,EMP_AFFECTED_ID,WORKAROUND_TIME_MONTH_ID,
       TASK_TIME_POST_ENHANCE_ID,LEGAL_REQ,DATE_LEG_CHANGE,IS_WORKAROUND,SCORE,WORKAROUND_DESCRIPTION,WORKAROUND_ISSUE,COUNTRY_IDS,SUBJECT,
       DESCRIPTION,REQUESTER,REQUEST_DATE,REQUEST_GO_LIVE,GO_LIVE_DATE,REV_GO_LIVE_DATE,SOLAR_ID,BUG_NUMBER,OAL_SR_NUMBER,OAL_LEAD,APPROVED_BY,CLOSED_DATE,EEE_SIGN)
  values (
       p_id, null, v_ppm_status,
       1, 1, v_team_member_email, i.system_id, i.issue_type_id, i.headcount_id, i.workaround_hour_id,
       i.after_workaround_hour_id, i.legally_required_sign, i.legislated_change_date, i.workaround_sign, get_score(p_id), i.workaround_details, null, replace(i.country_ids,',',':'),i.issue_subject,
       i.issue_description, /*i.employee_name*/ pcg.email2name(i.employee_email), i.raised_date, i.required_by_date,null,null,null,null,null,null,p_email,
       v_ppm_close_date,i.eee_sign
    ) returning project_id into v_project_id;
 
  update pay_attachments set project_id = v_project_id where bug_id = p_id ;
  update pay_links set project_id = v_project_id where bug_id = p_id ;
 
  end loop;
  commit;
exception when others then
bhu_logs('1013','1013 copy_2_Project_tracker start6');
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end copy_2_Project_tracker;
 
procedure ret_email_msg (p_id_text varchar2, po_title out varchar2, po_message_text out varchar2) as
/** retrieves title and message text template for a given type of email.
2017.04.18 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'ret_email_msg';
  c_proc_version constant varchar2(5 char) := '1.0';
begin
  -- simply select from the parameter table
  select title,message_text into po_title,po_message_text from bugt_messages where id_text = p_id_text;
exception
  when no_data_found then null;
  when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end ret_email_msg;
 
procedure sendmail(p_email varchar2, p_title varchar2, p_text varchar2, p_user varchar2 default v('APP_USER'),p_region varchar2 default v('G_USER_REGION')) is
/** sending out Payroll Service Request template related emails
2017.04.18 - 1.0 - András Tóth - create
2017.04.21 - 1.1 - András Tóth - remove link to the application.
2017.08.02 - 1.2 - András Tóth - adding OP/M&A users for allowing mail sending.
2018.03.20 - 1.3 - András Tóth - adding Test env checking for emails.
2024.05.22 - 1.4 - Bhuvi Chauhan - adding new parameter p_region as when user (jose) opens the sr via email region needs to be there.
 
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'sendmail';
  c_proc_version constant varchar2(5 char) := '1.4';
begin
  user_warn_check(p_user);
  -- checks only users with any GPAT roles can send emails through the bugt application
   bhu_logs(78,'is_manager call from sendmail','clob78');
  if is_analyst(p_user) = c_yes or is_manager(p_user) = c_yes or is_director(p_user) = c_yes
  or is_team_member(p_user) = c_yes or is_admin(p_user) = c_yes or is_op_manager(p_user) = c_yes
  or is_ma_manager(p_user) = c_yes or is_op_analyst(p_user) = c_yes or is_ma_analyst(p_user) = c_yes
    then
      -- sending out email
      if pcg.is_prod_env = 'Y' then
        pcg.sendmail(p_email, null, c_application_name, p_title, p_text);
      else
        pcg.sendmail('rohit.bq.kumar@oracle.com', null, c_application_name, '[TEST] - '||p_title, '[TO: '||p_email||']'||p_text);
      end if;
    else test_director(p_user); -- raise an error if app_user has no gpat roles
  end if;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end sendmail;
 
function comment_text(p_level in number, p_comment_text in varchar2) return varchar2 deterministic is
/** displaying a Comment in Innovation Tracker Form.
2021.09.07 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'comment_text';
  c_proc_version constant varchar2(5 char) := '1.0';
  c_thumbs_up constant varchar2(400) := '<span aria-hidden="true" class="fa fa-mail-forward fa-flip-vertical fa-lg"></span>';
  v_ln varchar2(32767 char);
  v_out varchar2(32767 char);
begin
  v_ln := to_char(p_level)||'-'||p_comment_text;
 
  v_out := ''
    ||'<table>'
    ||'  <tr>'
    ||'    <td>'||spaces(p_level)||'</td>'
    ||'    <td><span class="u-color-'||to_char(3 * (p_level - 1) - 2)||'-text">'||nvl(case when p_level > 1 then c_thumbs_up end, '&nbsp;')||'</span></td>'
    ||'    <td>'||p_comment_text||'</td>'
    ||'  </tr>'
    ||'</table>'
    ||'';
 
  return v_out;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)||' - '||v_ln); else raise; end if;
end comment_text;
 
function spaces(p_level in number) return varchar2 deterministic is
/** Adding N Spaces to a HTML text.
2021.09.06 - 1.0 - András Tóth - create
2021.09.07 - 1.1 - András Tóth - removing the additional Enter-sign, only add space when level > 1
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'spaces';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ln varchar2(32767 char);
  v_out varchar2(32767 char);
begin
  v_ln := to_char(p_level);
  v_out := '';
  for i in 1..p_level-2 loop
    v_out := v_out || '&nbsp;' || '&nbsp;' || '&nbsp;' || '&nbsp;' || '&nbsp;' || '&nbsp;' || '&nbsp;';
  end loop;
  return v_out;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)||' - '||v_ln); else raise; end if;
end spaces;
 
procedure user_comment_bug (p_id in number, comment_text in varchar2, reply_to_id in number, p_email varchar2 default v('APP_USER'), p_project_id in number default null) is
/** Team to Comment any Innovation Ideas
2021.09.07 - 1.0 - András Tóth - create
2021.09.22 - 1.1 - András Tóth - adding notifications
2021.10.05 - 1.2 - András Tóth - wrong notification recipients corrected
2022.02.22 - 1.3 - András Tóth - `comment_inno_bug` renamed to `user_comment_bug`, update notification chain. new parameter p_project_id
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'user_comment_bug';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_ln varchar2(32767 char);
  v_title varchar2(4000 char);
  v_message_text varchar2(4000 char);
  v_issue_type_id number;
  v_requestor_email varchar2(256 char);
begin
  -- Security
  user_warn_check(p_email);
  test_user_commentable(p_id, p_email, p_project_id);
  if nvl(p_id, p_project_id) is null then return; end if;
 
  v_ln := 'p_project_id='||to_char(p_project_id)||',p_id='||to_char(p_id)||',comment_text='||comment_text||',reply_to_id='||to_char(reply_to_id)||',p_email='||p_email;
 
  -- adding comment
  insert into bugt_bug_comments(id,bug_id,project_id,employee_email,comment_datetime,comment_text,reply_to_id)
  values (BUGT_ID_SEQ.nextval,p_id,p_project_id,lower(p_email),systimestamp,comment_text,reply_to_id);
 
  -- Extra staff When it is a BUG:
  if p_id is not null then
    -- Logging the action
    insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,null,systimestamp,'COMMENTING');
 
    -- Notification Emails:
    v_requestor_email := get_requester(p_id);
    v_issue_type_id := get_bug_issue_type_id(p_id);
    for i in (
      select distinct email from (
        -- BTSes
        select trim(upper(column_value)) as email from table(get_bug_BTSes(p_id)) where v_issue_type_id = c_issue_type_id__inno union all
        -- Requestor
        select trim(upper(v_requestor_email)) as email from dual union all
        -- Reply To
        --select trim(upper(EMPLOYEE_EMAIL)) as email from bugt_bug_comments where id = reply_to_id
        --bhuvi made change
        select trim(upper(PAYLEAD)) from PAY_DIC_PAYLEAD  where STATUS = 'Active' and PAYLEAD_ID = reply_to_id
      ) where email != p_email
    ) loop
      ret_email_msg ('commented', v_title, v_message_text);
      bhu_logs(1,'i.email is '||i.email);
      sendmail(i.email, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT_TEXT#', comment_text, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
      ret_email_msg ('commented-slack', v_title, v_message_text);
      begin
        bhu_logs(1,'i.email is '||i.email);
        sendslack(i.email, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link(p_id), '#BUG_ID#', to_char(p_id), '#SRCATEGORY#', sr_category_name(v_issue_type_id)));
      exception when others then null;
      end;
    end loop;
 
  end if;
 
  -- audit log:
  insert into audit_log values (p_email,v('SESSION'),'Payroll Service Requests Template','USER_COMMENT','USER',systimestamp,c_application_id);
  commit;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)||' - '||v_ln); else raise; end if;
end user_comment_bug;
 
procedure comment_reject_bug (p_id number,p_reason varchar2, p_email varchar2 default v('APP_USER')) is
/** GPO to Comment the Director-rejected bug
2017.04.19 - 1.0 - András Tóth - create
*/
  pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'comment_reject_bug';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_title varchar2(4000 char);
  v_message_text varchar2(4000 char);
  v_to varchar2(256 char);
  v_issue_type_id number;
begin
  -- testing if user is eligable to do this action
  test_reject_commentable(p_id, p_email);
  user_warn_check(p_email);
 
  -- getting additional info
  v_issue_type_id := get_bug_issue_type_id(p_id);
 
  -- changing status
  update bugt_bugs set status_id = status_name_2_status_id(c_status_permanently_rejected) where id = p_id;
 
  -- Logging the action
  insert into bugt_bug_stakeholders (bug_id, employee_email, employee_role, action_time, action) values (p_id,p_email,'GPO_TEAM_MEMBER',systimestamp,'REJECT_COMMENTING');
 
  -- sending out emails
  ret_email_msg ('strong_reject_commented', v_title, v_message_text);
  -- To requester:
  select employee_email into v_to from bugt_bugs where id = p_id;
  sendmail(v_to, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
  -- To last approving Manager:
  select max(employee_email) into v_to from bugt_bug_stakeholders where bug_id = p_id and employee_role = 'MANAGER' and action = 'APPROVE'
         and action_time = ( select max(action_time) from bugt_bug_stakeholders where bug_id = p_id and employee_role = 'MANAGER' and action = 'APPROVE' );
  sendmail(v_to, v_title, pcg.decode_regexp_replace(v_message_text, '#BUGNUMBER#', get_bug_link_a(p_id), '#COMMENT#', p_reason, '#SRCATEGORY#', sr_category_name(v_issue_type_id)), p_email);
 
  insert into audit_log values (p_email,v('SESSION'),'Payroll Service Requests Template','REJECT','USER',systimestamp,c_application_id);
  commit;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end comment_reject_bug;
 
 
 
function get_bug_link_a (p_bug_id number,p_region varchar2 default v('G_USER_REGION')) return varchar2 deterministic as
/** returns an <a> link to the given bug.
2017.04.21 - 1.0 - András Tóth - create
2024.05.22 - 1.1 - Bhuvi Chauhan - Addded new parameter p_region for jose req
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_link_a';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(4000 char);
begin
  return '<a href="'||get_bug_link(p_bug_id)||'">'||p_bug_id||'</a>';
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_link_a;
 
function get_bug_link (p_bug_id number,p_region varchar2 default v('G_USER_REGION')) return varchar2 deterministic as
/** returns an <a> link to the given bug.
2017.04.21 - 1.0 - András Tóth - create
2024.05.22 - 1.1 - Bhuvi Chauhan - Addded new parameter p_region for jose req
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_link';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_ret varchar2(4000 char);
begin
  --return c_APEX_LINK||'f?p='||c_application_id||':100:::::P100_ID:'||p_bug_id;
   RETURN c_APEX_LINK || 'f?p=' || c_application_id || ':100:::::P100_ID,P100_USER_REGION:' || p_bug_id || ',' || v('G_USER_REGION');
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_link;
 
function get_manager(p_bug_id number) return varchar2 deterministic is
/** returns the Manager of a service request.
2021.09.14 - 1.0 - András Tóth - create
*/
  v_tmp varchar2(256 char);
begin
 select manager_email into v_tmp from bugt_bugs where id = p_bug_id;
 return v_tmp;
exception when no_data_found then return null;
end get_manager;
 
function get_requester(p_bug_id number) return varchar2 deterministic is
/** returns the requester of a service request.
2017.05.03 - 1.0 - András Tóth - create
*/
  v_tmp varchar2(256 char);
begin
 select employee_email into v_tmp from bugt_bugs where id = p_bug_id;
 return v_tmp;
exception when no_data_found then return null;
end get_requester;
 
function is_MA_Manager(p_email varchar2) return char deterministic is
begin
 test_MA_manager(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_MA_manager;
 
function is_BTS(p_email varchar2) return char deterministic is
begin
 test_BTS(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_BTS;
 
function is_SME(p_email varchar2, p_region varchar2 default null) return char deterministic is
begin
 test_SME(p_email,p_region);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_SME;
 
function is_MA_Analyst(p_email varchar2) return char deterministic is
begin
 test_MA_analyst(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_MA_Analyst;
 
function is_OP_Manager(p_email varchar2) return char deterministic is
begin
 test_OP_manager(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_OP_Manager;
 
function is_OP_Analyst(p_email varchar2) return char deterministic is
begin
 test_OP_analyst(p_email);
 return c_yes;
exception when pcg.not_authorized then return c_NO;
end is_OP_Analyst;
 
procedure test_op_manager(p_email varchar2) is
/** tests if user has role
2017.07.17 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_op_manager';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin
  select 1 into v_tmp from md_users_v where username = upper(p_email) and role_name = 'OPERATIONS_MANAGER';
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_op_manager;
 
procedure test_op_analyst(p_email varchar2) is
/** tests if user has role
2017.07.17 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_op_analyst';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin
  select 1 into v_tmp from md_users_v where username = upper(p_email) and role_name = 'OPERATIONS_ANALYST';
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_op_analyst;
 
procedure test_ma_analyst(p_email varchar2) is
/** tests if user has role
2017.07.17 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_ma_analyst';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin
  select 1 into v_tmp from md_users_v where username = upper(p_email) and role_name = 'M&A_ANALYST';
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_ma_analyst;
 
procedure test_ma_manager(p_email varchar2) is
/** tests if user has role
2017.07.17 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_ma_manager';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin
  select 1 into v_tmp from md_users_v where username = upper(p_email) and role_name = 'M&A_MANAGER';
exception
when no_data_found then raise pcg.not_authorized;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_ma_manager;
 
procedure test_BTS(p_email varchar2) is
/** tests if user has role
2021.09.10 - 1.0 - András Tóth - create
2021.09.28 - 1.1 - András Tóth - correcting bug, no max() should be applied! Catch the too-many-rows exception as it is OK.
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_bts';
  c_proc_version constant varchar2(5 char) := '1.1';
  v_tmp number;
begin
  -- OIM check:
  test_payroll_org_member(p_email);
  -- special access check:
  select 1 into v_tmp from bugt_inno_btses where employee_email = upper(p_email);
exception
when no_data_found then raise pcg.not_authorized;
when TOO_MANY_ROWS then null;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_BTS;
 
procedure test_SME(p_email varchar2, p_region varchar2 default null) is
/** tests if user has role
2022.07.08 - 1.0 - Marek Szwarczewski - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'test_sme';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_tmp number;
begin
  -- OIM check:
  test_payroll_org_member(p_email);
  -- special access check:
  select distinct(1) into v_tmp from md_sme_bts where upper(username) = upper(p_email) and upper(role) in ('SME', 'BTS') and (upper(region) = upper(p_region) or p_region is null or region is null);
exception
when no_data_found then raise pcg.not_authorized;
when TOO_MANY_ROWS then null;
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end test_SME;
 
function is_qrc(p_bug_id in number) return char is
/** checks if the bug(Service Request) is a Quick R
2018.03.20 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_qrc';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret char;
begin
  -- When the Issue Type is selected as to be a Quick Response type.
  select max(quick_response_sign) into v_ret from bugt_issue_type
    where id = (select max(issue_type_id) from bugt_bugs where id = p_bug_id);
  return nvl(v_ret,'N');
exception
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_qrc;
 
function is_qrc_issue_type(p_type_id in number) return char is
/** checks if the issue type is a quick response type issue type
2018.03.21 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_qrc_issue_type';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ret char;
begin
  select max(quick_response_sign) into v_ret from bugt_issue_type where id = p_type_id;
  return nvl(v_ret,'N');
exception
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_qrc_issue_type;
 
function is_likeable (p_id in number, p_email in varchar2 default v('APP_USER')) return char is
/** checks if one can put Like on an Innovation Idea.
2021.09.07 - 1.0 - András Tóth - create
2021.09.15 - 1.1 - András Tóth - change: likeable until Director approval
2021.09.20 - 1.2 - András Tóth - own request is not likeable anymore.
2021.09.28 - 1.3 - András Tóth - BTS and Director will not like a Request.
 
***********
** Note: **
if you update the procedure, update  P100 - `Action Required` region also in APEX  !!!!!
***********
 
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_likeable';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_issue_type_id number;
  v_status_id number;
  v_employee_email varchar2(256 char);
begin
  -- new is always not likable;
  if nvl(p_id,-1) < 0 then return c_no; end if;
 
  -- Check if user has any roles in the system...?
  if not(is_payroll_org_member(p_email) = 'Y') then return c_no; end if;
 
  -- get Bug details
  select ISSUE_TYPE_ID, STATUS_ID, EMPLOYEE_EMAIL into v_issue_type_id, v_status_id, v_employee_email from bugt_bugs where id = p_id;
 
  -- check if inno-type:
  if v_issue_type_id <> c_issue_type_id__inno then return c_no; end if;
 
  -- own request is not likeable
  if v_employee_email = p_email then return c_No; end if;
 
  -- BTS and Director will not like it:
  if is_director(p_email) = c_Yes or is_BTS(p_email) = c_Yes then return c_No; end if;
 
  --likeable until approved by Director.
  if v_status_id in ( status_name_2_status_id(c_status_submitted), status_name_2_status_id(c_status_gpo_approved) ) then return c_yes; end if;
 
  -- default:
  return c_no;
-- error log:
exception
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_likeable;
 
procedure test_likeable (p_id in number, p_email in varchar2 default v('APP_USER')) is
begin
    if nvl(is_likeable(p_id, p_email), c_no) = c_no then raise pcg.not_authorized; end if;
end test_likeable;
 
/** function is_inno_commentable (p_id in number, p_email in varchar2 default v('APP_USER')) return char is
checks if Innovation Idea can be commented by user.
2021.09.07 - 1.0 - András Tóth - create
2022.02.22 - 1.1 - András Tóth - deprecated
*/
 
function is_User_commentable (p_id in number, p_email in varchar2 default v('APP_USER'), p_project_id in number default null) return char is
/** checks if SR can be commented by user.
2022.02.22 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_User_commentable';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_issue_type_id number;
begin
  return case when bugt_pkg.is_payroll_org_member(p_email) = 'Y' and nvl(p_id, p_project_id) > 0 then c_Yes else c_No end;
-- error log:
exception
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_User_commentable;
 
procedure test_User_commentable (p_id in number, p_email in varchar2 default v('APP_USER'), p_project_id in number default null) is
begin
    if nvl(is_User_commentable(p_id, p_email, p_project_id), c_no) = c_no then raise pcg.not_authorized; end if;
end test_User_commentable;
 
function is_viewable (p_id in number, p_email in varchar2 default v('APP_USER')) return char is
/** checks if the bug/SR can be opened by the user.
2018.07.10 - 1.0 - András Tóth - create
2021.09.14 - 1.1 - András Tóth - optimization and Innovation Tracker updates
2022.03.16 - 1.2 - András Tóth - adding GPO Process type requests
2022.07.08 - 1.3 - Marek Szwarczewski - adding SME role who can see Global or own region SRs.
 
 
***********
** Note: **
if you update the procedure, update  P100 - `SR Report region` region also in APEX  !!!!!
Not done for 1.3 SME not need to check bugs from the page 100. It is fine if they can access them from PPM
***********
 
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_viewable';
  c_proc_version constant varchar2(5 char) := '1.3';
  v_tmp number;
begin
  -- Check if user has any roles in the system...?
  if not(is_payroll_org_member(p_email) = 'Y')
  then return c_no;
  end if;
 
  -- new is always viewable;
  if nvl(p_id,-1) < 0 then return c_yes; end if;
 
  -- Director, Admin and Payroll GPO Systems Team Member can see all:
  if is_Director(p_email) = c_yes or is_Admin(p_email) = c_yes or is_Team_Member(p_email) = c_Yes then return c_yes; end if;
 
  -- GPO Process Team can see all Process-type SRs:
  if c_issue_type_id__gpo_process = get_bug_issue_type_id(p_id) and (is_op_analyst(p_email) = c_yes or is_op_manager(p_email) = c_yes) then return c_yes; end if;
 
  -- SME (and BTS) can see all in their region:
  if is_SME(p_email, get_bug_region(p_id)) = c_yes then return c_yes; end if;
 
  -- SR can be seen when user was among the stakeholders of the SR:
  select nvl(max(1),0) into v_tmp from bugt_bug_stakeholders where bug_id = p_id and employee_email = p_email;
  if v_tmp = 1 then return c_yes; end if;
 
  -- Anyone can see own requests:
  if p_email = get_requester(p_id) then return c_yes; end if;
 
  -- Manager can see requests:
  if p_email = get_manager(p_id) then return c_yes; end if;
 
  -- All Innovation type SRs are open too:
  if get_bug_issue_type_id(p_id) = c_issue_type_id__inno then return c_yes; end if;
 
  -- SR can be seen when editable by the user:
  if is_editable(p_id, p_email) = c_yes then return c_yes; end if;
 
  -- return NO otherwise
  return c_no;
-- error log:
exception
when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_viewable;
 
procedure test_viewable (p_id in number, p_email in varchar2 default v('APP_USER')) is
begin
    if nvl(is_viewable(p_id, p_email), c_no) = c_no then raise pcg.not_authorized; end if;
end test_viewable;
 
function get_bug_history (p_bug_id in number) return varchar2 deterministic is
/** returns the history of a bug in HTML format.
2018.07.13 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_bug_history';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_history varchar2(4000 char);
begin
  select max(history) into v_history from (
  select
    '<p >'||
    listagg(
      to_char(sh.action_time,'YYYY-MM-DD HH24:MI')||' - '||initcap(sh.action)||' - '||pcg.email2name(sh.employee_email)
      ,'<br />')
    WITHIN GROUP (order by sh.action_time asc)
    ||'</p>'
    as history
  from bugt_bug_stakeholders sh where sh.action != 'EDIT' and sh.bug_id = p_bug_id
  group by sh.bug_id
  );
  return v_history;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end get_bug_history;
 
function is_file_required_and_attached (p_id in number, p_issue_type_id in number) return char is
/** Checks, if the issue type requires obligatory attachment and it is attached.
2021.06.03 - 1.0 - András Tóth - create
*/
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'is_file_required_and_attached';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ATTACHMENTS_COUNT number;
  v_access_issue_type_id number;
begin
  select min(id) into v_access_issue_type_id from bugt_issue_type where ISSUE_TYPE_NAME = 'Access';
  if p_issue_type_id = v_access_issue_type_id then
    select count(1) into v_ATTACHMENTS_COUNT from PAY_ATTACHMENTS where bug_id = p_id;
    if nvl(v_ATTACHMENTS_COUNT,0) > 0
      then return 'Y';
      else return 'N';
    end if;
  else
    return 'Y';
  end if;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
end is_file_required_and_attached;
 
procedure like_inno_bug (p_id in number, p_email varchar2 default v('APP_USER')) is
/** Set Like on a Bug.
2021.09.07 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'like_inno_bug';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ln varchar2(32767 char);
  v_rec_id number;
begin
  user_warn_check(p_email);
  test_likeable(p_id, p_email);
 
  select max(id) into v_rec_id from bugt_bug_inno_likes where bug_id = p_id and employee_email = p_email;
 
  if v_rec_id is not null then
    update bugt_bug_inno_likes set yes_or_no_sign = 'Y'
    where bug_id = p_id and employee_email = p_email;
  else
    insert into bugt_bug_inno_likes (id, bug_id, employee_email, yes_or_no_sign)
    values (BUGT_ID_SEQ.nextval, p_id, p_email, 'Y');
  end if;
 
  commit;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)||' - '||v_ln); else raise; end if;
end like_inno_bug;
 
procedure dislike_inno_bug (p_id in number, p_email varchar2 default v('APP_USER')) is
/** Set DisLike on a Bug.
2021.09.07 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'dislike_inno_bug';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ln varchar2(32767 char);
  v_rec_id number;
begin
  user_warn_check(p_email);
  test_likeable(p_id, p_email);
 
  select max(id) into v_rec_id from bugt_bug_inno_likes where bug_id = p_id and employee_email = p_email;
 
  if v_rec_id is not null then
    update bugt_bug_inno_likes set yes_or_no_sign = 'N'
    where bug_id = p_id and employee_email = p_email;
  else
    insert into bugt_bug_inno_likes (id, bug_id, employee_email, yes_or_no_sign)
    values (BUGT_ID_SEQ.nextval, p_id, p_email, 'N');
  end if;
 
  commit;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)||' - '||v_ln); else raise; end if;
end dislike_inno_bug;
 
procedure clearlike_inno_bug (p_id in number, p_email varchar2 default v('APP_USER')) is
/** CClear Like on a Bug.
2021.09.07 - 1.0 - András Tóth - create
*/
pragma autonomous_transaction;
  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'clearlike_inno_bug';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ln varchar2(32767 char);
  v_rec_id number;
begin
  user_warn_check(p_email);
  test_likeable(p_id, p_email);
 
  delete from bugt_bug_inno_likes where bug_id = p_id and employee_email = p_email;
 
  commit;
exception when others then
  pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end||' - '||v_ln, SQLCODE);
  if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)||' - '||v_ln); else raise; end if;
end clearlike_inno_bug;
 
procedure sendslack(p_email in varchar2, p_msg in varchar2, p_channel in varchar2 default null) is
begin
  if pcg.is_prod_env = 'Y' then
    pcg.sendslack(p_email, p_msg, p_channel);
  else
    begin
      pcg.sendslack('rohit.bq.kumar@oracle.com', '*'||p_email||':'||p_channel||'*  ---  '||p_msg);
    exception when others then null;
    end;
  end if;
end sendslack;
 
function sr_category_name(p_issue_type_id in number) return varchar2 deterministic is
begin
  return
    case p_issue_type_id
    when c_issue_type_id__inno then 'Innovation Idea'
    else 'Service Request'
  end;
end sr_category_name;

function get_region_count(p_email IN VARCHAR2) RETURN NUMBER IS
/* returns the number of region user is responsible for 
2024.05.15 - 1.0 - Bhuvi Chauhan - create
*/  
    c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'get_region_count';
    c_proc_version constant varchar2(5 char) := '1.0';
    v_region_count NUMBER;
BEGIN
    SELECT COUNT(DISTINCT region)
    INTO v_region_count
    FROM md_users_v
    WHERE username = p_email;

    RETURN v_region_count;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0; -- Return 0 if no regions found for the username
    WHEN OTHERS THEN
        pcg.log(c_proc_name, c_version, c_proc_version, case when SQLCODE between -20999 and -20000 then pcg.get_SQLERRM(SQLCODE) else SQLERRM end, SQLCODE);
        if SQLCODE between -20999 and -20000 then raise_application_error(SQLCODE,pcg.get_SQLERRM(SQLCODE)); else raise; end if;
END get_region_count;

/** Returns the SR number for creating the folder/path for uploading the file.
09-SEP-2025 - 1.0 - Bhuvi Chauhan - Create
08-OCT-2025 - 1.3 - Bhuvi Chauhan - Added p_project_id paramters as well to handle cases when direct project is created and no SR.
**/
FUNCTION sr_key (p_sr_id NUMBER, p_project_id NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_sr_id IS NOT NULL THEN
      RETURN 'SR '||p_sr_id;
    ELSIF p_project_id IS NOT NULL THEN
        RETURN 'PROJECT '||p_project_id;  
    ELSE
      RETURN 'UNASSIGNED';
    END IF;
  END;

/** For uploading the SR ATTACHMENTS in the Sharepoint.
09-SEP-2025 - 1.0 - Bhuvi Chauhan - Create
08-OCT-2025 - 1.3 - Bhuvi Chauhan - Added p_project_id paramters as well to handle cases when direct project is created and no SR.
**/
PROCEDURE att_upload_sp (
    p_sr_id             IN NUMBER,
    p_project_id        IN NUMBER,
    p_title             IN VARCHAR2,
    p_comments          IN VARCHAR2,
    p_att_selector      IN VARCHAR2,
    p_site_id           IN VARCHAR2,
    p_drive_id          IN VARCHAR2,
    p_user              IN VARCHAR2 DEFAULT v('APP_USER')
  ) IS
    c_small_max CONSTANT PLS_INTEGER := 4*1024*1024;

  l_apex_root_id  VARCHAR2(150);     -- folder_id of "APEX Integration"
  l_folder_path   VARCHAR2(1000);    -- path relative to APEX Integration
  l_folder_id     VARCHAR2(150);     -- final parent folder id

    l_json       CLOB;
    l_item_id    VARCHAR2(150);
    l_web_url    VARCHAR2(1000);
    l_size       NUMBER;
    l_sha1       VARCHAR2(64);
    l_sp_file_id NUMBER;

  BEGIN
    -- Build SP target: APEX Integration / PPM / SR ATTACHMENTS / <SR_KEY>
    l_apex_root_id := PRL_MS_GRAPH_UTL_PK.apex_root_folder_id(p_site_id, p_drive_id);
    l_folder_path    := 'PPM/SR ATTACHMENTS/'|| sr_key(p_sr_Id,p_project_id);

    l_folder_id := PRL_MS_GRAPH_UTL_PK.ensure_folder_hierarchy(
                     p_site_id  => p_site_id,
                     p_drive_id => p_drive_id,
                     p_root_id  => l_apex_root_id,
                     p_path     => l_folder_path);

    FOR f IN (
      SELECT name, filename, mime_type, created_on, blob_content,
             DBMS_LOB.getlength(blob_content) len
      FROM   apex_application_temp_files
      WHERE  name IN (SELECT column_value
                      FROM TABLE(apex_string.split(p_att_selector, ':')))
    ) LOOP
      IF f.len <= c_small_max THEN
        l_json := PRL_MS_GRAPH_UTL_PK.upload_file_small_json(
                    p_site_id, p_drive_id, l_folder_id, f.filename, f.blob_content, f.mime_type);
      ELSE
        l_json := PRL_MS_GRAPH_UTL_PK.upload_file_large_json(
                    p_site_id, p_drive_id, l_folder_id, f.filename, f.blob_content, f.mime_type);
      END IF;

      l_item_id := JSON_VALUE(l_json,'$.id');
      l_web_url := JSON_VALUE(l_json,'$.webUrl');
      l_size    := TO_NUMBER(JSON_VALUE(l_json,'$.size'));
      l_sha1    := JSON_VALUE(l_json,'$.file.hashes.sha1Hash');

      INSERT INTO sp_files(
        app_id, app_name, entity_name, entity_id, 
        site_id, drive_id, folder_id, folder_path,
        filename, content_type, size_bytes, sha1_hash,
        sp_item_id, web_url, created_by, created_at
      ) VALUES (
        v('APP_ID'), 'PPM', 'SR ATTACHMENTS',
        NVL(TO_CHAR(p_sr_id),TO_CHAR(p_project_id)),     -- entity_id (string key)
        p_site_id, p_drive_id, l_folder_id, 'APEX Integration/'||l_folder_path,
        f.filename, f.mime_type, l_size, l_sha1,
        l_item_id, l_web_url, p_user, SYSTIMESTAMP
      )
      RETURNING id INTO l_sp_file_id;

      INSERT INTO pay_attachments(
        filename, file_mimetype, file_blob, tags, file_comments,
        project_id, bug_id, created, created_by, sp_file_id
      ) VALUES (
        f.filename, f.mime_type, NULL, p_title, p_comments,
        p_project_id, p_sr_Id, SYSDATE, p_user, l_sp_file_id
      );
    END LOOP;

    DELETE FROM apex_application_temp_files
     WHERE name IN (SELECT column_value FROM TABLE(apex_string.split(p_att_selector, ':')));
  END att_upload_sp;
 
 /** For Update (metadata only, or replace file if selector is provided)
09-SEP-2025 - 1.0 - Bhuvi Chauhan - Create
11-SEP-2025 - 1.1 - Bhuvi Chauhan - Updated the att_update_sp for cases where user edit their prev attachment and upload a replacement (new attachment) for the existing one.
12-SEP-2025 - 1.2 - Bhuvi Chauhan - Fixed the attachment replacemenet scenario as file was getting replaced but in sharepoint the filename and filetype and extension url stays the same.
08-OCT-2025 - 1.3 - Bhuvi Chauhan - Added p_project_id paramters as well to handle cases when direct project is created and no SR.
**/
PROCEDURE att_update_sp (
    p_file_id           IN NUMBER,
    p_sr_id             IN NUMBER,
    p_project_id        IN NUMBER,
    p_title             IN VARCHAR2,
    p_comments          IN VARCHAR2,
    p_att_selector      IN VARCHAR2,
    p_site_id           IN VARCHAR2,
    p_drive_id          IN VARCHAR2,
    p_user              IN VARCHAR2 DEFAULT v('APP_USER')
  ) IS
    c_small_max CONSTANT PLS_INTEGER := 4*1024*1024;

    l_sp_file_id NUMBER;
    l_folder_id  VARCHAR2(150);
    l_json       CLOB;
    l_item_id    VARCHAR2(150);
    l_web_url    VARCHAR2(1000);
    l_size       NUMBER;
    l_sha1       VARCHAR2(64);
    l_name       VARCHAR2(255);
    l_mime       VARCHAR2(255);

    -- DB values from sp_files if mapping exists
    l_site_id_db  VARCHAR2(200);
    l_drive_id_db VARCHAR2(200);
    l_sp_item_id  VARCHAR2(200);

    -- existing filename for rename comparison
    l_existing_name VARCHAR2(400);
  BEGIN
    -- start log
    bhu_logs(8000, 'att_update_sp START - file_id='||p_file_id||' sr_id='||p_sr_id||' selector='||NVL(p_att_selector,'<null>'), 'att_update');

    -- update app-level metadata (title/comments)
    UPDATE pay_attachments
       SET tags          = p_title,
           file_comments = p_comments,
           updated       = SYSDATE,
           updated_by    = p_user
     WHERE file_id = p_file_id;

    -- metadata-only -> exit
    IF p_att_selector IS NULL OR TRIM(p_att_selector) = '' THEN
      bhu_logs(8001, 'att_update_sp metadata-only, exit', 'att_update');
      RETURN;
    END IF;

    -- fetch mapping (if any)
    BEGIN
      SELECT s.id, s.folder_id, s.sp_item_id, s.site_id, s.drive_id
        INTO l_sp_file_id, l_folder_id, l_sp_item_id, l_site_id_db, l_drive_id_db
      FROM pay_attachments a
      LEFT JOIN sp_files s ON s.id = a.sp_file_id
      WHERE a.file_id = p_file_id;
      bhu_logs(8002, 'Mapping: sp_file_id='||NVL(TO_CHAR(l_sp_file_id),'NULL')||' folder_id='||NVL(l_folder_id,'NULL')||' sp_item_id='||NVL(l_sp_item_id,'NULL'), 'att_update');
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_sp_file_id := NULL;
        l_folder_id := NULL;
        l_sp_item_id := NULL;
        l_site_id_db := NULL;
        l_drive_id_db := NULL;
        bhu_logs(8003, 'Mapping: NO_DATA_FOUND for pay_attachments.file_id='||p_file_id, 'att_update');
    END;

    -- if folder id missing, ensure hierarchy under APEX Integration
    IF l_folder_id IS NULL THEN
      DECLARE
        l_apex_root_id VARCHAR2(150);
      BEGIN
        l_apex_root_id := PRL_MS_GRAPH_UTL_PK.apex_root_folder_id(p_site_id => p_site_id, p_drive_id => p_drive_id);
        bhu_logs(8004, 'apex_root_folder_id='||NVL(l_apex_root_id,'NULL'), 'att_update');

        IF l_apex_root_id IS NULL THEN
          RAISE_APPLICATION_ERROR(-20093, '"APEX Integration" folder not found or not accessible.');
        END IF;

        l_folder_id := PRL_MS_GRAPH_UTL_PK.ensure_folder_hierarchy(
                         p_site_id  => p_site_id,
                         p_drive_id => p_drive_id,
                         p_root_id  => l_apex_root_id,
                         p_path     => case when p_sr_id is not null then 'PPM/SR Attachments/'||'SR '||p_sr_id else 'PPM/SR Attachments/'||'PROJECT '||p_project_id end
                       );
        bhu_logs(8005, 'ensure_folder_hierarchy returned folder_id='||NVL(l_folder_id,'NULL'), 'att_update');

        IF l_folder_id IS NULL THEN
          RAISE_APPLICATION_ERROR(-20094, 'Could not resolve/create target path under "APEX Integration".');
        END IF;
      END;
    ELSE
      bhu_logs(8006, 'Using folder_id from mapping='||l_folder_id, 'att_update');
    END IF;

    -- Read temp file and upload (single file expected)
    DECLARE
      r_filename   VARCHAR2(255);
      r_mime       VARCHAR2(255);
      r_blob       BLOB;
      r_len        PLS_INTEGER;
    BEGIN
      SELECT filename, mime_type, blob_content, DBMS_LOB.getlength(blob_content)
      INTO   r_filename, r_mime, r_blob, r_len
      FROM   apex_application_temp_files
      WHERE  name = p_att_selector;

      bhu_logs(8007, 'Temp file: name='||NVL(r_filename,'NULL')||' mime='||NVL(r_mime,'NULL')||' len='||NVL(TO_CHAR(r_len),'0'), 'att_update');

      -- decide overwrite vs new upload
      IF l_sp_file_id IS NOT NULL AND l_sp_item_id IS NOT NULL THEN
        bhu_logs(8008, 'Overwrite path (by item_id) chosen: item='||l_sp_item_id, 'att_update');

        l_json := PRL_MS_GRAPH_UTL_PK.upload_file_by_item_id(
                    p_site_id   => NVL(l_site_id_db, p_site_id),
                    p_drive_id  => NVL(l_drive_id_db, p_drive_id),
                    p_item_id   => l_sp_item_id,
                    p_file_blob => r_blob,
                    p_file_name => r_filename,
                    p_mime_type => r_mime
                  );

        bhu_logs(8009, 'upload_file_by_item_id HTTP='||APEX_WEB_SERVICE.g_status_code, 'att_update');
        bhu_logs(8010, 'upload_by_item response start='||SUBSTR(NVL(l_json,'<null>'),1,1000), 'att_update');

      ELSE
        bhu_logs(8011, 'New upload path chosen. folder_id='||NVL(l_folder_id,'NULL'), 'att_update');

        IF r_len <= c_small_max THEN
          l_json := PRL_MS_GRAPH_UTL_PK.upload_file_small_json(
                      p_site_id    => p_site_id,
                      p_drive_id   => p_drive_id,
                      p_parent_id  => l_folder_id,
                      p_file_name  => r_filename,
                      p_file_blob  => r_blob,
                      p_mime_type  => r_mime);
          bhu_logs(8012, 'Called upload_file_small_json HTTP='||APEX_WEB_SERVICE.g_status_code, 'att_update');
        ELSE
          l_json := PRL_MS_GRAPH_UTL_PK.upload_file_large_json(
                      p_site_id    => p_site_id,
                      p_drive_id   => p_drive_id,
                      p_parent_id  => l_folder_id,
                      p_file_name  => r_filename,
                      p_file_blob  => r_blob,
                      p_mime_type  => r_mime);
          bhu_logs(8013, 'Called upload_file_large_json HTTP='||APEX_WEB_SERVICE.g_status_code, 'att_update');
        END IF;

        bhu_logs(8014, 'new upload response start='||SUBSTR(NVL(l_json,'<null>'),1,1000), 'att_update');
      END IF;

      -- parse DriveItem JSON safely
      BEGIN l_item_id := JSON_VALUE(l_json,'$.id'); EXCEPTION WHEN OTHERS THEN l_item_id := NULL; END;
      BEGIN l_web_url := JSON_VALUE(l_json,'$.webUrl'); EXCEPTION WHEN OTHERS THEN l_web_url := NULL; END;
      BEGIN l_size := CASE WHEN JSON_EXISTS(l_json,'$.size') THEN TO_NUMBER(JSON_VALUE(l_json,'$.size')) ELSE NULL END; EXCEPTION WHEN OTHERS THEN l_size := NULL; END;
      BEGIN l_sha1 := CASE WHEN JSON_EXISTS(l_json,'$.file.hashes.sha1Hash') THEN JSON_VALUE(l_json,'$.file.hashes.sha1Hash') ELSE NULL END; EXCEPTION WHEN OTHERS THEN l_sha1 := NULL; END;

      l_name := r_filename;
      l_mime := r_mime;

      bhu_logs(8015, 'Parsed DriveItem: id='||NVL(l_item_id,'NULL')||' size='||NVL(TO_CHAR(l_size),'NULL')||' sha1='||NVL(l_sha1,'NULL'), 'att_update');

    END;

    -- fetch existing filename from sp_files (if mapping exists) for rename decision
    IF l_sp_file_id IS NOT NULL THEN
      BEGIN
        SELECT filename INTO l_existing_name FROM sp_files WHERE id = l_sp_file_id;
      EXCEPTION WHEN NO_DATA_FOUND THEN l_existing_name := NULL;
      END;
    ELSE
      l_existing_name := NULL;
    END IF;

    -- If mapping exists then update row, else insert new row & update mapping
    IF l_sp_file_id IS NULL THEN
      INSERT INTO sp_files(app_id,app_name,entity_name,entity_id,
                           site_id,drive_id,folder_id,folder_path,
                           filename,content_type,size_bytes,sha1_hash,
                           sp_item_id,web_url,created_by,created_at)
      VALUES (v('APP_ID'),'PPM','SR ATTACHMENTS', NVL(TO_CHAR(p_sr_id),TO_CHAR(p_project_id)),
             p_site_id,p_drive_id,l_folder_id,'APEX Integration/PPM/SR ATTACHMENTS/'||'SR '||p_sr_id,
             l_name,l_mime,l_size,l_sha1,l_item_id,l_web_url,p_user,SYSTIMESTAMP)
      RETURNING id INTO l_sp_file_id;

      UPDATE pay_attachments SET sp_file_id = l_sp_file_id WHERE file_id = p_file_id;
      bhu_logs(8016, 'Inserted sp_files id='||l_sp_file_id, 'att_update');
    ELSE
      UPDATE sp_files
         SET filename     = l_name,
             content_type = l_mime,
             size_bytes   = l_size,
             sha1_hash    = l_sha1,
             sp_item_id   = l_item_id,
             web_url      = l_web_url,
             updated_by   = p_user,
             updated_at   = SYSTIMESTAMP
       WHERE id = l_sp_file_id;
      bhu_logs(8017, 'Updated sp_files id='||l_sp_file_id||' new_item_id='||NVL(l_item_id,'NULL'), 'att_update');
    END IF;

    -- Attempt to rename the DriveItem if the visible filename changed (non-fatal)
    BEGIN
      IF l_item_id IS NOT NULL AND l_name IS NOT NULL
         AND (l_existing_name IS NULL OR l_existing_name != l_name) THEN

        BEGIN
          -- Use site/drive from DB when available, otherwise use provided params
        l_json :=  PRL_MS_GRAPH_UTL_PK.update_item_metadata(
            p_site_id   => NVL(l_site_id_db, p_site_id),
            p_drive_id  => NVL(l_drive_id_db, p_drive_id),
            p_item_id   => l_item_id,
            p_body_json => '{"name":"'|| REPLACE(l_name, '"', '\"') ||'"}'
          );
          bhu_logs(8030, 'Rename succeeded for item '||l_item_id||' -> '||l_name, 'att_update');
        EXCEPTION
          WHEN OTHERS THEN
            bhu_logs(8031, 'Rename FAILED for item '||NVL(l_item_id,'?')||' err='||SQLERRM, 'att_update');
            -- don't raise; rename failure shouldn't block main flow
        END;

      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        bhu_logs(8032, 'Rename-check exception: '||SQLERRM, 'att_update');
    END;

    -- update pay_attachments metadata, clear blob
    UPDATE pay_attachments
       SET filename = l_name,
           file_mimetype = l_mime,
           file_blob = NULL,
           updated = SYSDATE,
           updated_by = p_user
     WHERE file_id = p_file_id;

    -- cleanup temp file
    DELETE FROM apex_application_temp_files WHERE name = p_att_selector;

    bhu_logs(8018, 'att_update_sp COMPLETE for file_id='||p_file_id||' sp_file_id='||NVL(TO_CHAR(l_sp_file_id),'NULL'), 'att_update');

  EXCEPTION
    WHEN OTHERS THEN
      pcg.log('BUGT_PKG.att_update_sp', 'n/a', '1.0', SQLERRM, SQLCODE, 'ERROR');
      bhu_logs(8999, 'att_update_sp ERROR: '||SQLERRM, 'att_update');
      RAISE;
  END att_update_sp;
 /** For Delete (SharePoint + DB) – autonomous
09-SEP-2025 - 1.0 - Bhuvi Chauhan - Create
**/

PROCEDURE att_delete_sp (
    p_file_id IN NUMBER,
    p_user    IN VARCHAR2 DEFAULT v('APP_USER')
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;

    l_sp_file_id NUMBER;
    l_site_id  VARCHAR2(200);
    l_drive_id VARCHAR2(200);
    l_item_id  VARCHAR2(200);
  BEGIN
    SELECT sp_file_id INTO l_sp_file_id
    FROM   pay_attachments
    WHERE  file_id = p_file_id;

    IF l_sp_file_id IS NOT NULL THEN
      BEGIN
        SELECT site_id, drive_id, sp_item_id
          INTO l_site_id, l_drive_id, l_item_id
          FROM sp_files
         WHERE id = l_sp_file_id;

        BEGIN
          PRL_MS_GRAPH_UTL_PK.delete_item(l_site_id, l_drive_id, l_item_id);
        EXCEPTION WHEN OTHERS THEN NULL; END;
      EXCEPTION WHEN NO_DATA_FOUND THEN NULL; END;

      DELETE FROM sp_files WHERE id = l_sp_file_id;  -- CASCADE cleans child if FK set
    END IF;

    DELETE FROM pay_attachments WHERE file_id = p_file_id; -- idempotent
    COMMIT;
  END att_delete_sp;

 /** For Download (SharePoint first, legacy fallback)
09-SEP-2025 - 1.0 - Bhuvi Chauhan - Create
**/

PROCEDURE att_download_sp (p_file_id IN NUMBER) IS
    l_sp_file_id NUMBER;
    l_site_id  VARCHAR2(200);
    l_drive_id VARCHAR2(200);
    l_item_id  VARCHAR2(200);
    l_name     VARCHAR2(255);
    l_mime     VARCHAR2(255);
    l_blob     BLOB;
  BEGIN
    SELECT a.sp_file_id, s.site_id, s.drive_id, s.sp_item_id,
           NVL(a.filename, s.filename), NVL(a.file_mimetype, s.content_type)
    INTO   l_sp_file_id, l_site_id, l_drive_id, l_item_id, l_name, l_mime
    FROM   pay_attachments a
           LEFT JOIN sp_files s ON s.id = a.sp_file_id
    WHERE  a.file_id = p_file_id;

    IF l_sp_file_id IS NOT NULL AND l_site_id IS NOT NULL AND l_item_id IS NOT NULL THEN
      PRL_MS_GRAPH_UTL_PK.download_file(
        p_site_id   => l_site_id,
        p_drive_id  => l_drive_id,
        p_item_id   => l_item_id,
        p_file_name => NVL(l_name,'file'),
        p_mime_type => NVL(l_mime,'application/octet-stream'));
      RETURN;
    END IF;

    -- legacy fallback
    SELECT file_blob, file_mimetype, filename
    INTO   l_blob, l_mime, l_name
    FROM   pay_attachments
    WHERE  file_id = p_file_id;

    owa_util.mime_header(NVL(l_mime,'application/octet-stream'), FALSE);
    htp.p('Content-Disposition: attachment; filename="'||REPLACE(NVL(l_name,'file'),'"','')||'"');
    htp.p('Content-Length: '||DBMS_LOB.getlength(l_blob));
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
    apex_application.stop_apex_engine;
  END att_download_sp;

/* For migrating files to SharePoint
06-Oct-2025 - 1.0 - Bhuvi Chauhan - migrate PPM attachments to SharePoint
08-Oct-2025 - 1.1 - Bhuvi Chauhan - Added handling when bug_id is NULL but project_id exists
*/
PROCEDURE migrate_ppm_files_to_sp (
  p_site_id     IN VARCHAR2,
  p_drive_id    IN VARCHAR2,
  p_user        IN VARCHAR2 DEFAULT v('APP_USER'),
  p_limit       IN PLS_INTEGER DEFAULT 50,         -- batch size
  p_clear_blob  IN BOOLEAN    DEFAULT FALSE        -- FALSE = safe mode (keep legacy BLOBs)
) IS
  c_small_max CONSTANT PLS_INTEGER := 4*1024*1024;  -- 4MB

  l_apex_root_id  VARCHAR2(150);
  l_folder_id     VARCHAR2(150);
  l_folder_path   VARCHAR2(1000);

  l_json          CLOB;
  l_item_id       VARCHAR2(150);
  l_web_url       VARCHAR2(1000);
  l_size          NUMBER;
  l_sha1          VARCHAR2(64);
  l_sp_file_id    NUMBER;

  l_done          PLS_INTEGER := 0;
  l_failed        PLS_INTEGER := 0;
  l_status        PLS_INTEGER;

-- entity info (will always use entity_name = 'SR ATTACHMENTS')
  l_entity_name   CONSTANT VARCHAR2(100) := 'SR ATTACHMENTS';
  l_entity_id     VARCHAR2(100);
BEGIN
  -- 0) Preconditions
  IF p_site_id IS NULL OR p_drive_id IS NULL THEN
    RAISE_APPLICATION_ERROR(-20090, 'SharePoint site/drive not initialized.');
  END IF;

  -- 1) Anchor to "APEX Integration"
  l_apex_root_id := PRL_MS_GRAPH_UTL_PK.apex_root_folder_id(p_site_id, p_drive_id);
  IF l_apex_root_id IS NULL THEN
    RAISE_APPLICATION_ERROR(-20093, '"APEX Integration" root folder not found or not accessible.');
  END IF;

  pcg.log(c_pkg_name||'.migrate_ppm_files_to_sp', c_pkg_version, '1.0',
          'Batch start: limit='||p_limit||', clear_blob='||(CASE WHEN p_clear_blob THEN 'Y' ELSE 'N' END),
          NULL, 'INFO');

  -- 2) Batch selection (include project_id & bug_id)
  FOR rec IN (
    SELECT file_id, project_id, bug_id, filename, file_mimetype, file_blob, created, created_by
    FROM   pay_attachments
    WHERE  file_blob IS NOT NULL
      AND  NVL(sp_file_id,0) = 0
      AND  DBMS_LOB.getlength(file_blob) > 0      -- Added to overcome migration failed error due to such blobs with no content
    ORDER BY file_id
    FETCH FIRST p_limit ROWS ONLY
  ) LOOP
    BEGIN
-- Decide subfolder under SR ATTACHMENTS
      IF rec.bug_id IS NOT NULL THEN
        l_entity_id := TO_CHAR(rec.bug_id);
        l_folder_path := 'PPM/SR ATTACHMENTS/SR ' || rec.bug_id;
      ELSIF rec.project_id IS NOT NULL THEN
        l_entity_id := TO_CHAR(rec.project_id);
        l_folder_path := 'PPM/SR ATTACHMENTS/PROJECT ' || rec.project_id;
      ELSE
        -- neither SR nor project -> put under UNASSIGNED subfolder to avoid losing file
        l_entity_id := '0';
        l_folder_path := 'PPM/SR ATTACHMENTS/UNASSIGNED';
      END IF;

      -- Ensure folder path under APEX Integration
      l_folder_id := PRL_MS_GRAPH_UTL_PK.ensure_folder_hierarchy(
                      p_site_id  => p_site_id,
                      p_drive_id => p_drive_id,
                      p_root_id  => l_apex_root_id,
                      p_path     => l_folder_path);

      IF l_folder_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20094, 'Could not resolve/create target path: '||l_folder_path);
      END IF;

      -- Upload file (small vs large)
      IF DBMS_LOB.getlength(rec.file_blob) <= c_small_max THEN
        l_json := PRL_MS_GRAPH_UTL_PK.upload_file_small_json(
                    p_site_id    => p_site_id,
                    p_drive_id   => p_drive_id,
                    p_parent_id  => l_folder_id,
                    p_file_name  => rec.filename,
                    p_file_blob  => rec.file_blob,
                    p_mime_type  => rec.file_mimetype);
      ELSE
        l_json := PRL_MS_GRAPH_UTL_PK.upload_file_large_json(
                    p_site_id    => p_site_id,
                    p_drive_id   => p_drive_id,
                    p_parent_id  => l_folder_id,
                    p_file_name  => rec.filename,
                    p_file_blob  => rec.file_blob,
                    p_mime_type  => rec.file_mimetype);
      END IF;

      -- HTTP status check (helper sets apex_web_service.g_status_code)
      l_status := APEX_WEB_SERVICE.g_status_code;
      IF l_status NOT IN (200,201) THEN
        RAISE_APPLICATION_ERROR(-20091,
          'SP upload failed. HTTP='||l_status||' Body='||SUBSTR(NVL(l_json,'<null>'),1,500));
      END IF;

      -- Parse response
      l_item_id := JSON_VALUE(l_json,'$.id');
      l_web_url := JSON_VALUE(l_json,'$.webUrl');
      l_size    := CASE WHEN JSON_EXISTS(l_json, '$.size') THEN TO_NUMBER(JSON_VALUE(l_json,'$.size')) ELSE NULL END;
      l_sha1    := JSON_VALUE(l_json,'$.file.hashes.sha1Hash');

      IF l_item_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20092,
          'Upload returned no item id. Body='||SUBSTR(NVL(l_json,'<null>'),1,500));
      END IF;

      -- Insert master metadata row in sp_files. If duplicate (unique constraint), try to reuse existing.
      BEGIN
        INSERT INTO sp_files (
          app_id, app_name, entity_name, entity_id, file_category_id,
          site_id, drive_id, folder_id, folder_path,
          filename, content_type, size_bytes, sha1_hash,
          sp_item_id, web_url, created_by, created_at
        ) VALUES (
          v('APP_ID'), 'PPM', l_entity_name, NVL(l_entity_id,'0'), NULL,
          p_site_id, p_drive_id, l_folder_id, 'APEX Integration/'||l_folder_path,
          rec.filename, rec.file_mimetype, l_size, NVL(l_sha1,''),
          l_item_id, l_web_url, p_user, SYSTIMESTAMP
        )
        RETURNING id INTO l_sp_file_id;
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          -- If insert failed because a row already exists for this sp_item_id, reuse it.
          BEGIN
            SELECT id INTO l_sp_file_id
            FROM sp_files
            WHERE sp_item_id = l_item_id
            AND ROWNUM = 1;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              -- re-raise - unexpected
              RAISE;
          END;
      END;

      -- Update local mapping in pay_attachments; optionally clear BLOB
      IF p_clear_blob THEN
        UPDATE pay_attachments
           SET sp_file_id = l_sp_file_id,
               file_blob  = NULL,
               updated    = SYSDATE,
               updated_by = p_user
         WHERE file_id = rec.file_id;
      ELSE
        UPDATE pay_attachments
           SET sp_file_id = l_sp_file_id,
               updated    = SYSDATE,
               updated_by = p_user
         WHERE file_id = rec.file_id;
      END IF;

      COMMIT;  -- per-file commit
      l_done := l_done + 1;

      pcg.log(c_pkg_name||'.migrate_ppm_files_to_sp', c_pkg_version, '1.0',
              'OK: id='||rec.file_id||' entity='||l_entity_name||'('||l_entity_id||')'||
              ' -> sp_file_id='||l_sp_file_id||' item_id='||l_item_id,
              NULL, 'INFO');

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        l_failed := l_failed + 1;
        pcg.log(c_pkg_name||'.migrate_ppm_files_to_sp', c_pkg_version, '1.0',
                'FAIL: id='||rec.file_id||' entity='||NVL(l_entity_name,'?')||'('||NVL(l_entity_id,'?')||')'||
                ' msg='||SQLERRM||' body='||SUBSTR(NVL(l_json,'<null>'),1,500)||
                ' stack='||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                SQLCODE, 'ERROR');
        -- continue with next row
    END;
  END LOOP;

  pcg.log(c_pkg_name||'.migrate_ppm_files_to_sp', c_pkg_version, '1.0',
          'Batch end: migrated='||l_done||' failed='||l_failed, NULL, 'INFO');

EXCEPTION
  WHEN OTHERS THEN
    pcg.log(c_pkg_name||'.migrate_ppm_files_to_sp', c_pkg_version, '1.0',
            'Fatal: '||SQLERRM||' stack='||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
            SQLCODE, 'ERROR');
    RAISE;
END migrate_ppm_files_to_sp;

end BUGT_pkg;
/