create or replace package "AUD_PKG" as

--== Constants ==--
c_Prod_Workspace_Name constant varchar2(30) := 'PAYROLL_PROD' ;
c_Prod_Application_ID constant varchar2(10) := 14163;

c_Workspace_Name constant varchar2(30) := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
c_Application_ID constant varchar2(10) := v('APP_ID');
c_Application_Name constant varchar2(100) := 'Audit';

c_pkg_spec_version constant varchar2(5 char) := '1.2';
c_admin varchar2(64) := 'milagro.valverde@oracle.com' ; 

c_space varchar2(10 char) := '%20'; /* WhiteSpace */
c_user varchar2(1000) := 'payroll-apex_ww@oracle.com';
c_tenant varchar2(1000) := '4e2c6054-71cb-48f1-bd6c-3a9705aca71b';
c_wip varchar2(32) := 'WIP';
c_sent_to_director varchar2(32) := 'Sent to Director' ;
c_verified_by_director varchar2(32) := 'Verified by Director' ; 

procedure send_mail_to_director (
    p_year in number  , 
    p_quarter in varchar2 
   
) ;
procedure send_mail_to_admin (
    p_year in number  , 
    p_quarter in varchar2 ,
    p_director_id in  number 
   
) ;

procedure read_mails;
procedure upload_user_roles_apex (
    p_year in number  , 
    p_quarter in varchar2 , 
    p_type_id in number
) ;

procedure upload_user_roles_osvc (
    p_year in number  , 
    p_quarter in varchar2 , 
    p_type_id in number
) ;

procedure upload_user_roles_ivacation (
    p_year in number  , 
    p_quarter in varchar2 , 
    p_type_id in number
) ;


function is_reset_director (
    p_year in number  , 
    p_quarter in varchar2 , 
    p_type_id in number
) return char ;

procedure update_web_template (
    p_web_template_html IN CLOB,
    p_template_id IN NUMBER
) ;
function get_director_id (p_emp_email IN VARCHAR2) return number;
 
function is_admin_access(p_user in varchar2 default v('APP_USER')) return char deterministic;
function is_admin_access(
    p_year    in number,
    p_quarter in varchar2,
    p_user    in varchar2 default v('APP_USER')) return char deterministic;
function columns_access(p_type_id IN NUMBER, p_column in varchar2) return BOOLEAN;

function is_director_access(p_user in varchar2 default v('APP_USER')) return char deterministic;
function is_user_access(p_user in varchar2 default v('APP_USER')) return char deterministic;
FUNCTION get_or_create_id_for_director(p_email IN VARCHAR2 ) RETURN NUMBER ;
function report(
    p_year in number  , 
    p_quarter in varchar2,
    p_type number ,
    p_user in varchar2
    ) return varchar2 ; 

procedure map_new_user_update_director_all (
    p_year in number  , 
    p_quarter in varchar2,
    p_type_id in number ,
    p_type_id_global in number 
) ;

procedure update_director_all (
    p_year in number  , 
    p_quarter in varchar2,
    p_type_id in number ,
    p_type_id_global in number 
) ;

procedure update_director_all (
    p_year in number  , 
    p_quarter in varchar2,
    p_type_id in number ,
    p_type_id_global in number ,
    p_user_name IN VARCHAR2
) ;

PROCEDURE AUD_INSERT(
  p_file_name IN VARCHAR2
) ;


procedure BUILD_EMAIL(p_to in varchar2,
  p_app_id in varchar2,
  p_app_name in varchar2,
  p_year in number,
  p_quarter in varchar2,
  p_title in varchar2,
  p_text in varchar2
  ) ;

end "AUD_PKG";
/