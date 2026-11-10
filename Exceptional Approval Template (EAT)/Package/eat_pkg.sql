create or replace package EAT_pkg as
--== Constants ==--
c_pkg_name constant varchar2(30 char) := 'EAT_PKG';

c_Test_WS_NAME constant varchar2(30 char):= 'PAYROLL_DEV';
c_Prod_WS_NAME constant varchar2(30 char):= 'PAYROLL_PROD';

c_test_app_id constant varchar2(30 char) := 32162;
c_prod_app_id constant varchar2(30 char) := 22026;

c_WS_NAME varchar2(30 char) := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
c_application_id varchar2(10 char) := v('APP_ID');

c_app_name constant varchar2(100 char) := 'Exceptional Approval Template';

c_space varchar2(10 char) := '%20'; /* WhiteSpace */
c_user varchar2(1000) := 'payroll-apex_ww@oracle.com';
c_tenant varchar2(1000) := '4e2c6054-71cb-48f1-bd6c-3a9705aca71b';

c_msg_for_review_act constant varchar2(4000 char) := '<p style="color: red;"> Action Required </p> Exceptional approval request has been <strong>submitted</strong> for your review.';
c_msg_for_escalate_review_act constant varchar2(4000 char) := '<p style="color: red;"> Action Required </p> Exceptional approval request has been <strong>escalated</strong> for your review.';
c_msg_approved_note constant varchar2(4000 char) := 'Exceptional approval request has been <strong>approved</strong>';
c_msg_submitted_note constant varchar2(4000 char) := 'Your exceptional approval request has been <strong>submitted</strong> for approval.';
c_msg_rejected_note constant varchar2(4000 char) := 'Exceptional approval request has been <strong>rejected</strong>. See comments bellow.';
c_msg_escalate_above_note constant varchar2(4000 char) := 'Exceptional approval request has been <strong>escalated</strong> to your manager.';
c_msg_escalate_note constant varchar2(4000 char) := 'Exceptional approval request has been <strong>escalated</strong>.';

c_max_mgr_level constant number := 6;
c_max_spec_mgr_level constant number := 2;

c_ADP_Global_Addon_email constant varchar2(256 char) := 'globaladdon_ro@oracle.com';
c_apex_mail constant varchar2(256 char) := 'payroll-apex_ww@oracle.com';

--== SUBROUTINES ==--
procedure delete_attachment(p_id number);
procedure add_attachment(p_request_id number);
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
);

procedure submit_request(p_id number, p_requester in varchar2 default v('APP_USER'));
procedure approve_request(p_id number, p_approver in varchar2 default v('APP_USER'));
procedure reject_request(p_id number, p_approver in varchar2 default v('APP_USER'));
procedure escalate_request(p_id number, p_requester in varchar2 default v('APP_USER'));

function link2request(p_id number) return varchar2 deterministic;
function get_m_level(p_email varchar2) return number deterministic;
function get_requester_email(p_id number) return varchar2 deterministic;
function get_manager_email(p_employee_email varchar2) return varchar2 deterministic;

function is_editable(p_request_id number, p_requester in varchar2 default v('APP_USER')) return char;
function is_approvable(p_request_id number, p_approver in varchar2 default v('APP_USER')) return char;
function is_escalatable(p_request_id number, p_requester in varchar2 default v('APP_USER')) return char;

function has_Page_Access(p_user in varchar2 default v('APP_USER')) return char deterministic;
procedure test_Page_Access(p_user in varchar2 default v('APP_USER'));

function get_role(p_email varchar2 default v('APP_USER')) return varchar2 deterministic;
function get_region(p_email varchar2 default v('APP_USER')) return varchar2 deterministic;

function is_Manager(p_user in varchar2 default v('APP_USER')) return char deterministic;
procedure test_Manager(p_user in varchar2 default v('APP_USER'));

procedure test_request_openable(p_user in varchar2 default v('APP_USER'), p_request_id in number default null);

procedure sendmail(p_to varchar2, p_app_id varchar2, p_app_name varchar2, p_title varchar2, p_text varchar2);

function request_2_html(p_request_id in number) return varchar2;
function buttons(p_request_id in number, p_email in varchar2) return varchar2;
function security_number(p_request_id in number, p_email in varchar2) return varchar2 deterministic;

procedure read_mails;

end EAT_pkg;
/