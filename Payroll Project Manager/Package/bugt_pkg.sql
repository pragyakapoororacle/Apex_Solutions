create or replace package BUGT_pkg as
--== Constants ==--
c_pkg_name constant varchar2(30 char) := 'BUGT_PKG';
c_pkg_version number;

c_APEX_LINK constant varchar2(256 char) := APEX_MAIL.GET_INSTANCE_URL;
--'https://apex'||trim(case when pcg.is_prod_env = 'Y' then null else '-stage' end)||'.oraclecorp.com/pls/apex/';

c_Test_WS_NAME constant varchar2(30 char):= 'PAYROLL_DEV';
c_Prod_WS_NAME constant varchar2(30 char):= 'PAYROLL_PROD';

c_test_application_id constant varchar2(10 char) := '26631';
c_prod_application_id constant varchar2(10 char) := '31635';

c_start_page constant varchar2(10 char) := '100';

c_TEST_USERS constant varchar2(4000 char) := 'rohit.bq.kumar@oracle.com MAREK.SZWARCZEWSKI@ORACLE.COM';

function c_INNO_SLACK_CHANNEL return varchar2 deterministic;
PRAGMA RESTRICT_REFERENCES(c_INNO_SLACK_CHANNEL, RNDS, RNPS, WNDS, WNPS);

c_WS_NAME constant varchar2(4000 char) := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
c_application_id constant varchar2(4000 char) := v('APP_ID');

c_new_line constant varchar2(2 char) := CHR(10)||CHR(13);
c_YES constant char := 'Y';
c_NO constant char := 'N';
c_32k constant number := 32672;

c_application_name varchar2(100 char) := 'Payroll Service Request'||case when c_application_id != c_prod_application_id then ' TEST' end;

c_status_new constant varchar2(100 char) := 'New';
c_status_submitted constant varchar2(100 char) := 'Submitted';
c_status_manager_approved constant varchar2(100 char) := 'Approved by Manager';
c_status_gpo_approved constant varchar2(100 char) := 'Approved by GPO';
c_status_director_approved constant varchar2(100 char) := 'Approved by Director'; /* DIRECTOR = Senior Systems Project Manager */
c_status_director_rejected constant varchar2(100 char) := 'Rejected by Director';
c_status_permanently_rejected constant varchar2(100 char) := 'Permanently Rejected';
c_status_manager_rejected constant varchar2(100 char) := 'Rejected by Manager';
c_status_gpo_rejected constant varchar2(100 char) := 'Rejected by GPO';

c_PPM_approved constant varchar2(20 char) := 'APPROVED';
c_PPM_rejected constant varchar2(20 char) := 'REJECTED';

--== SUBROUTINES ==--
-- administration
FUNCTION cvv (p_constant IN VARCHAR2) RETURN varchar2 deterministic;
FUNCTION cvn (p_constant IN VARCHAR2) RETURN number deterministic;
-- safety
procedure user_warn_check(p_user in varchar2);
function is_valid_bug(p_id number) return char;
procedure test_valid_bug(p_id number);

function is_payroll_org_member(p_email varchar2) return char deterministic;
function is_analyst(p_email varchar2, p_region varchar2 default null) return char deterministic;
function is_director(p_email varchar2) return char deterministic;
function is_manager(p_email varchar2, p_region varchar2 default null) return char deterministic;
function is_team_member(p_email varchar2) return char deterministic;
function is_admin(p_email varchar2) return char deterministic;
function is_MA_Manager(p_email varchar2) return char deterministic;
function is_MA_Analyst(p_email varchar2) return char deterministic;
function is_OP_Manager(p_email varchar2) return char deterministic;
function is_OP_Analyst(p_email varchar2) return char deterministic;
function is_BTS(p_email varchar2) return char deterministic;
function is_SME(p_email varchar2, p_region varchar2 default null) return char deterministic;

procedure test_payroll_org_member(p_email varchar2);
procedure test_analyst(p_email varchar2, p_region varchar2 default null);
procedure test_director(p_email varchar2);
procedure test_manager(p_email varchar2, p_region varchar2 default null);
procedure test_team_member(p_email varchar2);
procedure test_admin(p_email varchar2);
procedure test_MA_analyst(p_email varchar2);
procedure test_MA_manager(p_email varchar2);
procedure test_OP_analyst(p_email varchar2);
procedure test_OP_manager(p_email varchar2);
procedure test_BTS(p_email varchar2);
procedure test_SME(p_email varchar2, p_region varchar2 default null);

function is_editable (p_id number, p_email varchar2 default v('APP_USER')) return char;
procedure test_editable (p_id number, p_email varchar2 default v('APP_USER'));

function is_submissible (p_id number, p_email varchar2 default v('APP_USER')) return char;
procedure test_submissible (p_id number, p_email varchar2 default v('APP_USER'));

function is_deletable (p_id number, p_email varchar2 default v('APP_USER')) return char;
procedure test_deletable (p_id number, p_email varchar2 default v('APP_USER'));

function is_approvable (p_id number, p_email varchar2 default v('APP_USER')) return char;
procedure test_approvable (p_id number, p_email varchar2 default v('APP_USER'));

function is_reject_commentable (p_id number, p_email varchar2 default v('APP_USER')) return char;
procedure test_reject_commentable (p_id number, p_email varchar2 default v('APP_USER'));

function is_viewable (p_id in number, p_email in varchar2 default v('APP_USER')) return char;
procedure test_viewable (p_id in number, p_email in varchar2 default v('APP_USER'));

function is_likeable (p_id in number, p_email in varchar2 default v('APP_USER')) return char;
procedure test_likeable (p_id in number, p_email in varchar2 default v('APP_USER'));

function is_User_commentable (p_id in number, p_email in varchar2 default v('APP_USER'), p_project_id in number default null) return char;
procedure test_User_commentable (p_id in number, p_email in varchar2 default v('APP_USER'), p_project_id in number default null);

function is_file_required_and_attached (p_id in number, p_issue_type_id in number) return char;

-- misc
function get_user_id(p_email varchar2) return number deterministic;
function get_email(p_id number) return varchar2 deterministic;
function get_op_manager_team_member_id return number deterministic;
function status_name_2_status_id(p_status_name varchar2) return number deterministic;
function status_id_2_status_name(p_status_id number) return varchar2 deterministic;
function country_id_2_country_name(p_id number) return varchar2 deterministic;
function country_ids_2_country_names(p_ids varchar2) return varchar2 deterministic;
function get_bug_history(p_bug_id in number) return varchar2 deterministic;
function spaces(p_level in number) return varchar2 deterministic;
function comment_text(p_level in number, p_comment_text in varchar2) return varchar2 deterministic;
function get_bug_sum_likes_and_dislikes(p_bug_id in number) return number deterministic;
function get_region_count(p_email varchar2) return number deterministic;

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
);

procedure ret_email_msg (p_id_text varchar2, po_title out varchar2, po_message_text out varchar2);
procedure sendmail(p_email varchar2, p_title varchar2, p_text varchar2, p_user varchar2 default v('APP_USER'),p_region varchar2 default v('G_USER_REGION'));
procedure sendslack(p_email in varchar2, p_msg in varchar2, p_channel in varchar2 default null);

function get_requester(p_bug_id number) return varchar2 deterministic;
function get_manager(p_bug_id number) return varchar2 deterministic;

-- business
function get_country_ids(p_bug_id number) return varchar2;
function get_team_member_id(p_bug_id number) return number deterministic;
function get_bug_issue_type_id(p_bug_id number) return number deterministic;
function get_bug_system_id(p_bug_id number) return number deterministic;
function get_bug_region(p_bug_id number) return varchar2 deterministic;
function get_region(p_country_id number) return varchar2 deterministic;
function get_managers(p_region varchar2 default null) return PCG_number_LIST deterministic;
function get_user_region(p_id number, p_role varchar2 default 'MANAGER ANALYST' ) return varchar2 deterministic;
function get_BTS_country_id(p_country_id in number) return number deterministic;
function get_bug_hierarchy_country_id(p_id in number, p_country_ids in varchar2 default null) return MD_COUNTRIES%ROWTYPE deterministic;
function get_bug_BTSes(p_id in number, p_country_ids in varchar2 default null) return PCG_string_LIST deterministic;
function get_HUB_Leaders return PCG_string_LIST deterministic;

function get_score(p_id number) return number deterministic;
function get_severity_id(p_id number) return number deterministic;
function get_severity_name(p_id number) return varchar2 deterministic;

function is_qrc(p_bug_id in number) return char;
function is_qrc_issue_type(p_type_id in number) return char;

function get_project_tracker_link(p_id number, p_dummy varchar2 default null) return varchar2 deterministic;
function get_project_tracker_link_a(p_id number) return varchar2 deterministic;

function get_status (p_bug_id number) return number;

function get_bug_link_A (p_bug_id number,p_region varchar2 default v('G_USER_REGION')) return varchar2 deterministic;
function get_bug_link (p_bug_id number,p_region varchar2 default v('G_USER_REGION')) return varchar2 deterministic;

function get_team_member_id_byc(p_country_ids in varchar2, p_system_id in number, p_issue_type_id in number) return number deterministic;
function c_issue_type_id__inno return number deterministic;
function c_issue_type_id__gpo_process return number deterministic;
function c_issue_type_id__M_and_A return number deterministic;
function c_system_id__gpo_webpage return number deterministic;
function sr_category_name(p_issue_type_id in number) return varchar2 deterministic;

procedure mod_bug(p_id in out number, p_manager_email varchar2,p_system_id number,p_issue_type_id number,p_issue_subject varchar2,p_issue_description clob,
  p_roles_used varchar2,p_workaround_sign char,p_workaround_details varchar2,p_workaround_hour_id number,p_headcount_id number,p_legally_required_sign char,
  p_after_workaround_hour_id number,p_legislated_change_date date,p_required_by_date date, p_regions varchar2, p_status_id number, p_eee_sign char,  p_ee_pt_imp_sign char, p_hr_plcy_sign char, p_comments varchar2 default null,
  p_inno_type_id in number default null, p_inno_contributors in varchar2 default null, p_email varchar2 default v('APP_USER'));

procedure submit_bug(p_id number, p_email varchar2 default v('APP_USER'));
procedure del_bug(p_id number, p_email varchar2 default v('APP_USER'));
procedure approve_bug(p_id number, p_email varchar2 default v('APP_USER'));
procedure reject_bug(p_id number,p_reason varchar2, p_email varchar2 default v('APP_USER'));
procedure copy_2_Project_tracker (p_id number, p_with_status in varchar2, p_email varchar2 default v('APP_USER'));
procedure comment_reject_bug (p_id number,p_reason varchar2, p_email varchar2 default v('APP_USER'));
procedure user_comment_bug (p_id in number, comment_text in varchar2, reply_to_id in number, p_email varchar2 default v('APP_USER'), p_project_id in number default null);
procedure like_inno_bug (p_id in number, p_email varchar2 default v('APP_USER'));
procedure dislike_inno_bug (p_id in number, p_email varchar2 default v('APP_USER'));
procedure clearlike_inno_bug (p_id in number, p_email varchar2 default v('APP_USER'));

function custom_test_auth (p_username in varchar2, p_password in varchar2) return boolean;

  FUNCTION sr_key (p_sr_id NUMBER,p_project_id NUMBER) RETURN VARCHAR2;
  -- Upload (insert new attachment[s])
  PROCEDURE att_upload_sp (
    p_sr_id             IN NUMBER,
    p_project_id        IN NUMBER,
    p_title             IN VARCHAR2,
    p_comments          IN VARCHAR2,
    p_att_selector      IN VARCHAR2,   -- colon-separated APEX temp names
    p_site_id           IN VARCHAR2,   -- :G_SP_SITE_ID
    p_drive_id          IN VARCHAR2,   -- :G_SP_DRIVE_ID
    p_user              IN VARCHAR2 DEFAULT v('APP_USER')
  );

  -- Update (metadata only if selector is NULL; else replace the file)
  PROCEDURE att_update_sp (
    p_file_id           IN NUMBER,
    p_sr_id             IN NUMBER,
    p_project_id        IN NUMBER,
    p_title             IN VARCHAR2,
    p_comments          IN VARCHAR2,
    p_att_selector      IN VARCHAR2,   -- NULL = metadata only; else replace
    p_site_id           IN VARCHAR2,
    p_drive_id          IN VARCHAR2,
    p_user              IN VARCHAR2 DEFAULT v('APP_USER')
  );

  -- Delete (SharePoint + DB)
  PROCEDURE att_delete_sp (
    p_file_id IN NUMBER,
    p_user    IN VARCHAR2 DEFAULT v('APP_USER')
  );

  -- Download (SharePoint first, legacy BLOB fallback)
  PROCEDURE att_download_sp (
    p_file_id IN NUMBER
  );

  PROCEDURE migrate_ppm_files_to_sp (
  p_site_id     IN VARCHAR2,
  p_drive_id    IN VARCHAR2,
  p_user        IN VARCHAR2 DEFAULT v('APP_USER'),
  p_limit       IN PLS_INTEGER DEFAULT 50,         -- batch size
  p_clear_blob  IN BOOLEAN    DEFAULT FALSE        -- FALSE = safe mode (keep legacy BLOBs)
);

end BUGT_pkg;
/