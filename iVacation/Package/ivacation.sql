create or replace PACKAGE "IVACATION" as
--'IVACATION'
-- Constants --
c_YES constant char := 'Y';
c_NO constant char := 'N';
c_DB_NAME varchar2(4000 char) := lower(ORA_DATABASE_NAME());
c_WS_NAME varchar2(4000 char) := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID'));
c_WS_ID varchar2(4000 char) := v('WORKSPACE_ID');

c_APP_ID varchar2(50 char) := 2449 ; ---v('APP_ID'); Rohit added App id - 2449 since it is being use in JOBs too
c_default_mail_list varchar2(4000 char) := 'rohit.bq.kumar@oracle.com' ;
---'bhuvi.chauhan@oracle.com,anupam.ankesh@oracle.com,rohit.bq.kumar@oracle.com,marek.szwarczewski@oracle.com'
  DEFAULT_DATE constant date := to_date('01-Jan-1900','dd-Mon-yyyy');
  C_EML_FROM   constant varchar2(100) := 'iVacation <ivacation_noReply@oracle.com>';
  C_VACATION      CONSTANT varchar2(8) := 'VACATION';
  C_SICK_LEAVE    CONSTANT varchar2(10) := 'SICK_LEAVE';
  C_OOH           CONSTANT varchar2(3)  := 'OOH';
    procedure GET_BEGIN_END_DATES(
      P_EMP_EMAIL             in  AA_EMPLOYEES.EMP_EMAIL%type
     ,P_DATE                  in  AA_OVERVIEW.MONTH%type
     ,P_AA_COUNTRY_VP_INT_ID  in  AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type
     ,P_BEGIN_DATE            out AA_OVERVIEW.MONTH%type
     ,P_END_DATE              out AA_OVERVIEW.MONTH%type
    );
  function CONSTRUCT_LINK(P_PAGE_ID varchar2, P_CHECKSUM varchar2 default null, P_REQUEST varchar2 default null, P_SET_ARGS varchar2 default null)
    return varchar2;
  procedure NEW_STATUS (P_STATUS_TYPE varchar);
  function EXIST_VAC_PERIOD(P_EMP_EMAIL varchar2
                         ,P_LEAVE_START date
                         ,P_LEAVE_END date)
    return boolean;
  procedure NEW_REQUEST(P_EMAIL_TO varchar2
                       ,P_EMAIL_CC varchar2
                       ,P_EMAIL_BCC varchar2
                       ,P_NO_WORK_DAYS_LEAVE number
                       ,P_LEAVE_START date
                       ,P_LEAVE_END date
                       ,P_AA_COUNTRY_VP_INT_ID number
                       ,P_EMP_EMAIL varchar2 default null
                       ,P_EMP_COMMENTS varchar2 default null);
    procedure NEW_REQUEST_temp(P_EMAIL_TO varchar2
                       ,P_EMAIL_CC varchar2
                       ,P_EMAIL_BCC varchar2
                       ,P_NO_WORK_DAYS_LEAVE number
                       ,P_LEAVE_START date
                       ,P_LEAVE_END date
                       ,P_AA_COUNTRY_VP_INT_ID number
                       ,P_EMP_EMAIL varchar2 default null
                       ,P_EMP_COMMENTS varchar2 default null);
  procedure APPROVE_REQUEST(P_REQUEST_ID number);
    procedure APPROVE_REQUEST_TEMP(P_REQUEST_ID number);
  procedure CLEAR_APPROVAL(P_REQUEST_ID number);
  procedure REJECT_REQUEST(P_REQUEST_ID number, P_COMMENTS varchar2, P_STATUS_ID number);
  function HAS_ACCESS_VAC(P_REQUEST_ID number)
    return BOOLEAN;
  function IS_APPROVER
    return BOOLEAN;
  function is_approver(P_COUNTRY_ID number)
    return BOOLEAN;
  function IS_LOCAL_HR
    return boolean;
  function IS_LOCAL_HR(P_COUNTRY_ID number)
    return BOOLEAN;
  function IS_APPROVER(P_COUNTRY_ID number, P_DUMMY number)
    return number;
  function IS_LOCAL_HR(P_COUNTRY_ID number, P_DUMMY number)
    return number;
  function IS_PAYROLL
    return boolean;
  function IS_PAYROLL(P_COUNTRY_ID number)
    return BOOLEAN;
  function IS_PAYROLL(P_COUNTRY_ID number, P_DUMMY number)
    return number;
  procedure new_local_hr_rep (p_email varchar);
  procedure CREATE_EMP(
    P_EMP_NUMBER                    AA_EMPLOYEES.EMP_NUMBER%type
   ,P_EMP_NAME                      AA_EMPLOYEES.EMP_NAME%type
   ,P_EMP_EMAIL                     AA_EMPLOYEES.EMP_EMAIL%type
   ,P_START_DATE                    AA_EMPLOYEES.START_DATE%type
   ,P_COUNTRY_ID                    AA_EMPLOYEES.AA_COUNTRY_ID%type
   ,P_COST_CENTER                   AA_EMPLOYEES.COST_CENTER%type
   ,P_MANAGER                       AA_EMPLOYEES.EMP_MANAGER%type
   ,P_LEVAE_BALANCE                 AA_EMPLOYEES.STARTING_VAC_BALANCE%type default 0
   ,P_LAST_YEAR_LEAVE_BALANCE       AA_EMPLOYEES.STARTING_VAC_BALANCE%type default 0
   ,P_TENURE_BEFORE_ORACLE_MONTHS   AA_EMPLOYEES.TENURE_BEFORE_ORACLE_MONTHS%type default 0
  );
  procedure ADD_EMP_START_MONTHS(
    P_EMP_EMAIL                 AA_EMPLOYEES.EMP_EMAIL%type
   ,P_START_DATE                AA_EMPLOYEES.START_DATE%type
   ,P_LEAVE_BALANCE             AA_OVERVIEW.LEAVE_BALANCE%type default 0
   ,P_LAST_YEAR_LEAVE_BALANCE   AA_EMPLOYEES.STARTING_VAC_BALANCE%type default 0
  );
  procedure ADD_EMP (
    P_EMP_NUMBER                    AA_EMPLOYEES.EMP_NUMBER%type
   ,P_EMP_NAME                      AA_EMPLOYEES.EMP_NAME%type
   ,P_EMP_EMAIL                     AA_EMPLOYEES.EMP_EMAIL%type
   ,P_START_DATE                    AA_EMPLOYEES.START_DATE%type
   ,P_COUNTRY_ID                    AA_EMPLOYEES.AA_COUNTRY_ID%type
   ,P_COST_CENTER                   AA_EMPLOYEES.COST_CENTER%type
   ,P_MANAGER                       AA_EMPLOYEES.EMP_MANAGER%type
   ,P_LEVAE_BALANCE                 AA_EMPLOYEES.STARTING_VAC_BALANCE%type default 0
   ,P_LAST_YEAR_LEAVE_BALANCE       AA_EMPLOYEES.STARTING_VAC_BALANCE%type default 0
   ,P_TENURE_BEFORE_ORACLE_MONTHS   AA_EMPLOYEES.TENURE_BEFORE_ORACLE_MONTHS%type default 0
  );
  procedure UPDATE_EMP_EMAIL_TRIGGER(P_OLD_EMAIL varchar2, P_NEW_EMAIL varchar2);
  procedure UPDATE_MNG_EMAIL_TRIGGER(P_EMP_EMAIL varchar2, P_NEW_EMAIL varchar2);
  procedure inactivate_emp (p_employee_id number, p_end_date date);
  function get_amount_to_add(p_aa_overview_id number, p_new_leave_balance number)
    return number;
  function GET_EMP_LEAVE_BALANCE(P_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number)
    return number;
  function GET_EMP_LEAVE_BALANCE(P_EMAIL varchar2, P_MONTH date, P_AA_REQUEST_ID number)
    return number;
  function COUNT_PREVIOUS_WA_REQUESTS(P_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number)
    return number;
  function GET_EMP_RATE_PER_MONTH(P_EMAIL varchar2, P_AA_COUNTRY_VP_INT_ID number, P_DATE date default null)
    return number;
  -- function GET_TERMINATION_REDO_BALANCE(
  --   P_EMP_EMAIL AA_EMPLOYEES.EMP_EMAIL%type
  --  ,P_DATE      AA_OVERVIEW.month%type
  -- )
  -- return date;
  function GET_PREV_LEAVE_BALANCE(
    P_EMP_EMAIL             AA_OVERVIEW.EMP_EMAIL%type
   ,P_AA_COUNTRY_VP_INT_ID  AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type
  )
  return AA_OVERVIEW.LEAVE_BALANCE%type;
  function GET_PREV_AA_COUNTRY_VP_INT_ID(
    P_EMP_EMAIL             AA_OVERVIEW.EMP_EMAIL%type
   ,P_AA_COUNTRY_VP_INT_ID  AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type
  )
  return AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type;
  procedure REDO_BALANCE_ALL(P_EMAIL varchar2, P_MONTH date);
  procedure REDO_BALANCE(P_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number default null);
  procedure NEW_MONTH(P_EMAIL varchar2,
                       P_MONTH date,
                       P_ACCRUED number default 0,
                       P_LEAVE_TAKEN number default 0,
                       P_AMOUNT_ADDED number default null,
                       P_LAST_YEAR_LEAVE_BALANCE number default 0);
  procedure UPDATE_LEAVE_BALANCE(P_REQUEST_ID number, P_WHO varchar2);
  procedure update_leave_balance(p_request_id number, p_who varchar2, P_NEW_BALANCE out number);
  procedure DELETE_EMP(P_EMAIL varchar2);
  function EXIST_EMP_OVERVIEW_MONTH(P_EMP_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number)
    return boolean;
  function GET_COUNTRY_ADMIN(P_COUNTRY_ID number)
    return varchar2;
  function GET_COUNTRY_ADMIN_EML(P_COUNTRY_ID number)
    return varchar2;
  function GET_EMAIL_CC(P_COUNTRY_ID number)
    return varchar2;
  function GET_EMAIL_CC_APPROVED(P_COUNTRY_ID number)
    return varchar2;
  function GET_USER_COUNTRY_ID(P_EMAIL varchar2)
    return number;
  procedure UPDATE_EMP_INFO;
  procedure UPDATE_EMP_INFO(
    P_EMP_EMAIL AA_EMPLOYEES.EMP_EMAIL%type
  );
  procedure SEND_MNG_NO_ACTION_EML_4JOB;
  procedure UPDATE_EMP_INFO_4JOB;
  procedure ADD_MONTH_4JOB;
  procedure SEND_EMPS_NO_MANAGER_EML ;
  procedure GET_EMPS_NO_MANAGER_EML(P_COUNTRIES varchar2 
                                 ,P_EML_HTML OUT clob 
                                 ,P_EML_TEXT OUT clob) ;


  procedure PROCESS_EMPS_NO_MANAGER(P_COUNTRIES   varchar2, P_EML_HTML in OUT clob, P_EML_TEXT in OUT clob) ;
  procedure SEND_EMP_MONTHLY_REV_EML(P_DATE date default localtimestamp);
--  procedure SEND_EMP_MONTHLY_REV_EML(P_EMP_EMAIL varchar2, P_DATE date default localtimestamp);  
  procedure SEND_MNG_MONTHLY_REV_EML(P_DATE date default localtimestamp);
--  procedure SEND_MNG_MONTHLY_REV_EML(P_MGR_EMAIL varchar2, P_DATE date default localtimestamp);    
  procedure JURNALIZE_EMP(P_EMP_EMAIL varchar2, P_WHO varchar2 default null);
  procedure CHANGE_EMPLOYEE_COUNTRY(P_EMP_EMAIL               varchar2
                                   ,P_EMP_NUMBER              varchar2
                                   ,P_EMP_NAME                varchar2
                                   ,P_START_DATE              date
                                   ,P_COUNTRY_ID              number
                                   ,P_COST_CENTER             varchar2
                                   ,P_MANAGER                 varchar2
                                   ,P_LEVAE_BALANCE           number default 0
                                   ,P_LAST_YEAR_LEAVE_BALANCE number default 0);
  procedure ASSOCIATE_EVENT_TO_COUNTRY(P_AA_COUNTRY_ID          number
                                      ,P_AA_EVENT_TYPE_ID       number
                                      ,P_AA_UNIT_OF_MEASURE_ID  number);
  function IS_ELIG_SUSPEND_ASSIG(P_EMP_EMAIL varchar2)
    return boolean;
  function EXIST_SUSPEND_PERIOD(P_EMP_EMAIL   varchar2
                               ,P_START_DATE  date default null
                               ,P_END_DATE    date default null)
    return boolean;
  procedure PROCESS_SUSPEND_ASSIG(P_EMP_ID      number
                                 ,P_START_DATE  date default null
                                 ,P_END_DATE    date default null);
  procedure DELETE_SUSPEND_ASSIG(P_EMP_ID      number
                                ,P_START_DATE  date default null
                                ,P_END_DATE    date default null) ;
  procedure PRINT_EMP_BALANCE(P_EMP_EMAIL varchar2, P_COUNTRY_ID number);
  function GET_EMP_LEAVE_TYPES(P_EMP_EMAIL varchar2)
    return varchar2;
  function HAS_SICK_LEAVE_ELIG(P_EMP_EMAIL varchar2)
    return BOOLEAN;
  function HAS_OOH_ELIG_MNG(P_EMP_EMAIL varchar2)
    return BOOLEAN;
  function HAS_OOH_ELIG(P_EMP_EMAIL varchar2)
    return BOOLEAN;
  procedure PRINT_PORTAL(P_EMP_EMAIL varchar2);
  function GET_STATUS_LIST(P_REQUEST_ID number, P_EMP_EMAIL varchar2, P_QUERY number)
    return varchar2;
  procedure PROCESS_REQUEST(
    P_EMP_EMAIL varchar2
   ,P_REQUEST_ID varchar2
   ,P_STATUS_ID number
   ,P_DAYS_LEAVE number default null
   ,P_LEAVE_START date default null
   ,P_LEAVE_END date default null
   ,P_COMMENTS  varchar2 default null
  );

    procedure PROCESS_REQUEST_TEMP(
    P_EMP_EMAIL varchar2
   ,P_REQUEST_ID varchar2
   ,P_STATUS_ID number
   ,P_DAYS_LEAVE number default null
   ,P_LEAVE_START date default null
   ,P_LEAVE_END date default null
   ,P_COMMENTS  varchar2 default null
  );


  procedure NEW_REQUEST_NO_MAIL(
    P_EMAIL_TO varchar2
   ,P_NO_WORK_DAYS_LEAVE number
   ,P_LEAVE_START date
   ,P_LEAVE_END date
   ,P_AA_COUNTRY_VP_INT_ID number
   ,P_EMP_EMAIL varchar2 default null
   ,P_EMP_COMMENTS varchar2 default null
   ,P_REQUEST_ID out number
  );
  procedure APPROVE_REQUEST_NO_MAIL(P_REQUEST_ID number);
  
  procedure NEW_APPROVED_REQUEST_NO_MAIL(
    P_EMAIL_TO varchar2
   ,P_NO_WORK_DAYS_LEAVE number
   ,P_LEAVE_START date
   ,P_LEAVE_END date
   ,P_AA_COUNTRY_VP_INT_ID number
   ,P_EMP_EMAIL varchar2 default null
  );
  procedure JNL_MONTHS_AFTER_END(P_EMP_EMAIL  varchar2);
  
  procedure PROCESS_REQUESTS 
    (P_AA_COUNTRY_ID         aa_countries.aa_country_id%type
    ,P_FILE_NAME             varchar2
    ,P_APPROVED              number);
 
   procedure SUBMIT_REQUESTS 
    (P_AA_COUNTRY_ID         aa_countries.aa_country_id%type
    ,P_SUBMITTED_BY          varchar2); 
   procedure VALIDATE_BULK_REQUESTS 
    (P_AA_COUNTRY_ID       aa_requests_tmp.aa_country_id%type);

    FUNCTION get_country_id(role_name in VARCHAR2) RETURN NUMBER ; 
    procedure update_AA_USER_CT_ROLE_INT ; 
------------------------Morocco disable
------------Rohit added 18th Sep 2025
function is_country_allowed(p_emp_email in varchar2)
    return BOOLEAN;
    

procedure update_aa_oim_intg_users_and_roles;
 
end;
/