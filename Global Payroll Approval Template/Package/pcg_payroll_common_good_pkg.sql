create or replace package PCG_Payroll_Common_Good_pkg as
--'PCG_PAYROLL_COMMON_GOOD_PKG'

-- Constants --
c_YES constant char := 'Y';
c_NO constant char := 'N';
c_WS_NAME varchar2(4000 char) := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
c_WS_ID varchar2(4000 char) := v('WORKSPACE_ID');
c_Prod_WS_NAME constant varchar2(30 char):= 'PAYROLL_PROD';
c_Prod_WS_ID constant varchar2(20 char):= '13457932919518590877';
c_Test_WS_NAME constant varchar2(30 char):= 'PAYROLL_DEV';
c_Test_WS_ID constant varchar2(20 char):= '974584228257060843';
c_pkg_name constant varchar2(30 char) := 'pcg_payroll_common_good_pkg';
c_new_line constant varchar2(2 char) := CHR(10)||CHR(13);
c_line_feed constant varchar2(1 char) := CHR(10);
c_max_pls_integer constant pls_integer := 2147483647;
c_32k constant number := 32767;
c_cache_ldap_expire_days constant number := 5; /* number of days to requery the LDAP dictionary */
c_Debug constant varchar2(50 char) := 'DEBUG';
c_Info constant varchar2(50 char) := 'INFO';
c_Warn constant varchar2(50 char) := 'WARN';
c_Error constant varchar2(50 char) := 'ERROR';
c_Fatal constant varchar2(50 char) := 'FATAL';
c_GCW_TEST constant varchar2(10 char) := 'GCWAU';
c_GCW_PROD constant varchar2(10 char) := 'GCWAP';
c_is_prod_env varchar2(2 char);
c_retry_threshold number := 4;
c_retry_sleep_time number := 3;

c_vcalendar_template constant varchar2(32767):=''
  ||'BEGIN:VCALENDAR'||c_new_line
  ||'VERSION:2.0'||c_new_line
  ||'PRODID:-//ORACLE//NONSGML ICAL_EVENT//EN'||c_new_line
  ||'METHOD:PUBLISH'||c_new_line
  ||'BEGIN:VEVENT'||c_new_line
  ||'SUMMARY:#SUBJECT#'||c_new_line
  ||'DESCRIPTION:#DESC#'||c_new_line
  ||'ORGANIZER;CN=#ONAME#:MAILTO:#ORGANIZER#'||c_new_line
  ||'UID:#UID#'||c_new_line
  ||'DTSTAMP:#CREATION_DATE#'||c_new_line
  ||'DTSTART:#START#'||c_new_line
  ||'DTEND:#END#'||c_new_line
  ||'LOCATION:#LOC#'||c_new_line
  ||'STATUS:CONFIRMED'||c_new_line
  ||'BEGIN:VALARM'||c_new_line
  ||'TRIGGER:-PT1440M'||c_new_line
  ||'ACTION:DISPLAY'||c_new_line
  ||'DESCRIPTION:Reminder'||c_new_line
  ||'END:VALARM'||c_new_line
  ||'END:VEVENT'||c_new_line
  ||'END:VCALENDAR'||c_new_line;

-- Exceptions --
sql_injection exception;
table_row_modification exception;
invalid_input_value exception;
data_already_exists exception;
data_does_not_exist exception;
not_valid_object_name exception;
not_authorized exception;
PRAGMA EXCEPTION_INIT(sql_injection, -20001);
PRAGMA EXCEPTION_INIT(table_row_modification, -20002);
PRAGMA EXCEPTION_INIT(invalid_input_value, -20003);
PRAGMA EXCEPTION_INIT(data_already_exists, -20004);
PRAGMA EXCEPTION_INIT(data_does_not_exist, -20005);
PRAGMA EXCEPTION_INIT(not_valid_object_name, -20006);
PRAGMA EXCEPTION_INIT(not_authorized, -20007);

-- Logging --
function calculate_error_level(p_error_level in varchar2) return varchar2 deterministic;
procedure log(p_sender in varchar2 default null, p_pkg_version in varchar2 default null, p_proc_version in varchar2 default null, p_message in clob default null, p_error_code in number default null, p_error_level in varchar2 default null);
function log(p_sender in varchar2 default null, p_pkg_version in varchar2 default null, p_proc_version in varchar2 default null, p_message in clob default null, p_error_code in number default null, p_error_level in varchar2 default null) return varchar2;
function get_SQLERRM(p_SQLCODE number) return varchar2 deterministic;
--PRAGMA RESTRICT_REFERENCES(get_SQLERRM , RNDS, RNPS, WNDS, WNPS);
procedure selftest; /*only for development purposes*/
procedure audit_log(p_object varchar2, p_op varchar2, p_privs varchar2);

procedure daily_job;

-- Constants --
function cv (p_constant in varchar2, p_package in varchar2 default 'pcg_payroll_common_good_pkg') return varchar2 deterministic;
function to_iso8601_datetime (p_time timestamp) return varchar2 deterministic;
--PRAGMA RESTRICT_REFERENCES(to_iso8601_datetime , RNDS, RNPS, WNDS, WNPS);

-- Secret Blob --
function read_sec_blob(p_param in varchar2) return varchar2 deterministic;

-- LDAP  --
/* These functions are always working, but very slow and not always found data for every Employee */
/*Changing this ldap as per the latest ldap config update (https://einstein.oracle.com/q/ldap-configuration-change-latest-update-1825)- SR - #66882*/
c_ldap_host constant varchar2(4000) := 'ldappool2.us.oracle.com';/*'ldappool1.us.oracle.com'*/ /*ldap.oracle.com*/
c_ldap_username constant varchar2(4000) := 'cn=PAYROLL-APEX_WW,l=amer,dc=oracle,dc=com';
c_ldap_key varchar2(4000);
c_ldap_search_base constant varchar2(4000) := 'dc=oracle,dc=com';
c_ldap_port constant varchar2(4000) := '636';
c_ldap_use_ssl constant varchar2(4000) := 'A' /*Earlier it was Y, changes as per latest LDAP config update*/;

/*https://confluence.oraclecorp.com/confluence/display/APEXTIPS/Fetching+employee+information+using+APEX_LDAP.SEARCH?focusedCommentId=1966613768#comment-1966613768*/
function email2name (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_manager (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_org (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_title (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_emp_type (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_telephon (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_location (p_email varchar2 default v('APP_USER')) return varchar2 deterministic; -- Deprecated !!!! Do not use it!
function get_city (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_timezone (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_country_code2 (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_cost_center (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_uid (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_all_directs (p_email varchar2 default v('APP_USER')) return varchar2 deterministic;

function is_valid_email (p_email_input in varchar2) return char deterministic;

-- HR Link --
/* These are also slow, but limited number of them are allowed to called at the same number. More accurate probably. */
function employee_number_2_SSO (p_employee_number varchar2, p_business_group_id in number default null, p_attempt_number in number default 1) return varchar2 deterministic;
function sso_2_employee_number (p_sso in varchar2, p_e in char default 'N', p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_country_code2 (p_sso varchar2, p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_city (p_sso varchar2, p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_loc_code (p_sso varchar2, p_attempt_number in number default 1) return varchar2 deterministic;
function get_hire_date(p_sso in varchar2, p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_manager (p_email varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_job (p_email varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_job_level (p_email varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_business_group_id (p_email in varchar2 default v('APP_USER'), p_attempt_number in number default 1) return number deterministic;
function get_hr_bg_country_code2 (p_business_group_id in number, p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_entity_code (p_email in varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic;
function get_hr_entity_name (p_email in varchar2 default v('APP_USER'), p_attempt_number in number default 1) return varchar2 deterministic;

-- OIM roles --
function get_role(p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_other_roles(p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_region(p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function has_role(p_role_name varchar2, p_user varchar2 default v('APP_USER')) return char deterministic;
procedure test_role(p_role_name varchar2, p_user varchar2 default v('APP_USER'));
function has_region(p_region varchar2, p_email varchar2 default v('APP_USER')) return char deterministic;
procedure test_region(p_region varchar2, p_email varchar2 default v('APP_USER'));

-- Table Management --
procedure create_history_for_table (p_tablename varchar2 default null, p_schema varchar2 default sys_context('userenv', 'current_schema'), p_except varchar2 default '(LOAD_TIME)|(LOAD_USER)');
procedure create_auto_id_for_table(p_tablename varchar2 default null, p_schema varchar2 default sys_context('userenv', 'current_schema'), p_id varchar2 default 'ID', p_seq varchar2 default 'PCG_ID_SEQ');
procedure create_auto_audit_for_table(p_tablename varchar2 default null, p_schema varchar2 default sys_context('userenv', 'current_schema'), p_user varchar2 default 'LOAD_USER', p_time varchar2 default 'LOAD_TIME');

procedure update_md_users_v;

function explain_mview(p_view_name in varchar2) return clob;

-- Collection --
function id_string_2_id_list(p_ids varchar2, p_sep char default ',') return PCG_number_LIST deterministic;
function string_2_list(p_serial_list varchar2, p_sep varchar2 default ',') return PCG_string_LIST deterministic;

-- Key-Value --
procedure kv_add(p_key varchar2, p_value varchar2, p_active_sign char default 'Y', p_order number default null);
procedure kv_del(p_key varchar2, p_value varchar2 default null);
procedure kv_del(p_id number);
procedure kv_set(p_key varchar2, p_value varchar2 default null, p_active_sign char default 'Y', p_order number default null);
procedure kv_set(p_id number, p_value varchar2 default null, p_active_sign char default 'Y', p_order number default null);
function kv_get_id(p_key varchar2, p_value varchar2 default null, p_active_sign char default 'Y') return number;
function kv_get_ids(p_key varchar2, p_active_sign char default 'Y', p_separator varchar2 default ',') return clob;
function kv_get_ids_c(p_key varchar2, p_active_sign char default 'Y')  return PCG_string_LIST;
function kv_get_values(p_key varchar2, p_active_sign char default 'Y', p_separator varchar2 default ',') return clob;
function kv_get_values_c(p_key varchar2, p_active_sign char default 'Y') return PCG_string_LIST;

-- Cache --
procedure cache_put_s(p_query_prog_id in number, p_query_param in varchar2, p_value varchar2);
function cache_get_s(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return varchar2;
procedure cache_put_n(p_query_prog_id in number, p_query_param in varchar2, p_value number);
function cache_get_n(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return number;
procedure cache_put_d(p_query_prog_id in number, p_query_param in varchar2, p_value date);
function cache_get_d(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return date;
procedure cache_put_t(p_query_prog_id in number, p_query_param in varchar2, p_value timestamp);
function cache_get_t(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return timestamp;
procedure cache_put_c(p_query_prog_id in number, p_query_param in varchar2, p_value clob);
function cache_get_c(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return clob;
procedure cache_put_b(p_query_prog_id in number, p_query_param in varchar2, p_value blob);
function cache_get_b(p_query_prog_id in number, p_query_param in varchar2, p_date_after date default to_date('2017-01-01','YYYY-MM-DD')) return blob;

procedure cache_forget(p_query_prog_id in number, p_query_param in varchar);

-- Named LOVs --
  -- Adding/Deleting lovs and lov values:
procedure lov_add(p_name in varchar2, p_lov_type in varchar2, p_display_name in varchar2 default null, p_tags in varchar2 default null);
function lov_add(p_name in varchar2, p_lov_type in varchar2, p_display_name in varchar2 default null, p_tags in varchar2 default null) return number;
procedure lov_delete(p_id in number);
procedure lov_force_delete(p_id in number);
procedure lov_add_value(p_lov_id in number, p_lov_value in varchar2, p_display_value in varchar2 default null, p_value_order in number default null, p_tags in varchar2 default null);
function lov_add_value(p_lov_id in number, p_lov_value in varchar2, p_display_value in varchar2 default null, p_value_order in number default null, p_tags in varchar2 default null) return number;
procedure lov_delete_value(p_id in number);
procedure lov_force_delete_value(p_id in number);
  -- cascading add/remove/check
procedure lov_2_lov_link(p_lov_value_id in number, p_casc_lov_id in number);
procedure lov_2_lov_unlink(p_lov_value_id in number, p_casc_lov_id in number);
procedure lov_2_lov_force_unlink(p_lov_value_id in number, p_casc_lov_id in number);
function has_lov_2_lov_link(p_lov_value_id in number, p_casc_lov_id in number) return char;
function has_lov_2_lov_link_d(p_lov_value_id in number, p_casc_lov_id in number) return char;
  -- search by name
function lov_get_id_by_name(p_name in varchar2) return number;
function lov_get_value_id_by_name(p_name in varchar2, p_lov_id in number default null) return number;
  -- get/set attributes
function get_lov_name(p_id number) return varchar2;
function get_lov_display_name(p_id number) return varchar2;
function get_lov_type(p_id number) return varchar2;
function get_lov_tags(p_id number) return varchar2;
function get_lov_value_lov_id(p_id number) return number;
function get_lov_value_name(p_id number) return varchar2;
function get_lov_value_display_name(p_id number) return varchar2;
function get_lov_value_order(p_id number) return number;
function get_lov_value_tags(p_id number) return varchar2;
procedure set_lov_name(p_id number, p_new_value varchar2);
procedure set_lov_display_name(p_id number, p_new_value varchar2);
procedure set_lov_type(p_id number, p_new_value varchar2);
procedure set_lov_tags(p_id number, p_new_value varchar2);
procedure set_lov_value_lov_id(p_id number, p_new_value number);
procedure set_lov_value_name(p_id number, p_new_value varchar2);
procedure set_lov_value_display_name(p_id number, p_new_value varchar2);
procedure set_lov_value_order(p_id number, p_new_value number);
procedure set_lov_value_tags(p_id number, p_new_value varchar2);
  --== LOV Queries ==--
  /* maybe quicker then using the above functions.
  All LOVs:                   select * from MD_LOVS where deleted_sign is null;
  Values associated to a LOV: select * from MD_LOV_VALUES where lov_id = N and deleted_sign is null;
  Directed association:       select l1.*, '-->' con, l2.* from MD_LOVS l1,MD_LOVS l2, MD_LOV_CASCADES c
                                     where l1.id=c.lov_id and l2.id = c.casc_lov_id
                                       and coalesce(l1.deleted_sign, l2.deleted_sign, c.deleted_sign) is null;
  Modifications:              update MD_LOVS set name = '' where id = n;
  */

-- Trees --
function tree_create(p_name in varchar2, p_description in varchar2 default null) return number;
function tree_leaf_create(p_tree_id in number, p_parent_id in number, p_name in varchar2) return number;
procedure tree_delete(p_id in number);
procedure tree_deep_delete(p_id in number);
procedure tree_leaf_delete(p_id in number);
procedure tree_leaf_deep_delete(p_id in number);
procedure tree_leaf_move(p_id in number, p_new_parent_id in number);
procedure tree_leaf_mod_name(p_id in number, p_new_name in varchar2);
procedure tree_mod_name(p_id in number, p_new_name in varchar2);
procedure tree_mod_desc(p_id in number, p_new_description in varchar2);
function is_tree_leaf(p_id in number) return char;
function is_tree_root(p_id in number) return char;
function get_tree_leaf_root(p_id in number) return number;
function get_tree_leaf_parent(p_id in number) return number;
function get_tree_leaf_id(p_leaf_name in varchar2, p_tree_id in number default null) return number;
function tree_leaf_2_path(p_leaf_id in number) return varchar2;
function get_tree_leaf_name(p_id in number, p_tree_id in number default null) return varchar2;
function tree_dup(p_tree_id in number, p_new_name in varchar2, p_new_description in varchar2) return number;
procedure tree_dup(p_tree_id in number, p_new_name in varchar2, p_new_description in varchar2);
procedure tree_leaf_deep_copy(p_in_leaf_id number, p_out_tree_id in number, p_out_root_id in number);
function tree_leaf_deep_copy(p_in_leaf_id number, p_out_tree_id in number, p_out_root_id in number) return number;

-- Mail --
procedure sendmail(
  p_to in varchar2,
  p_app_id in varchar2,
  p_app_name in varchar2,
  p_title in varchar2,
  p_text in varchar2,
  p_attachment in blob default null,
  p_attachment_mime in varchar2 default null,
  p_attachment_filename in varchar2 default null,
  p_status in varchar2 default null
);
function app_url(p_app_id varchar2) return varchar2 deterministic;
function app_url(p_app_id number) return varchar2 deterministic;
function app_url(
  p_app_id number,
  p_page varchar2,
  p_session varchar2,
  p_options varchar2 default null
  ) return varchar2 deterministic;
function app_url_a(
  p_app_id number,
  p_page varchar2,
  p_session varchar2,
  p_display_name varchar2,
  p_options varchar2 default null
  ) return varchar2 deterministic;
function vcalendar(
  p_title in varchar2,
  p_description in varchar2,
  p_location in varchar2,
  p_start in date,
  p_end in date,
  p_email in varchar2 default 'noreply@oracle.com',
  p_uid in varchar2 default null,
  p_CREATION_DATE in date default null
) return varchar2 deterministic;

-- Slack:
function sendslack(p_email in varchar2, p_message in varchar2, p_channel in varchar2 default null) return clob;
procedure sendslack(p_email in varchar2, p_message in varchar2, p_channel in varchar2 default null);
procedure sendslack_err(p_email in varchar2, p_message in varchar2, p_channel in varchar2 default null);

-- Misc --
function get_country_headcount_force(p_country_id in number, p_max_date in date default sysdate) return number;
function get_country_headcount(p_country_id in number) return number;
function timestamp_diff(p_start_time in timestamp, p_end_time in timestamp, p_unit in varchar2 default 'MILISECONDS') return number deterministic;
function get_country_company (p_country_id in number) return varchar2 deterministic;
function get_country_region (p_country_id in number) return varchar2 deterministic;
function get_country_hub (p_country_id in number) return varchar2 deterministic;
function get_country_subregion (p_country_id in number) return varchar2 deterministic;
function get_country_name (p_country_id in number) return varchar2 deterministic;
function get_country_branch (p_country_id in number) return varchar2 deterministic;
function get_country_name_branch (p_country_id in number) return varchar2 deterministic;
function get_country_name_branch_c (p_country_id in number) return varchar2 deterministic;
function get_country_code2 (p_country_id in number) return varchar2 deterministic;
function get_country_code3 (p_country_id in number) return varchar2 deterministic;
function get_country_gpo_team_member (p_country_id in number) return varchar2 deterministic;
function get_country_payroll_analyst (p_country_id in number) return varchar2 deterministic;
function get_country_payroll_manager (p_country_id in number) return varchar2 deterministic;
function get_country_vendor_name (p_country_id in number) return varchar2 deterministic;
function get_country_currency_code3 (p_country_id in number) return varchar2 deterministic;
function get_country_currency_name (p_country_id in number) return varchar2 deterministic;
function is_adp_country (p_country_id in number) return char deterministic;
function get_country_subregion_id (p_sub_region in varchar2) return number deterministic;
function get_country_subregion_id (p_country_id in number) return number deterministic;
function get_country_hub_id (p_hub in varchar2) return number deterministic;
function get_country_hub_id (p_country_id in number) return number deterministic;
function get_country_region_id (p_region in varchar2) return number deterministic;
function get_country_region_id (p_country_id in number) return number deterministic;
function get_country_company_id (p_company in varchar2) return number deterministic;
function get_country_company_id (p_country_id in number) return number deterministic;
function get_hub_id_from_country_code2 (p_cc2 in varchar2) return number deterministic;
function get_country_id_of_entity (p_entity_id in number) return number deterministic;
function get_country_entity_name (p_entity_id in number) return varchar2 deterministic;
function get_country_activity_history (p_country_id in number) return varchar2 deterministic;
function get_reporting_mails (p_mail_id in varchar2) return email_list_type deterministic;

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
, p_match_parameter varchar2 default null) return clob;
--PRAGMA RESTRICT_REFERENCES(decode_regexp_replace , RNDS, RNPS, WNDS, WNPS);

function to_Fiscal_Year(p_date in date) return varchar2 deterministic;
--PRAGMA RESTRICT_REFERENCES(to_Fiscal_Year , RNDS, RNPS, WNDS, WNPS);
function to_Fiscal_Quarter(p_date in date) return varchar2 deterministic;
--PRAGMA RESTRICT_REFERENCES(to_Fiscal_Quarter , RNDS, RNPS, WNDS, WNPS);

FUNCTION blob_to_clob (p_blob_in IN BLOB) RETURN CLOB deterministic;
FUNCTION clob_to_blob (p_clob_in IN CLOB) RETURN BLOB deterministic;

-- Tests --
procedure fill_tablespace;
procedure test_sql_free(p_text varchar2);
function is_sql_free(p_text varchar2) return char deterministic;
--PRAGMA RESTRICT_REFERENCES(is_sql_free , RNDS, RNPS, WNDS, WNPS);
procedure test_valid_object_name(p_name varchar2);
function is_valid_object_name(p_name varchar2) return char deterministic;

function migrate_country_code_2_id (p_country_code varchar2) return number deterministic;

-- test auth function --
function custom_auth (p_username in varchar2, p_password in varchar2) return boolean;
function is_prod_env return char deterministic;

-- HR PaaS --
function get_hr_paas_data(p_email varchar2 default v('APP_USER')) return clob deterministic;
function get_hr_paas_hcm_id(p_data clob) return varchar2 deterministic;
function get_hr_paas_gsi_id(p_data clob) return varchar2 deterministic;
function get_hr_paas_user_type(p_data clob) return varchar2 deterministic;
function get_hr_paas_data_eid(p_employee_number number) return clob deterministic;
function get_hr_paas_data_pid(p_person_id number) return clob deterministic;
function get_region_aria(p_sso varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_hr_paas_cmbnd_data(p_busniess_group_id varchar2) return clob deterministic;
function get_hr_paas_country_data(p_country varchar2) return clob deterministic;
function get_hr_paas_dept_data(p_dept_name varchar2) return clob deterministic;
function get_hr_paas_company_data(p_company_code varchar2) return clob deterministic;

function get_bearer_token return varchar2 deterministic;

procedure set_hr_paas_collection(p_c_name in varchar2, p_data clob, p_app_user varchar2 default v('APP_USER'), p_app_session varchar2 default v('APP_SESSION'));
PROCEDURE fix_temp_entity_folders (
  p_site_id  IN VARCHAR2,
  p_drive_id IN VARCHAR2,
  p_user     IN VARCHAR2 DEFAULT v('APP_USER')
);

end PCG_Payroll_Common_Good_pkg;
/