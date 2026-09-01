create or replace PACKAGE BODY "IVACATION" as 
  c_pkg_version constant varchar2(5 char) := '1.2';
  c_pkg_name constant varchar2(30 char) := 'IVACATION';
 
  C_MANAGER_APPROVE_ID number := 1; 
  C_EMP_APPROVE_ID     number := 2; 
  C_EMP_REJECTED_ID    number := 3; 
 
  C_APPROVE            varchar2(20) := 'APPROVE_REQUEST'; 
  C_REDO_BALANCE       varchar2(20) := 'REDO_BALANCE'; 
 
 
 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            CONSTRUCT_LINK 
-- Type:            function 
-- Return:          Varchar2 
-- Creation date:   06-MAR-2014 
-- Created by:      Alexandru Banu 
-- Description:     Returns a qualified link 
-- 
--***************************************** 
/**
2026.08.05 - 1.1 - Pragya Kapoor - Modify the logic for GET_AMOUNT_TO_ADD. Do not expire the carryover for employees in AA_EXEMPTED_EMP table
2026.09.01 - 1.2 - Pragya Kapoor - Send notification when status is changed to Waiting Approval. Made changes to CLEAR_APPROVAL SR 180508
**/
function CONSTRUCT_LINK(P_PAGE_ID varchar2, P_CHECKSUM varchar2 default null, P_REQUEST varchar2 default null, P_SET_ARGS varchar2 default null) 
return varchar2 
is 
 
  V_LINK        varchar2(4000); 
  V_APP_SESSION number := V('APP_SESSION'); 
 
  V_CGIVAR_NAME  OWA.VC_ARR; 
  V_CGIVAR_VAL   OWA.VC_ARR; 
  V_WORKSPACE_ID number; 
 
  V_APP_USER      varchar2(100); 
 
begin 
-- If there is no valid session create one 
  if V_APP_SESSION is null then 
  -- Set the app user that is going to create the 
    if V('APP_USER') is null then 
      V_APP_USER := 'ROHIT.BQ.KUMAR@ORACLE.COM'; 
    else 
      V_APP_USER := V('APP_USER'); 
    end if; 
 
  -- set up cgi environment 
    HTP.INIT; 
    V_CGIVAR_NAME(1) := 'REQUEST_PROTOCOL'; 
    V_CGIVAR_VAL(1)  := 'HTTP'; 
 
    OWA.INIT_CGI_ENV( 
      NUM_PARAMS => V_CGIVAR_NAME.COUNT 
     ,PARAM_NAME => V_CGIVAR_NAME 
     ,PARAM_VAL  => V_CGIVAR_VAL 
    ); 
 
  -- Set the security id 
    SET_SECURITY_ID; 
 
  -- Set up apex session vars 
    APEX_APPLICATION.G_INSTANCE     := WWV_FLOW_CUSTOM_AUTH.GET_NEXT_SESSION_ID; 
 
    APEX_APPLICATION.G_FLOW_ID      := c_APP_ID; 
    APEX_APPLICATION.G_FLOW_STEP_ID := P_PAGE_ID; 
 
  -- Login 
    APEX_CUSTOM_AUTH.DEFINE_USER_SESSION( 
      P_USER       => V_APP_USER 
     ,P_SESSION_ID => APEX_APPLICATION.G_INSTANCE 
    ); 
 
    WWV_FLOW_CUSTOM_AUTH_STD.POST_LOGIN( 
      P_UNAME      => V_APP_USER 
     ,P_SESSION_ID => APEX_APPLICATION.G_INSTANCE 
     ,P_FLOW_PAGE  => APEX_APPLICATION.G_FLOW_ID||':'|| APEX_APPLICATION.G_FLOW_STEP_ID 
    ); 
 
  end if; 
 
-- Set array of protected PAGE IDS for session STATE protection 
--  APEX_APPLICATION.G_PROTECTED_PAGE_IDS(1) := P_PAGE_ID; 

-- Bhuvi Made a change added a new parameter p_plain_url
  if P_CHECKSUM is null 
    then 
      V_LINK:=  APEX_MAIL.GET_INSTANCE_URL||'f?p='||c_APP_ID||':'||P_PAGE_ID||':'||P_REQUEST; 
  else 
 
 --'f?p='||c_APP_ID||':'||P_PAGE_ID||'::'||P_REQUEST||':NO::'||P_SET_ARGS , this is the code without session, but I have changed the type of page 3 to normal page so now the old code should work fine
    V_LINK := APEX_UTIL.PREPARE_URL(P_URL           => 'f?p='||c_APP_ID||':'||P_PAGE_ID||':'||V_APP_SESSION||':'||P_REQUEST||':NO::'||P_SET_ARGS ,
                                  -- ,P_CHECKSUM_TYPE => P_CHECKSUM
                                   P_CHECKSUM_TYPE => 'PUBLIC_BOOKMARK'
                                   ,p_plain_url => TRUE); 
 
    V_LINK := APEX_MAIL.GET_INSTANCE_URL||V_LINK; 
  end if; 
 
  return V_LINK; 

  --Bhuvi's New Code was trying via GET_URL function
--    IF P_CHECKSUM IS NULL THEN
--         -- Constructing a simple link without checksum
--         V_LINK := APEX_MAIL.GET_INSTANCE_URL || APEX_PAGE.GET_URL(
--             p_application => c_APP_ID,
--             p_page => P_PAGE_ID,
--             p_request => P_REQUEST,
--             p_items => P_SET_ARGS
--         );
--     ELSE
--         -- Constructing a URL with checksum using APEX_PAGE.GET_URL
--         V_LINK := APEX_MAIL.GET_INSTANCE_URL || APEX_PAGE.GET_URL(
--             p_application => c_APP_ID,
--             p_page => P_PAGE_ID,
--             p_session => V_APP_SESSION,
--          --   p_request => P_REQUEST,
--        --     p_items => P_SET_ARGS,
--             p_items =>'P3_REQUEST_ID,P3_COUNTRY_ID',
--             p_values => P_REQUEST  P_SET_ARGS,
--             p_checksum_type => P_CHECKSUM
--         );
--     END IF;
 
end CONSTRUCT_LINK; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            exist_status 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if a status already exists 
-- 
--***************************************** 
function EXIST_STATUS (P_STATUS_TYPE varchar2) 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_STATUS_TYPES 
    where STATUS_TYPE = P_STATUS_TYPE; 
 
    if V_COUNT > 0 
      then return true; 
    else 
      return false; 
    end if; 
 
end EXIST_STATUS; 
 
 
 
 
--***************************************** 
-- 
-- Name:            new_status 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Create a new status 
-- 
--***************************************** 
procedure NEW_STATUS (P_STATUS_TYPE varchar) 
is 
 
  V_STATUS_TYPE   AA_STATUS_TYPES.STATUS_TYPE%type; 
  E_EXIST         EXCEPTION; 
 
begin 
 
  V_STATUS_TYPE := WS_TOOLS.TRIM_ALL(INITCAP(P_STATUS_TYPE)); 
 
  if EXIST_STATUS(V_STATUS_TYPE) = false 
    then 
      insert into AA_STATUS_TYPES (STATUS_TYPE) values (V_STATUS_TYPE); 
  else 
    RAISE E_EXIST; 
  end if; 
 
  EXCEPTION 
    when E_EXIST 
      then RAISE_APPLICATION_ERROR(-20001, 'The status "'||V_STATUS_TYPE||'" already exists'); 
 
end NEW_STATUS; 
 
 
 
--***************************************** 
-- 
-- Name:            get_manager_email 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Creates the HTML for the manager email 
-- 
--***************************************** 
function GET_MANAGER_EMAIL(P_MANAGER_EMAIL varchar2, P_EMP_NUMBER varchar2, P_NO_WORK_DAYS_LEAVE number, P_LEAVE_START date, P_LEAVE_END date, P_REQUEST_ID number, P_EMP_EMAIL varchar2 default null, P_EMP_COMMENTS varchar2 default null) 
return clob 
is 
 
  V_CLOB            clob; 
  V_MANAGER_NAME    T.EMAIL; 
  V_EMP_NAME        T.EMAIL; 
  V_EMP_EMAIL       T.EMAIL; 
  V_START_DATE      varchar2(12); 
  V_END_DATE        varchar2(12); 
  V_LINK            varchar2(1000); 
  V_EMP_PERSON_TYPE GLB_DATAWAREHOUSE.USER_PERSON_TYPE%type; 
 
  V_VACATION_PLAN   AA_COUNTRY_VP_INT.PLAN_DESC%type; 
  V_COUNTRY_ID      AA_COUNTRY_VP_INT.AA_COUNTRY_ID%type; 
 
begin 
 
  select EMAIL_TEMPLATE 
    into V_CLOB 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = 1; -- Manager Email template 
 
  select ACVI.PLAN_DESC, AA_COUNTRY_ID 
    into V_VACATION_PLAN, V_COUNTRY_ID 
    from AA_REQUESTS AR 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AR.AA_COUNTRY_VP_INT_ID 
    where AR.AA_REQUEST_ID = P_REQUEST_ID; 
 
  V_MANAGER_NAME := WS_TOOLS.GET_USER_NAME(P_MANAGER_EMAIL); 
  V_START_DATE := TO_CHAR(P_LEAVE_START,'DD-MON-YYYY'); 
  V_END_DATE := TO_CHAR(P_LEAVE_END,'DD-MON-YYYY'); 
  V_LINK := CONSTRUCT_LINK('3','PUBLIC_BOOKMARK',null,'P3_REQUEST_ID,P3_COUNTRY_ID:'||P_REQUEST_ID||','||V_COUNTRY_ID); 

  --bhu_logs(1,'V_LINK '||V_LINK,'V_LINK clob 1');
 
 
  if P_EMP_EMAIL is not null 
    then 
      V_EMP_NAME := WS_TOOLS.GET_USER_NAME(P_EMP_EMAIL); 
      V_EMP_EMAIL := P_EMP_EMAIL; 
  else 
    V_EMP_NAME := WS_TOOLS.GET_USER_NAME(WS_TOOLS.GET_USER); 
    V_EMP_EMAIL := WS_TOOLS.GET_USER; 
  end if; 
   
  begin 
    select USER_PERSON_TYPE 
    into V_EMP_PERSON_TYPE 
    from GLB_DATAWAREHOUSE 
    where EMP_EMAIL = nvl(P_EMP_EMAIL,WS_TOOLS.GET_USER); 
  exception 
    when NO_DATA_FOUND then V_EMP_PERSON_TYPE := 'Not Available'; 
  end;   
 
 
  V_CLOB := replace(V_CLOB,'[[$$NAME]]',V_MANAGER_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_NAME]]',V_EMP_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$NAME]]',V_MANAGER_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_EMAIL]]',V_EMP_EMAIL); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_NUMBER]]',P_EMP_NUMBER); 
  V_CLOB := replace(V_CLOB,'[[$$WORKING_DAYS]]',TO_CHAR(P_NO_WORK_DAYS_LEAVE)); 
  V_CLOB := replace(V_CLOB,'[[$$START_DATE]]',V_START_DATE); 
  V_CLOB := replace(V_CLOB,'[[$$END_DATE]]',V_END_DATE); 
  V_CLOB := replace(V_CLOB,'[[$$LINK]]',V_LINK); 
  V_CLOB := replace(V_CLOB,'[[$$VACATION_PLAN]]',V_VACATION_PLAN); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_COMMENTS]]',P_EMP_COMMENTS); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_PERSON_TYPE]]',V_EMP_PERSON_TYPE); 

    --bhu_logs(2,'V_CLOB ','V_CLOB clob 2 '||V_CLOB);
   
  if V_COUNTRY_ID in (31,27,26,29,21,16,15,14) and (lower(V_VACATION_PLAN) like '%paternity%' or lower(V_VACATION_PLAN) like '%parental%') then 
    V_CLOB := replace(V_CLOB,'[[$$PARENTAL_LEAVE]]', 
                    '<p style="font-size: 12px; font-family: Arial, Helvetica, sans-serif; color: #000000; line-height:18px; margin-bottom:8px; text-align:justify;"> 
                  The '||V_VACATION_PLAN||' request will be reviewed by HR Operations to ensure it is in line with the policy''s eligibility criteria. A resolution will be provided post review. 
                  </p>'); 
  else V_CLOB :=   replace(V_CLOB,'[[$$PARENTAL_LEAVE]]','');               
                   
  end if; 
 
 
 
  return V_CLOB; 
 
end GET_MANAGER_EMAIL; 
 
 
 
--***************************************** 
-- 
-- Name:            get_emp_cancelled_eml 
-- Type:            Procedure 
-- Creation date:   24-Jun-2014 
-- Created by:      Alexandru Banu 
-- Description:     Produces the email template used when an employee cancelles a request 
-- 
--***************************************** 
function GET_EMP_CANCELLED_EML(P_MANAGER_EMAIL varchar2, P_EMP_NUMBER varchar2, P_NO_WORK_DAYS_LEAVE number, P_LEAVE_START date, P_LEAVE_END date, P_REQUEST_ID number, P_EMP_EMAIL varchar2 default null, P_EMP_COMMENTS varchar2 default null) 
return clob 
is 
 
  V_CLOB            clob; 
  V_MANAGER_NAME    T.EMAIL; 
  V_EMP_NAME        T.EMAIL; 
  V_EMP_EMAIL       T.EMAIL; 
  V_START_DATE      varchar2(12); 
  V_END_DATE        varchar2(12); 
  V_LINK            varchar2(255); 
 
  V_VACATION_PLAN   AA_COUNTRY_VP_INT.PLAN_DESC%type; 
  V_COUNTRY_ID      AA_COUNTRY_VP_INT.AA_COUNTRY_ID%type; 
 
begin 
 
  select EMAIL_TEMPLATE 
    into V_CLOB 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = 8; -- Manager - Request Cancelled 
 
  select ACVI.PLAN_DESC, AA_COUNTRY_ID 
    into V_VACATION_PLAN, V_COUNTRY_ID 
    from AA_REQUESTS AR 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AR.AA_COUNTRY_VP_INT_ID 
    where AR.AA_REQUEST_ID = P_REQUEST_ID; 
 
 
  V_MANAGER_NAME := WS_TOOLS.GET_USER_NAME(P_MANAGER_EMAIL); 
  V_START_DATE := TO_CHAR(P_LEAVE_START,'DD-MON-YYYY'); 
  V_END_DATE := TO_CHAR(P_LEAVE_END,'DD-MON-YYYY'); 
  V_LINK := CONSTRUCT_LINK('2','PUBLIC_BOOKMARK'); 
 
 
  if P_EMP_EMAIL is not null 
    then 
      V_EMP_NAME := WS_TOOLS.GET_USER_NAME(P_EMP_EMAIL); 
      V_EMP_EMAIL := P_EMP_EMAIL; 
  else 
    V_EMP_NAME := WS_TOOLS.GET_USER_NAME(WS_TOOLS.GET_USER); 
    V_EMP_EMAIL := WS_TOOLS.GET_USER; 
  end if; 
 
 
  V_CLOB := replace(V_CLOB,'[[$$NAME]]',V_MANAGER_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_NAME]]',V_EMP_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$NAME]]',V_MANAGER_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_EMAIL]]',V_EMP_EMAIL); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_NUMBER]]',P_EMP_NUMBER); 
  V_CLOB := replace(V_CLOB,'[[$$WORKING_DAYS]]',TO_CHAR(P_NO_WORK_DAYS_LEAVE)); 
  V_CLOB := replace(V_CLOB,'[[$$START_DATE]]',V_START_DATE); 
  V_CLOB := replace(V_CLOB,'[[$$END_DATE]]',V_END_DATE); 
  V_CLOB := replace(V_CLOB,'[[$$LINK]]',V_LINK); 
  V_CLOB := replace(V_CLOB,'[[$$VACATION_PLAN]]',V_VACATION_PLAN); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_COMMENTS]]',P_EMP_COMMENTS); 
 
 
  return V_CLOB; 
 
end GET_EMP_CANCELLED_EML; 
 
 
 
--***************************************** 
-- 
-- Name:            get_employee_email 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Creates the employee email 
-- 
--***************************************** 
function GET_EMPLOYEE_EMAIL(P_REQUEST_ID number, P_EMAIL_TEMPLATE_ID number) 
return clob 
is 
 
  V_CLOB clob; 
 
begin 
 
  select EMAIL_TEMPLATE 
    into V_CLOB 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = P_EMAIL_TEMPLATE_ID; 
 
  for X in (select AR.EMP_EMAIL 
                  ,TO_CHAR(AE.EMP_NUMBER) EMP_NUMBER 
                  ,TO_CHAR(AR.NO_WORK_DAYS_LEAVE) NO_WORK_DAYS_LEAVE 
                  ,TO_CHAR(AR.LEAVE_START,'DD-MON-YYYY') LEAVE_START 
                  ,TO_CHAR(AR.LEAVE_END,'DD-MON-YYYY') LEAVE_END 
                  ,AR.COMMENTS 
                  ,ACVI.PLAN_DESC 
                  ,AR.EMP_COMMENTS 
            from AA_REQUESTS AR 
            join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
            join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AR.AA_COUNTRY_VP_INT_ID 
            where AR.AA_REQUEST_ID = P_REQUEST_ID 
            ) 
    LOOP 
 
      V_CLOB := replace(V_CLOB,'[[$$EMP_NAME]]',WS_TOOLS.GET_USER_NAME(X.EMP_EMAIL)); 
      V_CLOB := replace(V_CLOB,'[[$$EMP_EMAIL]]',X.EMP_EMAIL); 
      V_CLOB := replace(V_CLOB,'[[$$EMP_NUMBER]]',X.EMP_NUMBER); 
      V_CLOB := replace(V_CLOB,'[[$$WORKING_DAYS]]',X.NO_WORK_DAYS_LEAVE); 
      V_CLOB := replace(V_CLOB,'[[$$START_DATE]]',X.LEAVE_START); 
      V_CLOB := replace(V_CLOB,'[[$$END_DATE]]',X.LEAVE_END); 
      V_CLOB := replace(V_CLOB,'[[$$COMMENTS]]',X.COMMENTS); 
      V_CLOB := replace(V_CLOB,'[[$$VACATION_PLAN]]',X.PLAN_DESC); 
      V_CLOB := replace(V_CLOB,'[[$$EMP_COMMENTS]]',X.EMP_COMMENTS); 
 
    end LOOP; 
 
  return V_CLOB; 
 
end GET_EMPLOYEE_EMAIL; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            EXIST_VAC_PERIOD 
-- Type:            function 
-- Creation date:   18-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Check if the employee does not hava another overlapping request 
-- 
--***************************************** 
function EXIST_VAC_PERIOD(P_EMP_EMAIL varchar2 
                         ,P_LEAVE_START date 
                         ,P_LEAVE_END date) return boolean is 
  
  c_proc_version constant varchar2(5 char) := '1.0';
  c_proc_name constant varchar2(30 char) := 'EXIST_VAC_PERIOD';
  v_ln varchar2(1000);

  V_COUNT PLS_INTEGER; 
 
begin 
   v_ln := '0';

   select COUNT(1) 
    into V_COUNT 
    from AA_REQUESTS 
    where EMP_EMAIL = UPPER(P_EMP_EMAIL) 
    and AA_STATUS_ID in (1,2) -- Waiting Approval or Approved 
    and ( 
         (TRUNC(P_LEAVE_START) <= TRUNC(LEAVE_START) 
          and 
          NVL(P_LEAVE_END,TO_DATE('9999','yyyy')) >= TRUNC(LEAVE_START)) 
 
         or 
 
         (TRUNC(P_LEAVE_START) >= TRUNC(LEAVE_START) 
          and 
          TRUNC(P_LEAVE_START) <= NVL(LEAVE_END,TO_DATE('9999','yyyy'))) 
        ); 
   v_ln := '1';
 
  if V_COUNT = 0 then 
    return false; 
  else 
    return true; 
  end if; 
  v_ln := '2';

  exception
     when others then
        WS_TOOLS.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'['||v_ln||'] -'||SQLERRM,SQLCODE,'ERROR');
 
end EXIST_VAC_PERIOD; 
 
--***************************************** 
-- 
-- Name:            ALLOW_NEGATIVE_BALANCE 
-- Type:            Function 
-- Creation date:   15-APR-2020 
-- Created by:      Alexandru Banu, Madalin Nastase 
-- Description:     Create a new request 
-- Update Date:     11-NOV-2021 
-- Updated by:      Cristina Ursulescu 
-- Description:     Limit the number of days that can be taken from next FY (HRITEMEA-69) 
--***************************************** 
 
function ALLOW_NEGATIVE_BALANCE (P_NO_WORK_DAYS_LEAVE number 
                                ,P_AA_COUNTRY_VP_INT_ID number 
                                ,P_EMP_EMAIL varchar2) return boolean is 

c_proc_name constant varchar2(61 char) := 'ALLOW_NEGATIVE_BALANCE';
c_proc_version constant varchar2(5 char) := '1.0';
v_ln varchar2(1000);
 
V_NEGATIVE_BALANCE number; 
V_BALANCE_CALC number; 
 
begin 

  v_ln := 0 ;
  select NEGATIVE_BALANCE 
    into V_NEGATIVE_BALANCE 
    from AA_COUNTRY_VP_INT 
   where AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 

  v_ln := 1 ;
  if V_NEGATIVE_BALANCE = 99999 then v_ln := '1_True' ; return true; 
    else 
       v_ln := '1_False' ;
       with PENDING_OR_FUTURE_LEAVES as (
           select SUM(NO_WORK_DAYS_LEAVE) DAYS_LEAVE 
             from AA_REQUESTS 
            where EMP_EMAIL = P_EMP_EMAIL 
              and AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
              and (AA_STATUS_ID = 1 /* waiting approval */ or (AA_STATUS_ID = 2 and trunc(LEAVE_START, 'MM') > trunc(sysdate, 'mm'))) /*Approved future vacations*/ 
                                        ) 
           select O.LEAVE_BALANCE - P_NO_WORK_DAYS_LEAVE - nvl(PENDING_OR_FUTURE_LEAVES.DAYS_LEAVE,0) + V_NEGATIVE_BALANCE 
             into V_BALANCE_CALC 
             from AA_OVERVIEW O 
                  left join PENDING_OR_FUTURE_LEAVES on 1=1 
            where O.EMP_EMAIL = P_EMP_EMAIL 
              and O.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
              and trunc(MONTH, 'mm') = trunc(sysdate, 'mm'); 

      v_ln := 2 ;
      if V_BALANCE_CALC < 0 then return false; 
         else return true; 
      end if;      
  end if; 

  EXCEPTION 
    when others then
      WS_Tools.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'['||v_ln||'] -'||SQLERRM,SQLCODE,'ERROR');
end ALLOW_NEGATIVE_BALANCE; 
 
 
--***************************************** 
-- 
-- Name:            new_request 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Create a new request 
-- 
--***************************************** 
procedure NEW_REQUEST(P_EMAIL_TO varchar2 
                     ,P_EMAIL_CC varchar2 
                     ,P_EMAIL_BCC varchar2 
                     ,P_NO_WORK_DAYS_LEAVE number 
                     ,P_LEAVE_START date 
                     ,P_LEAVE_END date 
                     ,P_AA_COUNTRY_VP_INT_ID number 
                     ,P_EMP_EMAIL varchar2 default null 
                     ,P_EMP_COMMENTS varchar2 default null) is 
/** returning a list of IDs out of a string with IDs
2013.03.14 - 1.0 - Alexandru Banu
*/

  c_proc_name constant varchar2(61 char) := 'NEW_REQUEST';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ln varchar2(1000);

  L_ID          number; 
 
  V_EMAIL_TO        AA_REQUESTS.EMAIL_TO%type; 
  V_EMP_EMAIL       T.EMAIL; 
  V_STATUS_ID       AA_REQUESTS.AA_STATUS_ID%type; 
  V_REQUEST_ID      AA_REQUESTS.AA_REQUEST_ID%type; 
  V_EMP_NUMBER      AA_EMPLOYEES.EMP_NUMBER%type; 
  V_MESSAGE         VARCHAR2(300); 
  V_NEGATIVE_BALANCE AA_COUNTRY_VP_INT.NEGATIVE_BALANCE%type; 
 
  E_NOT_SAME_MONTH  EXCEPTION; 
  E_EXIST           EXCEPTION; 
  E_ALLOW_NEGATIVE_BALANCE  EXCEPTION; 
 
begin 
  v_ln := 0; 
-- Begin and End date must be in the same month else through exception 
  if TO_CHAR(P_LEAVE_START,'mm') != TO_CHAR(P_LEAVE_END,'mm') 
  then 
    RAISE E_NOT_SAME_MONTH; 
  end if; 
  v_ln := 1;

  V_EMAIL_TO := WS_TOOLS.TRIM_ALL(UPPER(P_EMAIL_TO)); 
  V_STATUS_ID := 1; -- Waiting Approval 
  v_ln := 2;
 
  if P_EMP_EMAIL is not null 
    then 
      V_EMP_EMAIL := WS_TOOLS.TRIM_ALL(UPPER(P_EMP_EMAIL)); 
  else 
     V_EMP_EMAIL := WS_TOOLS.GET_USER; 
  end if; 
  v_ln := 3;
 
-- Check if there isn't an overlapping vacation request already submitted 
  if EXIST_VAC_PERIOD(P_EMP_EMAIL   => V_EMP_EMAIL 
                     ,P_LEAVE_START => P_LEAVE_START 
                     ,P_LEAVE_END   => P_LEAVE_END) then 
    RAISE E_EXIST; 
  end if; 
  
  v_ln := 4;
-- extra debug code
  WS_TOOLS.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version
          ,'['||v_ln||'] - P_NO_WORK_DAYS_LEAVE='||P_NO_WORK_DAYS_LEAVE||', P_AA_COUNTRY_VP_INT_ID='||P_AA_COUNTRY_VP_INT_ID||' ,V_EMP_EMAIL='||V_EMP_EMAIL
          ,SQLCODE,'DEBUG') ;
  if not ALLOW_NEGATIVE_BALANCE (P_NO_WORK_DAYS_LEAVE   => P_NO_WORK_DAYS_LEAVE 
                                ,P_AA_COUNTRY_VP_INT_ID => P_AA_COUNTRY_VP_INT_ID 
                                ,P_EMP_EMAIL            => V_EMP_EMAIL) then 
      select NEGATIVE_BALANCE 
      into V_NEGATIVE_BALANCE 
      from AA_COUNTRY_VP_INT 
      where AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID;  
  v_ln := 5;
       
      if V_NEGATIVE_BALANCE > 0 then          
            V_MESSAGE := 'You are entitled to take '|| V_NEGATIVE_BALANCE ||' days from the next Fiscal Year.';          
      else        
           V_MESSAGE := null;        
       end if;     
  v_ln := 6;
       
       
      V_MESSAGE := V_MESSAGE || 
                    ' Your vacation in amount of ' || P_NO_WORK_DAYS_LEAVE || ' days would lower your balance below '|| V_NEGATIVE_BALANCE; 
                                 
    RAISE E_ALLOW_NEGATIVE_BALANCE; 
  end if; 
  v_ln := 7;
 
  select EMP_NUMBER 
    into V_EMP_NUMBER 
    from AA_EMPLOYEES 
    where EMP_EMAIL = V_EMP_EMAIL; 
  v_ln := 8;
 
                
  insert into AA_REQUESTS (EMP_EMAIL, EMAIL_TO, EMAIL_CC, EMAIL_BCC, NO_WORK_DAYS_LEAVE, LEAVE_START, LEAVE_END, AA_STATUS_ID, AA_COUNTRY_VP_INT_ID, EMP_COMMENTS, EMP_NUMBER) 
    values (V_EMP_EMAIL, V_EMAIL_TO, P_EMAIL_CC, P_EMAIL_BCC, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_STATUS_ID, P_AA_COUNTRY_VP_INT_ID, P_EMP_COMMENTS, V_EMP_NUMBER) 
    returning AA_REQUEST_ID into V_REQUEST_ID; 

    --  WS_Tools.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,GET_MANAGER_EMAIL(P_EMAIL_TO, V_EMP_NUMBER, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_REQUEST_ID,V_EMP_EMAIL, P_EMP_COMMENTS),NULL,'DEBUG');
  v_ln := 9;
 
 --Extra loading code
--   WS_Tools.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,GET_MANAGER_EMAIL(P_EMAIL_TO, V_EMP_NUMBER, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_REQUEST_ID,V_EMP_EMAIL, P_EMP_COMMENTS),NULL,'DEBUG');

--   L_ID  := APEX_MAIL.SEND( 
--                              P_TO => -- P_EMAIL_TO, 
--                              P_CC => P_EMAIL_CC, 
--                              P_BCC => P_EMAIL_BCC, 
--                              P_FROM => C_EML_FROM, 
--                              P_BODY => TO_CLOB('Your email client doesn''t support HTML. Please use a client that does. Thank you.'), 
--                              P_BODY_HTML => GET_MANAGER_EMAIL(P_EMAIL_TO, V_EMP_NUMBER, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_REQUEST_ID,V_EMP_EMAIL, P_EMP_COMMENTS), 
--                              P_SUBJ => 'Approval Required: Annual Leave Template '||V_EMP_EMAIL); 
bhu_logs(3000,'log3000'||systimestamp,' P_EMAIL_TO '||P_EMAIL_TO ||'P_EMAIL_CC '||P_EMAIL_CC ||' P_EMAIL_BCC '||P_EMAIL_BCC);
  L_ID  := APEX_MAIL.SEND( 
                             P_TO => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  P_EMAIL_TO else c_default_mail_list end), 
                             P_CC => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  P_EMAIL_CC else c_default_mail_list end), 
                             P_BCC => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  P_EMAIL_BCC else c_default_mail_list end),
                             P_FROM => C_EML_FROM, 
                             P_BODY => TO_CLOB('Your email client doesn''t support HTML. Please use a client that does. Thank you.'), 
                             P_BODY_HTML => to_clob(GET_MANAGER_EMAIL(P_EMAIL_TO, V_EMP_NUMBER, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_REQUEST_ID,V_EMP_EMAIL, P_EMP_COMMENTS)), 
                             P_SUBJ => 'Approval Required: Annual Leave Template '||V_EMP_EMAIL); 
  v_ln := 10;
  /* 
  for x in (select logo_name,logo,mime_type 
            from ment_logos 
            where ment_logo_id = 1) 
  loop 
    APEX_MAIL.ADD_ATTACHMENT( p_mail_id    => l_id, 
                              p_attachment => x.logo, 
                              p_filename   => x.logo_name, 
                              p_mime_type  => x.mime_type); 
  end loop;*/ 
  commit; 
   v_ln := 11;

  APEX_MAIL.PUSH_QUEUE('mail.oracle.com'); 
  v_ln := 12;
 
-- Set Overplapping Vacation item to 0 so that the report witht he overlapping vacations isn't shown 
  APEX_UTIL.SET_SESSION_STATE(P_NAME => 'P1_OVERLAPPING_VAC', P_VALUE => '0'); 
  v_ln := 13;
 
  EXCEPTION 
    when E_NOT_SAME_MONTH 
      then RAISE_APPLICATION_ERROR(-20006,'First day on leave and Last day on leave must be in the same month. If the leave crosses into another month please submit 2 requests (one for each month)'); 
    when E_EXIST then 
                      APEX_UTIL.SET_SESSION_STATE(P_NAME => 'P1_OVERLAPPING_VAC', P_VALUE => '1'); 
                      RAISE_APPLICATION_ERROR(-20007,'You have already submitted a Vacation Request that is overlapping the same dates as the current one. You have the posibility to cancel the previous request and submit a new one.' 
                                                    ||' For more information please contact your HR Representative.'); 
    when E_ALLOW_NEGATIVE_BALANCE then RAISE_APPLICATION_ERROR(-20008, V_MESSAGE); 
    when others then
      WS_Tools.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'['||v_ln||'] -'||SQLERRM,SQLCODE,'ERROR');
    raise;

end NEW_REQUEST; 
 
--***************************************** 
-- 
-- Name:            new_request 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Create a new request 
-- 
--***************************************** 
procedure NEW_REQUEST_temp(P_EMAIL_TO varchar2 
                     ,P_EMAIL_CC varchar2 
                     ,P_EMAIL_BCC varchar2 
                     ,P_NO_WORK_DAYS_LEAVE number 
                     ,P_LEAVE_START date 
                     ,P_LEAVE_END date 
                     ,P_AA_COUNTRY_VP_INT_ID number 
                     ,P_EMP_EMAIL varchar2 default null 
                     ,P_EMP_COMMENTS varchar2 default null) is 
/** returning a list of IDs out of a string with IDs
2013.03.14 - 1.0 - Alexandru Banu
*/

  c_proc_name constant varchar2(61 char) := 'NEW_REQUEST';
  c_proc_version constant varchar2(5 char) := '1.0';
  v_ln varchar2(1000);

  L_ID          number; 
 
  V_EMAIL_TO        AA_REQUESTS.EMAIL_TO%type; 
  V_EMP_EMAIL       T.EMAIL; 
  V_STATUS_ID       AA_REQUESTS.AA_STATUS_ID%type; 
  V_REQUEST_ID      AA_REQUESTS.AA_REQUEST_ID%type; 
  V_EMP_NUMBER      AA_EMPLOYEES.EMP_NUMBER%type; 
  V_MESSAGE         VARCHAR2(300); 
  V_NEGATIVE_BALANCE AA_COUNTRY_VP_INT.NEGATIVE_BALANCE%type; 
 
  E_NOT_SAME_MONTH  EXCEPTION; 
  E_EXIST           EXCEPTION; 
  E_ALLOW_NEGATIVE_BALANCE  EXCEPTION; 
 
begin 
  v_ln := 0; 
-- Begin and End date must be in the same month else through exception 
  if TO_CHAR(P_LEAVE_START,'mm') != TO_CHAR(P_LEAVE_END,'mm') 
  then 
    RAISE E_NOT_SAME_MONTH; 
  end if; 
  v_ln := 1;

  V_EMAIL_TO := WS_TOOLS.TRIM_ALL(UPPER(P_EMAIL_TO)); 
  V_STATUS_ID := 1; -- Waiting Approval 
  v_ln := 2;
 
  if P_EMP_EMAIL is not null 
    then 
      V_EMP_EMAIL := WS_TOOLS.TRIM_ALL(UPPER(P_EMP_EMAIL)); 
  else 
     V_EMP_EMAIL := WS_TOOLS.GET_USER; 
  end if; 
  v_ln := 3;
 
-- Check if there isn't an overlapping vacation request already submitted 
  if EXIST_VAC_PERIOD(P_EMP_EMAIL   => V_EMP_EMAIL 
                     ,P_LEAVE_START => P_LEAVE_START 
                     ,P_LEAVE_END   => P_LEAVE_END) then 
    RAISE E_EXIST; 
  end if; 
  
  v_ln := 4;
-- extra debug code
  WS_TOOLS.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version
          ,'['||v_ln||'] - P_NO_WORK_DAYS_LEAVE='||P_NO_WORK_DAYS_LEAVE||', P_AA_COUNTRY_VP_INT_ID='||P_AA_COUNTRY_VP_INT_ID||' ,V_EMP_EMAIL='||V_EMP_EMAIL
          ,SQLCODE,'DEBUG') ;
  if not ALLOW_NEGATIVE_BALANCE (P_NO_WORK_DAYS_LEAVE   => P_NO_WORK_DAYS_LEAVE 
                                ,P_AA_COUNTRY_VP_INT_ID => P_AA_COUNTRY_VP_INT_ID 
                                ,P_EMP_EMAIL            => V_EMP_EMAIL) then 
      select NEGATIVE_BALANCE 
      into V_NEGATIVE_BALANCE 
      from AA_COUNTRY_VP_INT 
      where AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID;  
  v_ln := 5;
       
      if V_NEGATIVE_BALANCE > 0 then          
            V_MESSAGE := 'You are entitled to take '|| V_NEGATIVE_BALANCE ||' days from the next Fiscal Year.';          
      else        
           V_MESSAGE := null;        
       end if;     
  v_ln := 6;
       
       
      V_MESSAGE := V_MESSAGE || 
                    ' Your vacation in amount of ' || P_NO_WORK_DAYS_LEAVE || ' days would lower your balance below '|| V_NEGATIVE_BALANCE; 
                                 
    RAISE E_ALLOW_NEGATIVE_BALANCE; 
  end if; 
  v_ln := 7;
 
  select EMP_NUMBER 
    into V_EMP_NUMBER 
    from AA_EMPLOYEES 
    where EMP_EMAIL = V_EMP_EMAIL; 
  v_ln := 8;
 
                
  insert into AA_REQUESTS (EMP_EMAIL, EMAIL_TO, EMAIL_CC, EMAIL_BCC, NO_WORK_DAYS_LEAVE, LEAVE_START, LEAVE_END, AA_STATUS_ID, AA_COUNTRY_VP_INT_ID, EMP_COMMENTS, EMP_NUMBER) 
    values (V_EMP_EMAIL, V_EMAIL_TO, P_EMAIL_CC, P_EMAIL_BCC, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_STATUS_ID, P_AA_COUNTRY_VP_INT_ID, P_EMP_COMMENTS, V_EMP_NUMBER) 
    returning AA_REQUEST_ID into V_REQUEST_ID; 

    --  WS_Tools.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,GET_MANAGER_EMAIL(P_EMAIL_TO, V_EMP_NUMBER, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_REQUEST_ID,V_EMP_EMAIL, P_EMP_COMMENTS),NULL,'DEBUG');
  v_ln := 9;
 

  v_ln := 10;

  commit; 
   v_ln := 11;


  v_ln := 12;
 
-- Set Overplapping Vacation item to 0 so that the report witht he overlapping vacations isn't shown 
  APEX_UTIL.SET_SESSION_STATE(P_NAME => 'P1_OVERLAPPING_VAC', P_VALUE => '0'); 
  v_ln := 13;
 
  EXCEPTION 
    when E_NOT_SAME_MONTH 
      then RAISE_APPLICATION_ERROR(-20006,'First day on leave and Last day on leave must be in the same month. If the leave crosses into another month please submit 2 requests (one for each month)'); 
    when E_EXIST then 
                      APEX_UTIL.SET_SESSION_STATE(P_NAME => 'P1_OVERLAPPING_VAC', P_VALUE => '1'); 
                      RAISE_APPLICATION_ERROR(-20007,'You have already submitted a Vacation Request that is overlapping the same dates as the current one. You have the posibility to cancel the previous request and submit a new one.' 
                                                    ||' For more information please contact your HR Representative.'); 
    when E_ALLOW_NEGATIVE_BALANCE then RAISE_APPLICATION_ERROR(-20008, V_MESSAGE); 
    when others then
      WS_Tools.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'['||v_ln||'] -'||SQLERRM,SQLCODE,'ERROR');
    raise;

end NEW_REQUEST_temp; 
 
 
--***************************************** 
-- 
-- Name:            exist_emp_overview_month 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the curent month has been introduced in the overview table for the particular employee 
-- 
--***************************************** 
function EXIST_EMP_OVERVIEW_MONTH(P_EMP_EMAIL            varchar2 
                                 ,P_MONTH                date 
                                 ,P_AA_COUNTRY_VP_INT_ID number) 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
  into V_COUNT 
  from AA_OVERVIEW 
  where EMP_EMAIL = P_EMP_EMAIL 
  and TO_CHAR(month,'mm.yy') = TO_CHAR(P_MONTH,'mm.yy') 
  and AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
  if V_COUNT > 0 
    then return true; 
  else 
    return false; 
  end if; 
 
end EXIST_EMP_OVERVIEW_MONTH; 
 
 
 
 
 
-- --***************************************** 
-- -- 
-- -- Name:            GET_BEGIN_END_DATES 
-- -- Type:            Procedure 
-- -- Creation date:   30-Jan-2019 
-- -- Created by:      Alexandru Banu 
-- -- Description:     Get the Begin and End dates of the period 
-- -- 
-- --***************************************** 
procedure GET_BEGIN_END_DATES( 
  P_EMP_EMAIL             in  AA_EMPLOYEES.EMP_EMAIL%type 
 ,P_DATE                  in  AA_OVERVIEW.MONTH%type 
 ,P_AA_COUNTRY_VP_INT_ID  in  AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type 
 ,P_BEGIN_DATE            out AA_OVERVIEW.MONTH%type 
 ,P_END_DATE              out AA_OVERVIEW.MONTH%type 
) 
is 
 
  V_YEAR_BEGIN_DATE AA_VACATION_PLANS.YEAR_BEGIN_DATE%type; 
  V_YEAR_END_DATE   AA_VACATION_PLANS.YEAR_END_DATE%type; 
  V_EMP_START_DATE  AA_EMPLOYEES.START_DATE%type; 
  V_EMP_END_DATE    AA_EMPLOYEES.END_DATE%type; 
  V_ACVI_START_DATE AA_COUNTRY_VP_INT.BEGIN_DATE%type; 
  V_ACVI_END_DATE   AA_COUNTRY_VP_INT.END_DATE%type; 
 
begin 
-- Select the data 
  select AVP.YEAR_BEGIN_DATE 
        ,AVP.YEAR_END_DATE 
        ,AE.START_DATE 
        ,AE.END_DATE 
        ,ACVI.BEGIN_DATE 
        ,ACVI.END_DATE 
 
    into V_YEAR_BEGIN_DATE 
        ,V_YEAR_END_DATE 
        ,V_EMP_START_DATE 
        ,V_EMP_END_DATE 
        ,V_ACVI_START_DATE 
        ,V_ACVI_END_DATE 
 
    from AA_EMPLOYEES AE 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
    join AA_VACATION_PLANS AVP on AVP.AA_VACATION_PLAN_ID = ACVI.AA_VACATION_PLAN_ID 
    left join AA_VACATION_PLAN_CAPS AVPC on (AVPC.AA_COUNTRY_VP_INT_ID = ACVI.AA_COUNTRY_VP_INT_ID 
                                              and ROUND(MONTHS_BETWEEN(TRUNC(NVL(P_DATE,TRUNC(SYSDATE))),TRUNC(AE.START_DATE)) + NVL(AE.TENURE_BEFORE_ORACLE_MONTHS,0)) between AVPC.TEN_STATRT and AVPC.TEN_END 
                                            ) 
    left join AA_EMP_CUST_ACCRUAL AECA on (AECA.EMP_EMAIL = AE.EMP_EMAIL 
                                            and TRUNC(P_DATE,'mm') between TRUNC(AECA.BEGIN_DATE,'mm') and NVL(LAST_DAY(TRUNC(AECA.END_DATE,'mm')), TO_DATE('01.01.4076','dd.mm.yyyy')) 
                                          ) 
    left join AA_OVERVIEW AO on AO.EMP_EMAIL = AE.EMP_EMAIL 
                            and trunc(AO.MONTH,'mm') = trunc(P_DATE,'mm') 
                            and AO.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
    where AE.EMP_EMAIL = P_EMP_EMAIL 
    and ACVI.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
-- Calculate the outputs 
  V_YEAR_BEGIN_DATE := TO_DATE(to_char(V_YEAR_BEGIN_DATE,'dd') 
                      ||'-' 
                      ||to_char(V_YEAR_BEGIN_DATE,'Mon') 
                      ||'-' 
                      ||to_char(P_DATE,'yyyy') 
                      ,'dd-Mon-yyyy'); 
-- If the current month is before the YEAR_BEGIN_DATE, subtract one year from YEAR_BEGIN_DATE 
-- This applies to vacation plans that don't have the YEAR_BEGIN_DATE and YEAR_END_DATE in the same calendar year 
  if trunc(P_DATE) < V_YEAR_BEGIN_DATE then 
    V_YEAR_BEGIN_DATE := ADD_MONTHS(V_YEAR_BEGIN_DATE,-12); 
  end if; 
-- If the start date of the employee is greated than the YEAR_BEGIN_DATE of the vacation plan set it as the START_DATE 
-- As the employee started after the vacation plan's YEAR_BEGIN_DATE 
  if V_EMP_START_DATE > V_YEAR_BEGIN_DATE then 
    V_YEAR_BEGIN_DATE := trunc(V_EMP_START_DATE); 
  end if; 
-- If the vacation plan start date is greater than the YEAR_BEGIN_DATE use it 
-- As is means that the vacation plan has changed and it should be used to calculate the accrual 
  if V_ACVI_START_DATE > V_YEAR_BEGIN_DATE then 
    V_YEAR_BEGIN_DATE := V_ACVI_START_DATE; 
  end if; 
-- Calculate the YEAR_END_DATE for the vacation plan 
  V_YEAR_END_DATE := TO_DATE(to_char(V_YEAR_END_DATE,'dd') 
                      ||'-' 
                      ||to_char(V_YEAR_END_DATE,'Mon') 
                      ||'-' 
                      ||to_char(P_DATE,'yyyy') 
                      ,'dd-Mon-yyyy'); 
-- If the YEAR_BEGIN_DATE is greater than the YEAR_END_DATE add 12 months to the end 
-- This applies to vacation plans that don't have the YEAR_BEGIN_DATE and YEAR_END_DATE in the same calendar year 
  if V_YEAR_BEGIN_DATE > V_YEAR_END_DATE then 
    V_YEAR_END_DATE := ADD_MONTHS(V_YEAR_END_DATE,12); 
  end if; 
-- The YEAR_END_DATE should be the least date out of: 
-- YEAR_END_DATE, Employee's END_DATE and the vacation plan's END_DATE 
  V_YEAR_END_DATE := LEAST(V_YEAR_END_DATE, NVL(V_EMP_END_DATE,V_YEAR_END_DATE), nvl(V_ACVI_END_DATE,V_YEAR_END_DATE)); 
 
-- Return the variables 
  P_BEGIN_DATE := V_YEAR_BEGIN_DATE; 
  P_END_DATE := V_YEAR_END_DATE; 
 
end GET_BEGIN_END_DATES; 
 
 
 
 
--***************************************** 
-- 
-- Name:            get_amount_to_add 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the amount_added is null or not 
-- 
--***************************************** 
function GET_AMOUNT_TO_ADD(P_AA_OVERVIEW_ID number, P_NEW_LEAVE_BALANCE number) 
/**
2026.08.05 - 1.1 - Pragya Kapoor - Modify the logic for GET_AMOUNT_TO_ADD. Do not expire the carryover for employees in AA_EXEMPTED_EMP table
**/
return number 
is 
 
  V_ACCRUAL_EXPIRY_DATE   number; 
  V_MONTH                 number; 
  V_BEGIN_DATE            date; 
  V_END_DATE              date; 
  V_MONTH_DATE            AA_OVERVIEW.MONTH%type; 
  V_ENTITLEMENT           AA_VACATION_PLANS.ENTITLED_NO_DAYS%type; 
  V_CUR_ENTITLEMENT       AA_VACATION_PLANS.ENTITLED_NO_DAYS%type; 
  V_MAX_ENTITLEMENT       AA_VACATION_PLANS.MAX_NO_DAYS%type; 
  V_MONTHLY_ACCRUAL       AA_VACATION_PLANS.MONTHLY_ACCRUAL%type; 
  V_AMOUNT_ADDED          AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_RATE_PER_MONTH        AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_CURRENT_BALANCE       AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_RETURN                AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_AA_COUNTRY_VP_INT_ID  AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type; 
  V_EMP_EMAIL             AA_OVERVIEW.EMP_EMAIL%type; 
  v_exempted_count        NUMBER;
 
begin 
 
----------------- 
-------------------------------------------------------- 
----------------- 
-------------------------------------------------------- 
----------------- 
-------------------------------------------------------- 
--------- ACCRUAL EXPIRY DATE DOES NOT WORK FOR MONTHLY ACCRUAL --------- 
----------------- 
-------------------------------------------------------- 
----------------- 
-------------------------------------------------------- 
------------------------------------------------------------------------- 
  select  NVL(TO_NUMBER(TO_CHAR(ACCRUAL_EXPIRY_DATE,'mm')),13)                                                                    ACCRUAL_EXPIRY_DATE 
         ,TO_NUMBER(TO_CHAR(AO.MONTH,'mm'))                                                                                       MONTH 
         ,case ACVI.AFFECT_LEAVE_BALANCE 
            when 1 then COALESCE(AECA.ENTITLED_NO_DAYS, AVPC.MAX_NO_DAYS + AVP.ENTITLED_NO_DAYS, AVP.ENTITLED_NO_DAYS)                           
            else 0  
          end                                                                                                                     ENTITLEMENT 
         ,case ACVI.AFFECT_LEAVE_BALANCE 
            when 1 then COALESCE(AECA.MAX_NO_DAYS, AVPC.MAX_NO_DAYS, AVP.MAX_NO_DAYS)                           
            else 0  
          end                                                                                                                     MAX_ENTITLEMENT 
         ,NVL(AO.AMOUNT_ADDED,0)                                                                                                  AMOUNT_ADDED 
         ,case ACVI.AFFECT_LEAVE_BALANCE 
            when 1 then GET_EMP_RATE_PER_MONTH(P_EMAIL => AO.EMP_EMAIL, P_AA_COUNTRY_VP_INT_ID => AO.AA_COUNTRY_VP_INT_ID, P_DATE => AO.MONTH)   
            else 0 
          end RATE_PER_MONTH 
         ,AVP.MONTHLY_ACCRUAL 
         ,AO.MONTH 
         ,AO.AA_COUNTRY_VP_INT_ID 
         ,AO.EMP_EMAIL 
    into V_ACCRUAL_EXPIRY_DATE 
        ,V_MONTH 
        ,V_ENTITLEMENT 
        ,V_MAX_ENTITLEMENT 
        ,V_AMOUNT_ADDED 
        ,V_RATE_PER_MONTH 
        ,V_MONTHLY_ACCRUAL 
        ,V_MONTH_DATE 
        ,V_AA_COUNTRY_VP_INT_ID 
        ,V_EMP_EMAIL 
    from AA_OVERVIEW AO 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AO.AA_COUNTRY_VP_INT_ID 
    join AA_VACATION_PLANS AVP on AVP.AA_VACATION_PLAN_ID = ACVI.AA_VACATION_PLAN_ID 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AO.EMP_EMAIL 
    left join AA_VACATION_PLAN_CAPS AVPC on (AVPC.AA_COUNTRY_VP_INT_ID = ACVI.AA_COUNTRY_VP_INT_ID and ROUND(MONTHS_BETWEEN(TRUNC(NVL(AO.month,TRUNC(sysdate))),TRUNC(AE.START_DATE)) + NVL(AE.TENURE_BEFORE_ORACLE_MONTHS,0)) between AVPC.TEN_STATRT and AVPC.TEN_END) 
    left join AA_EMP_CUST_ACCRUAL AECA on (AECA.EMP_EMAIL = AE.EMP_EMAIL 
                                            and TRUNC(AO.MONTH,'mm') between TRUNC(AECA.BEGIN_DATE,'mm') and NVL(LAST_DAY(TRUNC(AECA.END_DATE,'mm')), TO_DATE('01.01.4076','dd.mm.yyyy')) 
                                          ) 
    where AA_OVERVIEW_ID = P_AA_OVERVIEW_ID; 
 
  GET_BEGIN_END_DATES( 
    P_EMP_EMAIL             => V_EMP_EMAIL 
   ,P_DATE                  => V_MONTH_DATE 
   ,P_AA_COUNTRY_VP_INT_ID  => V_AA_COUNTRY_VP_INT_ID 
   ,P_BEGIN_DATE            => V_BEGIN_DATE 
   ,P_END_DATE              => V_END_DATE 
  ); 
 
  V_CURRENT_BALANCE := P_NEW_LEAVE_BALANCE; 
 
-- Get the employee's entitlement for the current year 
  V_CUR_ENTITLEMENT := GET_EMP_RATE_PER_MONTH( 
                         P_EMAIL => V_EMP_EMAIL 
                        ,P_AA_COUNTRY_VP_INT_ID => V_AA_COUNTRY_VP_INT_ID 
                        ,P_DATE => V_BEGIN_DATE 
                      ); 
  SELECT COUNT(*) INTO v_exempted_count FROM AA_EXEMPTED_EMP
   WHERE emp_email = V_EMP_EMAIL;                    
 bhu_logs(667,'log6667'||systimestamp,V_MAX_ENTITLEMENT||'-'||V_CURRENT_BALANCE||'-'||P_AA_OVERVIEW_ID ||'-'||P_NEW_LEAVE_BALANCE||' '||V_CUR_ENTITLEMENT||' '||V_MONTH||' '||V_ACCRUAL_EXPIRY_DATE);
  -- Accrual expiry date 
  if V_ACCRUAL_EXPIRY_DATE = V_MONTH  and V_MONTHLY_ACCRUAL = 0 then 
  -- Accrual + Monthly entitlement is greater than the Entitlement 
  -- This means the employee has carryover days 
    if V_CURRENT_BALANCE > V_CUR_ENTITLEMENT then -- The begin month of the employee 
    -- Remove the carryover 
    bhu_logs(668,'log668'||systimestamp,'V_CUR_ENTITLEMENT');
    IF v_exempted_count > 0 THEN
      V_RETURN := V_RATE_PER_MONTH;
    ELSE
      V_RETURN := V_CUR_ENTITLEMENT - V_CURRENT_BALANCE; 
    END IF;
    else 
    bhu_logs(669,'log669'||systimestamp,'V_RATE_PER_MONTH');
    -- Return the rate per month 
      V_RETURN := V_RATE_PER_MONTH; 
    end if; 
 
  else 
  -- Any other month except expirty date 
  -- If the rate per month would go over MAX Entitlement 
    if V_MAX_ENTITLEMENT <= V_CURRENT_BALANCE + V_RATE_PER_MONTH then 
    bhu_logs(670,'log670'||systimestamp,TO_CHAR(V_MAX_ENTITLEMENT)||'-'|| TO_CHAR(V_CURRENT_BALANCE)||'-'||P_AA_OVERVIEW_ID ||'-'||P_NEW_LEAVE_BALANCE );
    -- Return the difference to max entitlement 
      V_RETURN := V_MAX_ENTITLEMENT - V_CURRENT_BALANCE; 
    else 
    bhu_logs(671,'log671'||systimestamp,'V_RATE_PER_MONTH');
    -- Return the rate per month 
      V_RETURN := V_RATE_PER_MONTH; 
    end if; 
 
  end if; 
 
  return V_RETURN; 
 
end GET_AMOUNT_TO_ADD; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            update_amount_added 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     If the parameter is greater than 0 it updates the row with the value 
-- 
--***************************************** 
procedure UPDATE_AMOUNT_ADDED(P_AA_OVERVIEW_ID number, P_AMOUNT_TO_ADD number) 
is 
 
begin 
 
  update AA_OVERVIEW 
  set AMOUNT_ADDED = NVL(AMOUNT_ADDED,0) + NVL(P_AMOUNT_TO_ADD,0) 
  where AA_OVERVIEW_ID = P_AA_OVERVIEW_ID; 
 
end UPDATE_AMOUNT_ADDED; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            get_future_emp_leave_balance 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns an employee's leave balance for a specific month 
-- 
--***************************************** 
function GET_FUTURE_EMP_LEAVE_BALANCE(P_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number) 
return number 
is 
 
  V_LEAVE_BALANCE number; 
 
  V_APPROVED      AA_REQUESTS.AA_STATUS_ID%type; 
 
begin 
-- Initialize parameters 
  V_APPROVED := 2; 
 
-- Get the current Leave Balance 
  select ROUND(LEAVE_BALANCE,2) 
    into V_LEAVE_BALANCE 
    from AA_OVERVIEW 
    where EMP_EMAIL = UPPER(P_EMAIL) 
    and TO_CHAR(month,'mm.yy') = TO_CHAR(P_MONTH,'mm.yy') 
    and AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
      --or to_char(month,'mm.yy') = to_char(add_months(p_month,1),'mm.yy'); 
 
-- Subtract any future approved leaves 
  for S1 in (select NO_WORK_DAYS_LEAVE 
              from AA_REQUESTS 
              where EMP_EMAIL = P_EMAIL 
              and TRUNC(LEAVE_START) > LAST_DAY(P_MONTH) 
              and AA_STATUS_ID = V_APPROVED 
              and AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID) 
  loop 
 
    V_LEAVE_BALANCE := V_LEAVE_BALANCE - S1.NO_WORK_DAYS_LEAVE; 
 
  end loop; 
 
  return V_LEAVE_BALANCE; 
 
 
  EXCEPTION 
    when NO_DATA_FOUND 
      --then raise_application_error(-20005, p_month||' is not a valid month for '||p_email); 
      then return -999; 
 
end GET_FUTURE_EMP_LEAVE_BALANCE; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            get_emp_leave_balance 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns an employee's leave balance for a specific month 
-- 
--***************************************** 
function GET_EMP_LEAVE_BALANCE(P_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number) 
return number 
is 
 
  V_LEAVE_BALANCE number; 
 
begin 
 
  select ROUND(AO.LEAVE_BALANCE,2) 
    into V_LEAVE_BALANCE 
    from AA_OVERVIEW AO 
    where AO.EMP_EMAIL = UPPER(P_EMAIL) 
    and TO_CHAR(AO.month,'mm.yy') = TO_CHAR(P_MONTH,'mm.yy') 
    and AO.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
      --or to_char(month,'mm.yy') = to_char(add_months(p_month,1),'mm.yy'); 
 
  return V_LEAVE_BALANCE; 
 
 
  EXCEPTION 
    when NO_DATA_FOUND 
      --then raise_application_error(-20005, p_month||' is not a valid month for '||p_email); 
      then return -999; 
 
end GET_EMP_LEAVE_BALANCE; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            get_emp_leave_balance 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns an employee's leave balance for a specific month 
-- 
--***************************************** 
function GET_EMP_LEAVE_BALANCE(P_EMAIL varchar2, P_MONTH date, P_AA_REQUEST_ID number) 
return number 
is 
 
  V_LEAVE_BALANCE number; 
 
begin 
 
  select ROUND(LEAVE_BALANCE,2) 
    into V_LEAVE_BALANCE 
    from AA_OVERVIEW 
    where EMP_EMAIL = UPPER(P_EMAIL) 
    and TO_CHAR(month,'mm.yy') = TO_CHAR(P_MONTH,'mm.yy') 
    and AA_COUNTRY_VP_INT_ID = (select AA_COUNTRY_VP_INT_ID 
                                  from AA_REQUESTS 
                                  where AA_REQUEST_ID = P_AA_REQUEST_ID); 
      --or to_char(month,'mm.yy') = to_char(add_months(p_month,1),'mm.yy'); 
 
  return V_LEAVE_BALANCE; 
 
 
  EXCEPTION 
    when NO_DATA_FOUND 
      --then raise_application_error(-20005, p_month||' is not a valid month for '||p_email); 
      then return -999; 
 
end GET_EMP_LEAVE_BALANCE; 
 
 
 
 
--***************************************** 
-- 
-- Name:            update_leave_balance 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Updates an employee's leave_balance for the given request 
-- 
--***************************************** 
procedure UPDATE_LEAVE_BALANCE(P_REQUEST_ID number, P_WHO varchar2) 
is 
 
  V_OVERVIEW_ID               AA_OVERVIEW.AA_OVERVIEW_ID%type; 
  V_EMP_EMAIL                 AA_REQUESTS.EMP_EMAIL%type; 
  V_LEAVE_END                 AA_REQUESTS.LEAVE_END%type; 
  V_NEW_LEAVE_BALANCE         AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_LEAVE_TAKEN               AA_REQUESTS.NO_WORK_DAYS_LEAVE%type; 
  V_STATUS_ID                 AA_REQUESTS.AA_STATUS_ID%type; 
  V_AMOUNT_ADDED              AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_LAST_YEAR_LEAVE_BALANCE   AA_OVERVIEW.LAST_YEAR_LEAVE_BALANCE%type; 
  V_AA_COUNTRY_VP_INT_ID      AA_REQUESTS.AA_COUNTRY_VP_INT_ID%type; 
 
begin 
 
-- Select the necessary information from the request table 
 
-- If AFFECT_LEAVE_BALANCE = 0 then the balance is always going to be 0 
-- If AFFECT_LEAVE_BALANCE = 1 we subtract the number of leave days from the current balance to calculate the new leave balance 
  select AR.EMP_EMAIL 
        ,AR.LEAVE_END 
        ,case ACVI.AFFECT_LEAVE_BALANCE 
          when 0 then 0 
          when 1 then (GET_EMP_LEAVE_BALANCE(P_EMAIL                => AR.EMP_EMAIL 
                                            ,P_MONTH                => AR.LEAVE_END 
                                            ,P_AA_COUNTRY_VP_INT_ID => AR.AA_COUNTRY_VP_INT_ID) - AR.NO_WORK_DAYS_LEAVE) 
        end NEW_LEAVE_BALANCE 
        ,AR.NO_WORK_DAYS_LEAVE 
        ,AR.AA_STATUS_ID 
        ,AR.AA_COUNTRY_VP_INT_ID 
 
    into V_EMP_EMAIL 
        ,V_LEAVE_END 
        ,V_NEW_LEAVE_BALANCE 
        ,V_LEAVE_TAKEN 
        ,V_STATUS_ID 
        ,V_AA_COUNTRY_VP_INT_ID 
    from AA_REQUESTS AR 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AR.AA_COUNTRY_VP_INT_ID 
    where AR.AA_REQUEST_ID = P_REQUEST_ID; 
 
  if V_STATUS_ID = 2 -- Approved 
    then 
 
    -- Select the month that is going to be updated 
      select AA_OVERVIEW_ID, LAST_YEAR_LEAVE_BALANCE 
      into V_OVERVIEW_ID, V_LAST_YEAR_LEAVE_BALANCE 
      from AA_OVERVIEW 
      where EMP_EMAIL = V_EMP_EMAIL 
      and TO_CHAR(month,'mm.yy') = TO_CHAR(V_LEAVE_END,'mm.yy') 
      and AA_COUNTRY_VP_INT_ID = V_AA_COUNTRY_VP_INT_ID; 
 
    -- Daca amount_added este null verifica daca nu trebuie adaugat 
    -- The new Balance is equal with the sum between the New Balance and the Amount that should be added to each month 
      /*v_amount_added := get_amount_to_add(v_overview_id,v_new_leave_balance); 
      v_new_leave_balance := v_new_leave_balance + v_amount_added;*/ 
 
   -- Check to see if we have days from the previous year and substract from them if we have 
      if V_LAST_YEAR_LEAVE_BALANCE - V_LEAVE_TAKEN > 0 
        then 
          V_LAST_YEAR_LEAVE_BALANCE := V_LAST_YEAR_LEAVE_BALANCE - V_LEAVE_TAKEN; 
      else 
        V_LAST_YEAR_LEAVE_BALANCE := 0; 
      end if; 
 
--      V_AMOUNT_ADDED := GET_AMOUNT_TO_ADD(V_OVERVIEW_ID, V_NEW_LEAVE_BALANCE); 
      bhu_logs(666,'log6666'||systimestamp,V_OVERVIEW_ID ||' '||V_NEW_LEAVE_BALANCE);
      update AA_OVERVIEW 
      set LEAVE_BALANCE = V_NEW_LEAVE_BALANCE, LEAVE_TAKEN = LEAVE_TAKEN + V_LEAVE_TAKEN, LAST_YEAR_LEAVE_BALANCE = V_LAST_YEAR_LEAVE_BALANCE 
      where AA_OVERVIEW_ID = V_OVERVIEW_ID; 
 
-- Update the amount added. If the value of v_amount_added is greater then 0 it will update, otherwise it will do nothing 
-- THe amount added is set in the REDO_BALANCE procedure 
--      UPDATE_AMOUNT_ADDED(V_OVERVIEW_ID,V_AMOUNT_ADDED); 
 
  end if; 
 
end UPDATE_LEAVE_BALANCE; 
 
 
 
 
--***************************************** 
-- 
-- Name:            update_leave_balance 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Updates an employee's leave_balance for the given request 
-- 
--***************************************** 
procedure UPDATE_LEAVE_BALANCE(P_REQUEST_ID number, P_WHO varchar2, P_NEW_BALANCE out number) 
is 
 
  V_OVERVIEW_ID               AA_OVERVIEW.AA_OVERVIEW_ID%type; 
  V_EMP_EMAIL                 AA_REQUESTS.EMP_EMAIL%type; 
  V_LEAVE_END                 AA_REQUESTS.LEAVE_END%type; 
  V_NEW_LEAVE_BALANCE         AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_LEAVE_TAKEN               AA_REQUESTS.NO_WORK_DAYS_LEAVE%type; 
  V_STATUS_ID                 AA_REQUESTS.AA_STATUS_ID%type; 
  V_AMOUNT_ADDED              AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_LAST_YEAR_LEAVE_BALANCE   AA_OVERVIEW.LAST_YEAR_LEAVE_BALANCE%type; 
  V_AA_COUNTRY_VP_INT_ID      AA_REQUESTS.AA_COUNTRY_VP_INT_ID%type; 
 
begin 
 
-- Select the necessary information from the request table 
 
-- If AFFECT_LEAVE_BALANCE = 0 then the balance is always going to be 0 
-- If AFFECT_LEAVE_BALANCE = 1 we subtract the number of leave days from the current balance to calculate the new leave balance 
  select AR.EMP_EMAIL 
        ,AR.LEAVE_END 
        ,case ACVI.AFFECT_LEAVE_BALANCE 
          when 0 then 0 
          when 1 then (GET_EMP_LEAVE_BALANCE(P_EMAIL                => AR.EMP_EMAIL 
                                            ,P_MONTH                => AR.LEAVE_END 
                                            ,P_AA_COUNTRY_VP_INT_ID => AR.AA_COUNTRY_VP_INT_ID) - AR.NO_WORK_DAYS_LEAVE) 
        end NEW_LEAVE_BALANCE 
        ,AR.NO_WORK_DAYS_LEAVE 
        ,AR.AA_STATUS_ID 
        ,AR.AA_COUNTRY_VP_INT_ID 
 
    into V_EMP_EMAIL 
        ,V_LEAVE_END 
        ,V_NEW_LEAVE_BALANCE 
        ,V_LEAVE_TAKEN 
        ,V_STATUS_ID 
        ,V_AA_COUNTRY_VP_INT_ID 
    from AA_REQUESTS AR 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AR.AA_COUNTRY_VP_INT_ID 
    where AR.AA_REQUEST_ID = P_REQUEST_ID; 
 
  if V_STATUS_ID = 2 -- Approved 
    then 
 
    -- Select the month that is going to be updated 
      select AA_OVERVIEW_ID, LAST_YEAR_LEAVE_BALANCE 
      into V_OVERVIEW_ID, V_LAST_YEAR_LEAVE_BALANCE 
      from AA_OVERVIEW 
      where EMP_EMAIL = V_EMP_EMAIL 
      and TO_CHAR(month,'mm.yy') = TO_CHAR(V_LEAVE_END,'mm.yy') 
      and AA_COUNTRY_VP_INT_ID = V_AA_COUNTRY_VP_INT_ID; 
 
    -- Daca amount_added este null verifica daca nu trebuie adaugat 
    -- The new Balance is equal with the sum between the New Balance and the Amount that should be added to each month 
      /*v_amount_added := get_amount_to_add(v_overview_id,v_new_leave_balance); 
      v_new_leave_balance := v_new_leave_balance + v_amount_added;*/ 
 
   -- Check to see if we have days from the previous year and substract from them if we have 
      if V_LAST_YEAR_LEAVE_BALANCE - V_LEAVE_TAKEN > 0 
        then 
          V_LAST_YEAR_LEAVE_BALANCE := V_LAST_YEAR_LEAVE_BALANCE - V_LEAVE_TAKEN; 
      else 
        V_LAST_YEAR_LEAVE_BALANCE := 0; 
      end if; 
 
--      V_AMOUNT_ADDED := GET_AMOUNT_TO_ADD(V_OVERVIEW_ID, V_NEW_LEAVE_BALANCE); 
 
      update AA_OVERVIEW 
      set LEAVE_BALANCE = V_NEW_LEAVE_BALANCE, LEAVE_TAKEN = LEAVE_TAKEN + V_LEAVE_TAKEN, LAST_YEAR_LEAVE_BALANCE = V_LAST_YEAR_LEAVE_BALANCE 
      where AA_OVERVIEW_ID = V_OVERVIEW_ID; 
 
-- Update the amount added. If the value of v_amount_added is greater then 0 it will update, otherwise it will do nothing 
-- THe amount added is set in the REDO_BALANCE procedure 
--      UPDATE_AMOUNT_ADDED(V_OVERVIEW_ID,V_AMOUNT_ADDED); 
 
  -- Return the new balance 
    P_NEW_BALANCE := V_NEW_LEAVE_BALANCE; 
 
  end if; 
 
end UPDATE_LEAVE_BALANCE; 
 
 
 
 
-- --***************************************** 
-- -- 
-- -- Name:            GET_TERMINATION_REDO_BALANCE 
-- -- Type:            Procedure 
-- -- Creation date:   25-Sep-2017 
-- -- Created by:      Alexandru Banu 
-- -- Description:     Return the date of the redo balance in case of termination 
-- -- 
-- --***************************************** 
-- function GET_TERMINATION_REDO_BALANCE( 
--   P_EMP_EMAIL AA_EMPLOYEES.EMP_EMAIL%type 
--  ,P_DATE      AA_OVERVIEW.month%type 
-- ) 
-- return date 
-- is 
-- 
--   V_RET_DATE AA_OVERVIEW.month%type; 
-- 
-- begin 
-- -- If the employee is in a country that has a monthly accrual, return the first day of the termination date 
-- -- If the employee is in a country that has a monthly accrual, return the begining date of the vacation plan 
--   select case AVP.MONTHLY_ACCRUAL 
--           when 1 then trunc(P_DATE,'mm') 
--           when 0 then to_date(TO_CHAR(AVP.YEAR_BEGIN_DATE,'dd-mon')||'-'||TO_CHAR(P_DATE,'yyyy'),'dd-mon-yyyy') 
--         end REDO_DATE 
-- 
--     into V_RET_DATE 
--     from AA_EMPLOYEES AE 
--     join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
--     join AA_VACATION_PLANS AVP on AVP.AA_VACATION_PLAN_ID = ACVI.AA_VACATION_PLAN_ID 
--     where AE.EMP_EMAIL = upper(P_EMP_EMAIL); 
-- 
--   return V_RET_DATE; 
-- 
-- end GET_TERMINATION_REDO_BALANCE; 
 
 
 
 
-- --***************************************** 
-- -- 
-- -- Name:            GET_PREV_LEAVE_BALANCE 
-- -- Type:            Procedure 
-- -- Creation date:   25-Sep-2017 
-- -- Created by:      Alexandru Banu 
-- -- Description:     Return the date of the redo balance in case of termination 
-- -- 
-- --***************************************** 
function GET_PREV_LEAVE_BALANCE( 
  P_EMP_EMAIL             AA_OVERVIEW.EMP_EMAIL%type 
 ,P_AA_COUNTRY_VP_INT_ID  AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type 
) 
return AA_OVERVIEW.LEAVE_BALANCE%type 
is 
 
  V_LEAVE_BALANCE               AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_PREV_AA_COUNTRY_VP_INT_ID   AA_COUNTRY_VP_INT.PREV_AA_COUNTRY_VP_INT_ID%type; 
 
begin 
-- Function that uses regresion to check all the previous AA_COUNTRY_VP_INT_IDs until one is found for the employee 
-- If none is found then return null 
  select LEAVE_BALANCE 
        ,PREV_AA_COUNTRY_VP_INT_ID 
    into V_LEAVE_BALANCE 
        ,V_PREV_AA_COUNTRY_VP_INT_ID 
    from AA_COUNTRY_VP_INT ACVI 
    left join AA_OVERVIEW AO on AO.AA_COUNTRY_VP_INT_ID = ACVI.AA_COUNTRY_VP_INT_ID 
                            and AO.EMP_EMAIL = P_EMP_EMAIL 
    where ACVI.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
    order by MONTH desc 
    fetch first 1 rows only; 
 
  if V_LEAVE_BALANCE is null then 
 
    if V_PREV_AA_COUNTRY_VP_INT_ID is not null then 
      return GET_PREV_LEAVE_BALANCE(P_EMP_EMAIL => P_EMP_EMAIL, P_AA_COUNTRY_VP_INT_ID => V_PREV_AA_COUNTRY_VP_INT_ID); 
    else 
      return 0; 
    end if; 
 
  else 
 
    return V_LEAVE_BALANCE; 
 
  end if; 
 
end GET_PREV_LEAVE_BALANCE; 
 
 
 
 
-- --***************************************** 
-- -- 
-- -- Name:            GET_PREV_LEAVE_BALANCE 
-- -- Type:            Procedure 
-- -- Creation date:   25-Sep-2017 
-- -- Created by:      Alexandru Banu 
-- -- Description:     Return the date of the redo balance in case of termination 
-- -- 
-- --***************************************** 
function GET_PREV_AA_COUNTRY_VP_INT_ID( 
  P_EMP_EMAIL             AA_OVERVIEW.EMP_EMAIL%type 
 ,P_AA_COUNTRY_VP_INT_ID  AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type 
) 
return AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type 
is 
 
  V_LEAVE_BALANCE               AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_PREV_AA_COUNTRY_VP_INT_ID   AA_COUNTRY_VP_INT.PREV_AA_COUNTRY_VP_INT_ID%type; 
 
begin 
-- Function that uses regresion to check all the previous AA_COUNTRY_VP_INT_IDs until one is found for the employee 
-- If none is found then return null 
  select LEAVE_BALANCE 
        ,PREV_AA_COUNTRY_VP_INT_ID 
    into V_LEAVE_BALANCE 
        ,V_PREV_AA_COUNTRY_VP_INT_ID 
    from AA_COUNTRY_VP_INT ACVI 
    left join AA_OVERVIEW AO on AO.AA_COUNTRY_VP_INT_ID = ACVI.AA_COUNTRY_VP_INT_ID 
                            and AO.EMP_EMAIL = P_EMP_EMAIL 
    where ACVI.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
    order by MONTH desc 
    fetch first 1 rows only; 
 
  if V_LEAVE_BALANCE is null then 
 
    if V_PREV_AA_COUNTRY_VP_INT_ID is not null then 
      return GET_PREV_AA_COUNTRY_VP_INT_ID(P_EMP_EMAIL => P_EMP_EMAIL, P_AA_COUNTRY_VP_INT_ID => V_PREV_AA_COUNTRY_VP_INT_ID); 
    else 
      return P_AA_COUNTRY_VP_INT_ID; 
    end if; 
 
  else 
 
    return P_AA_COUNTRY_VP_INT_ID; 
 
  end if; 
 
end GET_PREV_AA_COUNTRY_VP_INT_ID; 
 
 
 
 
 
-- --***************************************** 
-- -- 
-- -- Name:            GET_EMP_CARRYOVER 
-- -- Type:            Function 
-- -- Creation date:   30-Jan-2019 
-- -- Created by:      Alexandru Banu 
-- -- Description:     Get the carryover for an employee 
-- -- 
-- --***************************************** 
function GET_EMP_CARRYOVER( 
  P_EMAIL                 in  AA_EMPLOYEES.EMP_EMAIL%type 
 ,P_DATE                  in  AA_COUNTRY_VP_INT.BEGIN_DATE%type 
 ,P_AA_COUNTRY_VP_INT_ID  in  AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type 
) 
return number 
is 
 
  V_ENTITLED_NO_DAYS number; 
  V_MAX_NO_DAYS      number; 
 
begin 
 
  select NVL(AECA.ENTITLED_NO_DAYS, AVP.ENTITLED_NO_DAYS) + NVL(AVPC.ADDITIONAL_ACCRUAL,0) 
        ,NVL(AVPC.MAX_NO_DAYS,0) + NVL(AECA.MAX_NO_DAYS, NVL(AVP.MAX_NO_DAYS,0)) 
    into V_ENTITLED_NO_DAYS 
        ,V_MAX_NO_DAYS 
 
    from AA_EMPLOYEES AE 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
    join AA_VACATION_PLANS AVP on AVP.AA_VACATION_PLAN_ID = ACVI.AA_VACATION_PLAN_ID 
    left join AA_VACATION_PLAN_CAPS AVPC on (AVPC.AA_COUNTRY_VP_INT_ID = ACVI.AA_COUNTRY_VP_INT_ID 
                                              and ROUND(MONTHS_BETWEEN(TRUNC(NVL(P_DATE,TRUNC(SYSDATE))),TRUNC(AE.START_DATE)) + NVL(AE.TENURE_BEFORE_ORACLE_MONTHS,0)) between AVPC.TEN_STATRT and AVPC.TEN_END 
                                            ) 
    left join AA_EMP_CUST_ACCRUAL AECA on (AECA.EMP_EMAIL = AE.EMP_EMAIL 
                                            and TRUNC(P_DATE,'mm') between TRUNC(AECA.BEGIN_DATE,'mm') and NVL(LAST_DAY(TRUNC(AECA.END_DATE,'mm')), TO_DATE('01.01.4076','dd.mm.yyyy')) 
                                          ) 
    left join AA_OVERVIEW AO on AO.EMP_EMAIL = AE.EMP_EMAIL 
                            and trunc(AO.MONTH,'mm') = trunc(P_DATE,'mm') 
                            and AO.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
    where AE.EMP_EMAIL = P_EMAIL 
    and ACVI.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
    return V_MAX_NO_DAYS - V_ENTITLED_NO_DAYS; 
 
end GET_EMP_CARRYOVER; 
 
 
 
 
 
 
 
-- --***************************************** 
-- 
-- Name:            redo_balance_all 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Redoes the leave balance for all the vacation plans 
-- 
--***************************************** 
procedure REDO_BALANCE_ALL(P_EMAIL varchar2, P_MONTH date) 
is 
 
begin 
 
  for S1 in (select ACVI.AA_COUNTRY_VP_INT_ID 
              from AA_EMPLOYEES AE 
              join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
              where AE.EMP_EMAIL = P_EMAIL 
              order by BEGIN_DATE) 
  LOOP 
    bhu_logs(600,'log600'||systimestamp,P_EMAIL ||' '||P_MONTH||' '||S1.AA_COUNTRY_VP_INT_ID);

    REDO_BALANCE( 
      P_EMAIL                 => P_EMAIL 
     ,P_MONTH                 => P_MONTH 
     ,P_AA_COUNTRY_VP_INT_ID  => S1.AA_COUNTRY_VP_INT_ID 
    ); 
 
  end LOOP; 
 
end REDO_BALANCE_ALL; 
 
 
 
 
--***************************************** 
-- 
-- Name:            redo_balance 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Redoes the leave balance starting with the supplied month ntil the present one 
-- 
--***************************************** 
procedure REDO_BALANCE(P_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number default null) 
is 
 
  V_COUNT                     number := 0; 
  V_NEW_BALANCE               number; 
  V_CARRYOVER                 number; 
  V_LEAVE_BALANCE             AA_OVERVIEW.LEAVE_TAKEN%type; 
  V_OVERVIEW_ID               AA_OVERVIEW.AA_OVERVIEW_ID%type; 
 
  V_AMOUNT_TO_ADD             AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_AMOUNT_TO_ADD_2           AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_LAST_YEAR_LEAVE_BALANCE   AA_OVERVIEW.LAST_YEAR_LEAVE_BALANCE%type; 
 
  V_RATE_PER_MONTH            AA_VACATION_PLANS.RATE_PER_MONTH%type; 
  V_PREV_AA_COUNTRY_VP_INT_ID AA_COUNTRY_VP_INT.PREV_AA_COUNTRY_VP_INT_ID%type; 
 
  V_BEGIN_DATE                AA_OVERVIEW.MONTH%type; 
  V_END_DATE                  AA_OVERVIEW.MONTH%type; 
 
begin 
 
-- Loop through all the months from p_month - 1 until the last one in ascending order 
    
  for X in (select AO.AA_OVERVIEW_ID 
                  ,AO.ACCRUED 
                  ,AO.LEAVE_TAKEN 
                  ,AO.LEAVE_BALANCE 
                  ,AO.month 
                  ,AO.START_MONTH 
                  ,case when trunc(AE.START_DATE, 'mm')-1 = AO.MONTH and AO.START_MONTH = 1 then null else ACVI.PREV_AA_COUNTRY_VP_INT_ID end PREV_AA_COUNTRY_VP_INT_ID 
                  ,AO.AA_COUNTRY_VP_INT_ID 
                  ,AE.END_DATE  EMP_TERMINATION_DATE 
                  ,ACVI.PRORATE 
                  ,AVP.MONTHLY_ACCRUAL 
            from AA_OVERVIEW AO 
            join AA_EMPLOYEES AE on AE.EMP_EMAIL = AO.EMP_EMAIL 
            left join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AO.AA_COUNTRY_VP_INT_ID 
            left join AA_VACATION_PLANS AVP on AVP.AA_VACATION_PLAN_ID = ACVI.AA_VACATION_PLAN_ID 
            where AO.EMP_EMAIL = P_EMAIL 
            and TRUNC(AO.month) >= TRUNC(ADD_MONTHS(TRUNC(P_MONTH,'mm'),-1)) 
            and AO.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
            order by AO.month asc 
            ) 
  LOOP 
  -- v_count is 0 initially and coresponds to the p_month - 1 month when we do nothing except copy the values in the variables 
  -- Redo Balance for starting months that continue another vacation plan 
      bhu_logs(601,'log601'||systimestamp,'V_COUNT'||to_char(V_COUNT)|| 'START_MONTH'||X.START_MONTH ||' PREV_AA_COUNTRY_VP_INT_ID '||X.PREV_AA_COUNTRY_VP_INT_ID||' P_MONTH '||P_MONTH);

    if X.START_MONTH = 1 and X.PREV_AA_COUNTRY_VP_INT_ID is not null then 
    -- Update the leave balance from the previous vacation plan 
      V_LEAVE_BALANCE := GET_PREV_LEAVE_BALANCE(P_EMP_EMAIL => P_EMAIL, P_AA_COUNTRY_VP_INT_ID => X.PREV_AA_COUNTRY_VP_INT_ID); 

       bhu_logs(651,'log651'||systimestamp,'V_LEAVE_BALANCE'||to_char(V_LEAVE_BALANCE) );

      update AA_OVERVIEW 
        set LEAVE_BALANCE = V_LEAVE_BALANCE 
           ,ACCRUED = V_LEAVE_BALANCE 
        where AA_OVERVIEW_ID = X.AA_OVERVIEW_ID; 
 
    -- Update all vacation requests from that moment forward to use the new vacation plan 
      update AA_REQUESTS 
        set AA_COUNTRY_VP_INT_ID = X.AA_COUNTRY_VP_INT_ID 
        where EMP_EMAIL = P_EMAIL 
        and AA_COUNTRY_VP_INT_ID = GET_PREV_AA_COUNTRY_VP_INT_ID(P_EMP_EMAIL => P_EMAIL, P_AA_COUNTRY_VP_INT_ID => X.PREV_AA_COUNTRY_VP_INT_ID) 
        and LEAVE_START > X.MONTH -- First Month should always be the last day of the previous month before joining Oracle 
        and AA_COUNTRY_VP_INT_ID != X.AA_COUNTRY_VP_INT_ID; 
 
    end if; 
  bhu_logs(652,'log652'||systimestamp,'V_COUNT'||to_char(V_COUNT) );

    if V_COUNT > 0 
      then 
      -- Set the amount_added column to null (reset the column) 
 
        update AA_OVERVIEW 
        set AMOUNT_ADDED = null 
        where AA_OVERVIEW_ID = X.AA_OVERVIEW_ID; 
 
      -- Get the amount to be added 
      -- Don't add amount to add to the second month because this is actually the first one. 
 
        V_AMOUNT_TO_ADD := GET_AMOUNT_TO_ADD(X.AA_OVERVIEW_ID, V_LEAVE_BALANCE); 
 
--        HTP.P('    V_AMOUNT_TO_ADD in REDO_BALANCE => '||V_AMOUNT_TO_ADD); 
 
      -- Update the new month with the final results of the previous months 
        if X.START_MONTH = 1 
          then 
            V_LEAVE_BALANCE := 0; 
            V_AMOUNT_TO_ADD := GET_AMOUNT_TO_ADD(X.AA_OVERVIEW_ID, 0); 
        end if; 
 
      -- Get the begin and end date of the interval 
        GET_BEGIN_END_DATES( 
          P_EMP_EMAIL             => P_EMAIL 
         ,P_DATE                  => trunc(X.MONTH) 
         ,P_AA_COUNTRY_VP_INT_ID  => P_AA_COUNTRY_VP_INT_ID 
         ,P_BEGIN_DATE            => V_BEGIN_DATE 
         ,P_END_DATE              => V_END_DATE 
        ); 
 
 
      -- Check if the employees has a termination date in the current year 
      -- And if the accrual is yearly and prorate 3 
      -- The employee will move into the new year only the carryover 
        if X.EMP_TERMINATION_DATE between  V_BEGIN_DATE and V_END_DATE 
          and X.MONTHLY_ACCRUAL = 0 
          and X.PRORATE = 2 
          and trunc(X.MONTH,'mm') = trunc(V_BEGIN_DATE,'mm') then 
 
          V_CARRYOVER := GET_EMP_CARRYOVER( 
                          P_EMAIL                 => P_EMAIL 
                         ,P_DATE                  => V_BEGIN_DATE--trunc(P_MONTH) -- HRITEMEA-464 
                         ,P_AA_COUNTRY_VP_INT_ID  => P_AA_COUNTRY_VP_INT_ID 
                        ); 
 
          -- DBMS_OUTPUT.PUT_LINE('V_CARRYOVER: '||V_CARRYOVER); 
 
          if V_LEAVE_BALANCE > V_CARRYOVER then 
            V_LEAVE_BALANCE := V_CARRYOVER; 
          end if; 
 
        -- In this case Amount to add should be calculated using the carryover value 
          V_AMOUNT_TO_ADD := GET_AMOUNT_TO_ADD(X.AA_OVERVIEW_ID, V_LEAVE_BALANCE); 
 
        end if; 
 
        update AA_OVERVIEW 
        set ACCRUED = V_LEAVE_BALANCE+V_AMOUNT_TO_ADD, LEAVE_TAKEN = 0, LEAVE_BALANCE = V_LEAVE_BALANCE + V_AMOUNT_TO_ADD, LAST_YEAR_LEAVE_BALANCE = V_LAST_YEAR_LEAVE_BALANCE 
        where AA_OVERVIEW_ID = X.AA_OVERVIEW_ID; 
          bhu_logs(653,'log653'||systimestamp,'V_COUNT'||to_char(V_COUNT) ||'V_LEAVE_BALANCE '||V_LEAVE_BALANCE ||'V_AMOUNT_TO_ADD '||V_AMOUNT_TO_ADD ||'V_LAST_YEAR_LEAVE_BALANCE '||V_LAST_YEAR_LEAVE_BALANCE  );

      -- Update the amount added. If the value of v_amount_added is greater then 0 it will update, otherwise it will do nothing 
        UPDATE_AMOUNT_ADDED(X.AA_OVERVIEW_ID,V_AMOUNT_TO_ADD); 
 
      -- Loop through all the requests in that month 
 
        for Y in (select AA_REQUEST_ID 
                    from AA_REQUESTS 
                    where EMP_EMAIL = P_EMAIL 
                    and TO_CHAR(LEAVE_END,'mm.yy') = TO_CHAR(X.month,'mm.yy') 
                    and AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
                  ) 
        LOOP 
        -- Update the balances for each request in that month 
          UPDATE_LEAVE_BALANCE(Y.AA_REQUEST_ID, C_REDO_BALANCE, V_NEW_BALANCE); 
 
        end LOOP; 
 
    -- Check if the new balance is eligible for an accrual 
        select case 
                when AVP.MONTHLY_ACCRUAL = 1 then NVL(RATE_PER_MONTH,0) 
                else 0 
               end RATE_PER_MONTH 
          into V_RATE_PER_MONTH 
          from AA_COUNTRY_VP_INT ACVI 
          join AA_VACATION_PLANS AVP on AVP.AA_VACATION_PLAN_ID = ACVI.AA_VACATION_PLAN_ID 
          where ACVI.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
        if V_AMOUNT_TO_ADD >= 0 and V_AMOUNT_TO_ADD < V_RATE_PER_MONTH and V_NEW_BALANCE is not null then 
 
        V_AMOUNT_TO_ADD := GET_AMOUNT_TO_ADD(X.AA_OVERVIEW_ID, V_NEW_BALANCE); 
        bhu_logs(691,'log691'||systimestamp,X.AA_OVERVIEW_ID||'-'||V_AMOUNT_TO_ADD ||'-'|| V_AMOUNT_TO_ADD);
          update AA_OVERVIEW 
            set LEAVE_BALANCE = LEAVE_BALANCE + V_AMOUNT_TO_ADD 
               ,AMOUNT_ADDED = AMOUNT_ADDED + V_AMOUNT_TO_ADD 
            -- set LEAVE_BALANCE = LEAVE_BALANCE 
            --    ,AMOUNT_ADDED = AMOUNT_ADDED 
            where AA_OVERVIEW_ID = X.AA_OVERVIEW_ID; 

        end if; 
 
    end if; 
 
 -- Set the variables with the values of the current month. 
 
    select LEAVE_BALANCE, AA_OVERVIEW_ID, LAST_YEAR_LEAVE_BALANCE 
    into V_LEAVE_BALANCE, V_OVERVIEW_ID, V_LAST_YEAR_LEAVE_BALANCE 
    from AA_OVERVIEW 
    where AA_OVERVIEW_ID = X.AA_OVERVIEW_ID; 
 
    V_COUNT := V_COUNT + 1; 
  -- Reset the new balance calculated after subtracting Leaves Taken 
    V_NEW_BALANCE := null; 
 
  end LOOP; 
 
end REDO_BALANCE; 
 
 
 
 
--***************************************** 
-- 
-- Name:            get_emp_rate_per_month 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Return the rate_per_month entitled to an employee 
-- 
--***************************************** 
function GET_EMP_RATE_PER_MONTH(P_EMAIL varchar2, P_AA_COUNTRY_VP_INT_ID number, P_DATE date default null) 
return number 
is 
 
  V_RATE_PER_MONTH          AA_VACATION_PLANS.RATE_PER_MONTH%type; 
  V_RATE_PER_DAY            AA_VACATION_PLANS.RATE_PER_MONTH%type; 
  V_RATE_PER_DAY_LAST_MONTH AA_VACATION_PLANS.RATE_PER_MONTH%type; 
  V_MONTHLY_ACCRUAL         AA_VACATION_PLANS.MONTHLY_ACCRUAL%type; 
  V_ENTITLED_NO_DAYS        AA_VACATION_PLANS.ENTITLED_NO_DAYS%type; 
  V_YEAR_BEGIN_DATE         AA_VACATION_PLANS.YEAR_BEGIN_DATE%type; 
  V_YEAR_END_DATE           AA_VACATION_PLANS.YEAR_END_DATE%type; 
 
  V_SUSPEND_ASSIGNMENT      AA_COUNTRY_VP_INT.SUSPEND_ASSIGNMENT%type; 
  V_PRORATE                 AA_COUNTRY_VP_INT.PRORATE%type; 
  V_AA_COUNTRY_VP_INT_ID    AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type; 
  V_ACVI_START_DATE         AA_COUNTRY_VP_INT.BEGIN_DATE%type; 
  V_ACVI_END_DATE           AA_COUNTRY_VP_INT.END_DATE%type; 
-- V_PRORATE := 0 -- the accrual is not prorated 
-- V_PRORATE := 1 -- The accrual is prorated on a monthly basis 
-- V_PRORATE := 2 -- The accrual is prorated on a daily basis 
-- V_PRORATE := 3 -- The accrual is prorated on a monthly basis rounding the result 
-- V_PRORATE := 4 -- The accrual is prorated on a monthly basis rounding the result 
 
  V_IGNORE_STARTING_BALANCE AA_COUNTRY_VP_INT.IGNORE_STARTING_BALANCE%type; 
 
  V_START_MONTH             AA_OVERVIEW.START_MONTH%type; 
 
  V_START_DATE              AA_EMPLOYEES.START_DATE%type; 
  V_END_DATE                AA_EMPLOYEES.END_DATE%type; 
  V_COUNTRY_ID              AA_EMPLOYEES.AA_COUNTRY_ID%type; 
  V_START_VAC_BALANCE       AA_EMPLOYEES.STARTING_VAC_BALANCE%type; 
 
  V_UKRAINE                 number := 20; 
  V_ARMENIA                 number := 26; 
  V_KAZAKHSTAN              number := 27; 
  V_BELARUS                 number := 30; 
  V_DAYS_IN_MONTH           number; 
  V_ENT_DAYS                number; 
  V_SA_BEGIN_DATE           date; 
  V_SA_END_DATE             date; 
  V_BEGIN_MONTH             PLS_INTEGER; 
  V_NO_MONTHS               pls_integer; 
  V_CURRENT_MONTH           pls_integer; 
  V_REMAINING_MONTHS        pls_integer; 
  V_DATE                    date; 
 
begin 
 
  V_DATE := P_DATE; 
 
-- Get the variables 
-- V_RATE_PER_MONTH = any additional accrual is added to the custom rate per month for the employee 
--                    if the employeees doesn't have a custom rate per month the country standard is going to be used 
  select  NVL(AVPC.ADDITIONAL_ACCRUAL,0) + NVL(AECA.RATE_PER_MONTH, NVL(AVP.RATE_PER_MONTH,0)) 
        ,AVP.MONTHLY_ACCRUAL 
        ,NVL(AECA.ENTITLED_NO_DAYS, AVP.ENTITLED_NO_DAYS) + NVL(AVPC.ADDITIONAL_ACCRUAL,0) 
        ,AVP.YEAR_BEGIN_DATE 
        ,AVP.YEAR_END_DATE 
        ,TO_NUMBER(TO_CHAR(AVP.YEAR_BEGIN_DATE,'mm')) 
        ,AE.START_DATE 
        ,AE.END_DATE 
        ,ACVI.SUSPEND_ASSIGNMENT 
        ,ACVI.PRORATE 
        ,AE.AA_COUNTRY_ID 
        ,AE.STARTING_VAC_BALANCE 
        ,IGNORE_STARTING_BALANCE 
        ,AO.START_MONTH 
        ,ACVI.AA_COUNTRY_VP_INT_ID 
        ,ACVI.BEGIN_DATE 
        ,ACVI.END_DATE 
 
    into V_RATE_PER_MONTH 
        ,V_MONTHLY_ACCRUAL 
        ,V_ENTITLED_NO_DAYS 
        ,V_YEAR_BEGIN_DATE 
        ,V_YEAR_END_DATE 
        ,V_BEGIN_MONTH 
        ,V_START_DATE 
        ,V_END_DATE 
        ,V_SUSPEND_ASSIGNMENT 
        ,V_PRORATE 
        ,V_COUNTRY_ID 
        ,V_START_VAC_BALANCE 
        ,V_IGNORE_STARTING_BALANCE 
        ,V_START_MONTH 
        ,V_AA_COUNTRY_VP_INT_ID 
        ,V_ACVI_START_DATE 
        ,V_ACVI_END_DATE 
 
    from AA_EMPLOYEES AE 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
    join AA_VACATION_PLANS AVP on AVP.AA_VACATION_PLAN_ID = ACVI.AA_VACATION_PLAN_ID 
    left join AA_VACATION_PLAN_CAPS AVPC on (AVPC.AA_COUNTRY_VP_INT_ID = ACVI.AA_COUNTRY_VP_INT_ID 
                                              and ROUND(MONTHS_BETWEEN(TRUNC(NVL(P_DATE,TRUNC(SYSDATE))),TRUNC(AE.START_DATE)) + NVL(AE.TENURE_BEFORE_ORACLE_MONTHS,0)) between AVPC.TEN_STATRT and AVPC.TEN_END 
                                            ) 
    left join AA_EMP_CUST_ACCRUAL AECA on (AECA.EMP_EMAIL = AE.EMP_EMAIL 
                                            and TRUNC(P_DATE,'mm') between TRUNC(AECA.BEGIN_DATE,'mm') and NVL(LAST_DAY(TRUNC(AECA.END_DATE,'mm')), TO_DATE('01.01.4076','dd.mm.yyyy')) 
                                          ) 
    left join AA_OVERVIEW AO on AO.EMP_EMAIL = AE.EMP_EMAIL 
                            and trunc(AO.MONTH,'mm') = trunc(P_DATE,'mm') 
                            and AO.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID 
    where AE.EMP_EMAIL = P_EMAIL 
    and ACVI.AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
-- BLock for countries that have a monthly accrual 
  if V_MONTHLY_ACCRUAL = 1 then 
 
    V_RATE_PER_DAY := V_RATE_PER_MONTH / EXTRACT(DAY from LAST_DAY(P_DATE)); 
 
  -- If V_PRORATE is 1 it means that we calculate the prorated value to the day 
  -- Otherwise we give the full monthly accrual 
 
    if P_DATE is not null/* and TO_CHAR(P_DATE,'dd') != '01'*/ and V_PRORATE = 1 then 
 
      if TRUNC(P_DATE) < TRUNC(V_START_DATE) and V_IGNORE_STARTING_BALANCE = 0 then 
      -- Use the starting vacation balance is the IGNORE_STARTING_BALANCE flag is set to 0 
        V_RATE_PER_MONTH := NVL(V_START_VAC_BALANCE,0); 
      else 
      -- If the period's end date is in the same month as the current month 
        if TRUNC(V_END_DATE,'mm') = TRUNC(P_DATE,'mm') then 
        -- If the period's end is in the same month as the start date 
          if trunc(V_END_DATE,'mm') = trunc(V_START_DATE,'mm') then 
          -- Calculate the number of days between start_date and end_date 
            V_DAYS_IN_MONTH := extract(day from V_END_DATE) - extract(day from V_START_DATE) + 1; 
          else 
          -- If the period's end month is not in the period's start month use the number of days in the end month 
            V_DAYS_IN_MONTH := extract(day from V_END_DATE); 
          end if; 
        else 
        -- If the period's end date is not in the same month as the current month 
        -- Calculate the number of days from the end of the current month until the current day 
          V_DAYS_IN_MONTH := extract(day from LAST_DAY(TRUNC(P_DATE))) - extract(day from P_DATE) + 1; 
        end if; 
      -- The number of days until end of month * rate per day 
        V_RATE_PER_MONTH := ROUND((V_DAYS_IN_MONTH * V_RATE_PER_DAY),2); 
      end if; 
 
    else 
    -- If prorate is not 1 then return the full Rate Per Month 
      V_RATE_PER_MONTH := V_RATE_PER_MONTH; 
    end if; 
 
  elsif V_MONTHLY_ACCRUAL = 0 then 
  -- Set Current Month as a number 
    V_CURRENT_MONTH := TO_NUMBER(TO_CHAR(P_DATE,'mm')); 
 
  -- Set V_YEAR_BEGIN_DATE 
  -- If the current month is less than the begin month we need to calculate how many months there are between today and the start of the year 
  -- else we need to add 12 to the begin_month as we passed it and then subtract the current month to find out how many months there are to 
  -- next year's begin date 
    V_YEAR_BEGIN_DATE := TO_DATE(to_char(V_YEAR_BEGIN_DATE,'dd') 
                        ||'-' 
                        ||to_char(V_YEAR_BEGIN_DATE,'Mon') 
                        ||'-' 
                        ||to_char(P_DATE,'yyyy') 
                        ,'dd-Mon-yyyy'); 
  -- If the current month is before the YEAR_BEGIN_DATE, subtract one year from YEAR_BEGIN_DATE 
  -- This applies to vacation plans that don't have the YEAR_BEGIN_DATE and YEAR_END_DATE in the same calendar year 
    if trunc(P_DATE) < V_YEAR_BEGIN_DATE then 
      V_YEAR_BEGIN_DATE := ADD_MONTHS(V_YEAR_BEGIN_DATE,-12); 
    end if; 
-- If the start date of the employee is greated than the YEAR_BEGIN_DATE of the vacation plan set it as the START_DATE 
-- As the employee started after the vacation plan's YEAR_BEGIN_DATE 
    if V_START_DATE > V_YEAR_BEGIN_DATE then 
      V_YEAR_BEGIN_DATE := trunc(V_START_DATE); 
    end if; 
-- If the vacation plan start date is greater than the YEAR_BEGIN_DATE use it 
-- As is means that the vacation plan has changed and it should be used to calculate the accrual 
    if V_ACVI_START_DATE > V_YEAR_BEGIN_DATE then 
      V_YEAR_BEGIN_DATE := V_ACVI_START_DATE; 
    end if; 
-- Calculate the YEAR_END_DATE for the vacation plan 
    V_YEAR_END_DATE := TO_DATE(to_char(V_YEAR_END_DATE,'dd') 
                        ||'-' 
                        ||to_char(V_YEAR_END_DATE,'Mon') 
                        ||'-' 
                        ||to_char(P_DATE,'yyyy') 
                        ,'dd-Mon-yyyy'); 
-- If the YEAR_BEGIN_DATE is greater than the YEAR_END_DATE add 12 months to the end 
-- This applies to vacation plans that don't have the YEAR_BEGIN_DATE and YEAR_END_DATE in the same calendar year 
    if V_YEAR_BEGIN_DATE > V_YEAR_END_DATE then 
      V_YEAR_END_DATE := ADD_MONTHS(V_YEAR_END_DATE,12); 
    end if; 
-- The YEAR_END_DATE should be the least date out of: 
-- YEAR_END_DATE, Employee's END_DATE and the vacation plan's END_DATE 
    V_YEAR_END_DATE := LEAST(V_YEAR_END_DATE, NVL(V_END_DATE,V_YEAR_END_DATE), nvl(V_ACVI_END_DATE,V_YEAR_END_DATE)); 
-- The nnumber of months used to calculate the accrual is the number of months between YEAR_END_DATE and YEAR_BEGIN_DATE 
-- The 0.01 is added to fix the calculation for dates that are on the same day of the month 
    V_REMAINING_MONTHS :=  CEIL(MONTHS_BETWEEN(V_YEAR_END_DATE,V_YEAR_BEGIN_DATE) + 0.01); 
-- Calculate the RATE_PER_DAY for the current month and for the last month for the interval 
-- These will be used to calculate prorated vacation plans on the current month 
-- and the last month of the interval(Termination Date / Year End Date / Vacation plan End Date) 
    V_RATE_PER_DAY := V_ENTITLED_NO_DAYS / 12 / EXTRACT(DAY from LAST_DAY(P_DATE)); 
    V_RATE_PER_DAY_LAST_MONTH := V_ENTITLED_NO_DAYS / 12 / EXTRACT(DAY from LAST_DAY(V_YEAR_END_DATE)); 
 
-- Calculate the RATE_PER_MONTH(accrual) for teh current month 
-- Add the accrual only on the YEAR_BEGIN_DATE(Employee Start Date / Vacation Plan Start Date / Vacation plan Year begin date - month of accrual) 
    if TO_CHAR(P_DATE,'mm yyyy') = TO_CHAR(V_YEAR_BEGIN_DATE,'mm yyyy') and V_PRORATE = 0 then 
 
      V_RATE_PER_MONTH := CEIL(ROUND((V_ENTITLED_NO_DAYS / 12) * V_REMAINING_MONTHS, 2)); 
 
    ELSIF TO_CHAR(P_DATE,'mm yyyy') = TO_CHAR(V_YEAR_BEGIN_DATE,'mm yyyy') and V_PRORATE = 1 then 
 
      V_RATE_PER_MONTH := ROUND((V_ENTITLED_NO_DAYS / 12) * V_REMAINING_MONTHS, 2); 
 
    ELSIF TO_CHAR(P_DATE,'mm yyyy') = TO_CHAR(V_YEAR_BEGIN_DATE,'mm yyyy') and V_PRORATE = 2 then 
    -- If the YEAR_BEGIN_DATE and YEAR_END_DATE are in the same month 
    -- The accrual will be only for the days between START and END 
      if trunc(V_YEAR_BEGIN_DATE,'mm') = trunc(V_YEAR_END_DATE,'mm') then 
        V_RATE_PER_MONTH := V_RATE_PER_DAY * (extract (day from V_YEAR_END_DATE) 
                                            - extract (day from V_YEAR_BEGIN_DATE) 
                                            + 1); 
 
      else 
    -- Othewise calculate the entitlement for the full months except the first and last one 
    -- and add the prorated amounts for the first and last ones (these will be prorated to the day) 
        V_RATE_PER_MONTH := ROUND( 
                              ((V_ENTITLED_NO_DAYS / 12) * (V_REMAINING_MONTHS - 2)) -- Begin and End date for interval are excluded 
                              + (V_RATE_PER_DAY * (extract (day from LAST_DAY(V_YEAR_BEGIN_DATE)) 
                                                  - extract (day from V_YEAR_BEGIN_DATE) 
                                                  + 1)) 
                              + NVL(V_RATE_PER_DAY_LAST_MONTH * extract (day from V_YEAR_END_DATE), 0) 
                              ,2 
                            ); 
      end if; 
 
    ELSIF TO_CHAR(P_DATE,'mm yyyy') = TO_CHAR(V_YEAR_BEGIN_DATE,'mm yyyy') and V_PRORATE = 3 then 
 
      V_RATE_PER_MONTH := ROUND((V_ENTITLED_NO_DAYS / 12) * V_REMAINING_MONTHS); 
 
    ELSIF TO_CHAR(P_DATE,'mm yyyy') = TO_CHAR(V_YEAR_BEGIN_DATE,'mm yyyy') and V_PRORATE = 4 then 
 
    -- If the YEAR_BEGIN_DATE and YEAR_END_DATE are in the same month 
    -- The accrual will be only for the days between START and END 
      if trunc(V_YEAR_BEGIN_DATE,'mm') = trunc(V_YEAR_END_DATE,'mm') then 
        V_RATE_PER_MONTH := ROUND(V_RATE_PER_DAY * (extract (day from V_YEAR_END_DATE) 
                                            - extract (day from V_YEAR_BEGIN_DATE) 
                                            + 1) 
                            ); 
 
      else 
    -- Othewise calculate the entitlement for the full months except the first and last one 
    -- and add the prorated amounts for the first and last ones (these will be prorated to the day) 
        V_RATE_PER_MONTH := ROUND( 
                              ((V_ENTITLED_NO_DAYS / 12) * (V_REMAINING_MONTHS - 2)) -- Begin and End date for interval are excluded 
                              + (V_RATE_PER_DAY * (extract (day from LAST_DAY(V_YEAR_BEGIN_DATE)) 
                                                  - extract (day from V_YEAR_BEGIN_DATE) 
                                                  + 1)) 
                              + NVL(V_RATE_PER_DAY_LAST_MONTH * extract (day from V_YEAR_END_DATE), 0) 
                            ); 
      end if; 
    
    ELSIF TO_CHAR(P_DATE,'mm yyyy') = TO_CHAR(V_YEAR_BEGIN_DATE,'mm yyyy') and V_PRORATE = 5 then --Added on 13-Mar-2026
 
    -- If the YEAR_BEGIN_DATE and YEAR_END_DATE are in the same month 
    -- The accrual will be only for the days between START and END 
      if trunc(V_YEAR_BEGIN_DATE,'mm') = trunc(V_YEAR_END_DATE,'mm') then 
        V_RATE_PER_MONTH := ROUND(V_RATE_PER_DAY * (extract (day from V_YEAR_END_DATE) 
                                            - extract (day from V_YEAR_BEGIN_DATE) 
                                            + 1) 
                            ,2); 
 
      else 
    -- Othewise calculate the entitlement for the full months except the first and last one 
    -- and add the prorated amounts for the first and last ones (these will be prorated to the day) 
        V_RATE_PER_MONTH := ( 
                              ROUND(((V_ENTITLED_NO_DAYS / 12) * (V_REMAINING_MONTHS - 1)),2) -- Begin and End date for interval are excluded 
                              + ROUND((V_RATE_PER_DAY * (extract (day from LAST_DAY(V_YEAR_BEGIN_DATE)) 
                                                  - extract (day from V_YEAR_BEGIN_DATE) 
                                                  + 1)),2) 
                              
                            ); 
      end if;

    ELSIF TO_CHAR(P_DATE,'mm') = TO_CHAR(V_YEAR_BEGIN_DATE,'mm') then 
 
      V_RATE_PER_MONTH := V_ENTITLED_NO_DAYS; 
 
    else 
    -- If it's not the YEAR_BEGIN_DATE the entitlement is 0 as the accrual is added once per year 
      V_RATE_PER_MONTH := 0; 
    end if; 
 
  end if; 
 
-- Get the rate for suspended assignemnt only for the countries with monthly accrual 
  if V_SUSPEND_ASSIGNMENT = 1 and V_MONTHLY_ACCRUAL = 1 then 
 
  -- Get the last Susspend Assignment 
    for S1 in (select BEGIN_DATE 
                     ,NVL(END_DATE,LAST_DAY(P_DATE)) END_DATE 
                from AA_EMP_STATUS_INT 
                where EMP_EMAIL = P_EMAIL 
                and AA_EMP_STATUS_ID = 1 
                order by BEGIN_DATE) 
    LOOP 
    -- If the date is between the first day of the month when the suspend assignment starts 
    --   and the last day of leave or the last day of the month that is passed to the function 
      if TRUNC(P_DATE) between TRUNC(S1.BEGIN_DATE,'mm') and 
         NVL(S1.END_DATE,LAST_DAY(P_DATE)) then 
 
      -- If the begin date is in this month 
        if TRUNC(P_DATE,'mm') = TRUNC(S1.BEGIN_DATE,'mm') then 
 
          V_SA_BEGIN_DATE := S1.BEGIN_DATE; 
        -- If end date is in this month use it otherwise get the last day of this month 
          if to_char(P_DATE,'mon-yyyy') = to_char(S1.END_DATE,'mon-yyyy') then 
            V_SA_END_DATE := S1.END_DATE; 
          else 
            V_SA_END_DATE := LAST_DAY(P_DATE); 
          end if; 
 
      -- If the begin date is in a previous month 
      -- And the end_date is still in the future 
        ELSIF TRUNC(P_DATE,'mm') > TRUNC(S1.BEGIN_DATE,'mm') and 
              TRUNC(P_DATE) < NVL(S1.END_DATE,TRUNC(LAST_DAY(P_DATE))) then 
        -- First day of this month 
          V_SA_BEGIN_DATE := TRUNC(P_DATE,'mm'); 
        -- If end date is in this month use it otherwise get eh last day of this month 
          if extract(month from TRUNC(P_DATE)) = extract(month from S1.END_DATE) then 
            V_SA_END_DATE := S1.END_DATE; 
          else 
            V_SA_END_DATE := LAST_DAY(P_DATE); 
          end if; 
 
        end if; 
 
        if V_SA_BEGIN_DATE is not null and 
           V_SA_END_DATE is not null then 
        -- If the suspend assignment date is after the END_DATE of the employee's record use the end_date 
          if V_SA_END_DATE > V_END_DATE then 
            V_SA_END_DATE := V_END_DATE; 
          end if; 
 
         V_RATE_PER_MONTH := V_RATE_PER_DAY * (V_DAYS_IN_MONTH/*extract(day from LAST_DAY(P_DATE))*/ 
                                                 - ( 
                                                     extract(day from V_SA_END_DATE) 
                                                     - extract(day from V_SA_BEGIN_DATE) 
                                                     + 1 
                                                   ) 
                                               ); 
        end if; 
 
      end if; 
 
    end LOOP; 
 
  end if; 
 
-- If it's not the end of the month for Ukraine we use 0 
  if V_COUNTRY_ID in (V_UKRAINE,V_ARMENIA,V_KAZAKHSTAN,V_BELARUS) and 
     TRUNC(sysdate) < LAST_DAY(P_DATE) /*and TRUNC(sysdate,'MM') = TRUNC(P_DATE,'MM')*/ then 
 
    V_RATE_PER_MONTH := 0; 
 
  end if; 
 
  return V_RATE_PER_MONTH; 
 
end GET_EMP_RATE_PER_MONTH; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            get_prev_aa_ct_vp_int_id 
-- Type:            Procedure 
-- Creation date:   14-May-2018 
-- Created by:      Alexandru Banu 
-- Description:     Get the PREV_AA_COUNTRY_VP_INT_ID 
-- 
--***************************************** 
function GET_PREV_AA_CT_VP_INT_ID( 
  P_AA_COUNTRY_VP_INT_ID AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type 
) 
return AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type 
is 
 
  V_RETURN AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type; 
 
begin 
 
  select PREV_AA_COUNTRY_VP_INT_ID 
    into V_RETURN 
    from AA_COUNTRY_VP_INT 
    where AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
  return V_RETURN; 
 
  exception 
    when NO_DATA_FOUND then 
      return null; 
 
end GET_PREV_AA_CT_VP_INT_ID; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_MAX_OVERVIEW_ID 
-- Type:            Procedure 
-- Creation date:   14-May-2018 
-- Created by:      Alexandru Banu 
-- Description:     Get the Latest AA_OVERVIEW_ID 
-- 
--***************************************** 
function GET_MAX_OVERVIEW_ID( 
  P_EMP_EMAIL             AA_OVERVIEW.EMP_EMAIL%type 
 ,P_AA_COUNTRY_VP_INT_ID  AA_OVERVIEW.AA_COUNTRY_VP_INT_ID%type 
) 
return AA_OVERVIEW.AA_OVERVIEW_ID%type 
is 
 
  V_RETURN AA_OVERVIEW.AA_OVERVIEW_ID%type; 
 
begin 
 
  select max(AA_OVERVIEW_ID) 
    into V_RETURN 
    from AA_OVERVIEW 
    where EMP_EMAIL = P_EMP_EMAIL 
    and AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
  return V_RETURN; 
 
  exception 
    when NO_DATA_FOUND then 
      return null; 
 
end GET_MAX_OVERVIEW_ID; 
 
 
 
--***************************************** 
-- 
-- Name:            new_month 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Creates a new month for a specific employee int he overview table 
-- 
--***************************************** 
procedure NEW_MONTH(P_EMAIL varchar2, 
                     P_MONTH date, 
                     P_ACCRUED number default 0, 
                     P_LEAVE_TAKEN number default 0, 
                     P_AMOUNT_ADDED number default null, 
                     P_LAST_YEAR_LEAVE_BALANCE number default 0) 
is 
 
  V_MAX_OVERVIEW              AA_OVERVIEW.AA_OVERVIEW_ID%type; 
  V_OVERVIEW_ID               AA_OVERVIEW.AA_OVERVIEW_ID%type; 
  V_LEAVE_BALANCE             AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_ACCRUED                   AA_OVERVIEW.ACCRUED%type; 
  V_MONTH                     AA_OVERVIEW.month%type; 
  V_PREV_MONTH                AA_OVERVIEW.month%type; 
  E_EXIST                     EXCEPTION; 
  V_AMOUNT_TO_ADD             AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_LAST_YEAR_LEAVE_BALANCE   AA_OVERVIEW.LAST_YEAR_LEAVE_BALANCE%type; 
  V_AMOUNT_ADDED              AA_OVERVIEW.AMOUNT_ADDED%type; 
  V_SAME_VACATION_PLAN        boolean := true; 
  --v_count_months    number; 
 
begin 
 
  V_MONTH := TRUNC(P_MONTH); -- This takes care of the time difference of the server and localtimestamp. 
                                             -- Bug when emloyee starts on the last day of the month 
 
  V_PREV_MONTH := ADD_MONTHS(LAST_DAY(TRUNC(P_MONTH/*+2*/)),-1); -- This will be used so that we have a backup for the first month of an employee 
 
-- Create the new month for all the vacation plans that a country has 
  for S1 in (select ACVI.AA_COUNTRY_VP_INT_ID 
                   ,ACVI.AFFECT_LEAVE_BALANCE 
                   ,AO.AA_OVERVIEW_ID 
               from AA_EMPLOYEES AE 
               join AA_COUNTRY_VP_INT ACVI on AE.AA_COUNTRY_ID = ACVI.AA_COUNTRY_ID 
               left join AA_OVERVIEW AO on AO.EMP_EMAIL = AE.EMP_EMAIL 
                                       and AO.AA_COUNTRY_VP_INT_ID = ACVI.AA_COUNTRY_VP_INT_ID 
                                       and AO.MONTH = P_MONTH 
               where AE.EMP_EMAIL = P_EMAIL 
               and P_MONTH between ACVI.BEGIN_DATE and NVL(ACVI.END_DATE,P_MONTH) 
            ) 
  LOOP 
     
  -- Redo the balance if the current month exists for the specific vacation plan 
    if S1.AA_OVERVIEW_ID is not null then 
      REDO_BALANCE(P_EMAIL,trunc(P_MONTH,'mm'),S1.AA_COUNTRY_VP_INT_ID); 
    else 
    -- This procedure is based on normal flow of time. It copies the info from the previous one 
    -- Check to see what is the latest row in the table for the specific employee 
 
    -- Get the last OVERVIEW_ID for the month and vacation plan 
      V_MAX_OVERVIEW := GET_MAX_OVERVIEW_ID( 
                          P_EMP_EMAIL             => P_EMAIL 
                         ,P_AA_COUNTRY_VP_INT_ID  =>  S1.AA_COUNTRY_VP_INT_ID 
                        ); 
 
      if V_MAX_OVERVIEW is null then 
        V_MAX_OVERVIEW := GET_MAX_OVERVIEW_ID( 
                            P_EMP_EMAIL             => P_EMAIL 
                           ,P_AA_COUNTRY_VP_INT_ID  => GET_PREV_AA_CT_VP_INT_ID(P_AA_COUNTRY_VP_INT_ID => S1.AA_COUNTRY_VP_INT_ID) 
                          ); 
 
        V_SAME_VACATION_PLAN := false; 
 
      end if; 
 
    -- Construct the amount to add 
      if NVL(P_AMOUNT_ADDED,0) = 0 then 
        V_AMOUNT_ADDED := GET_EMP_RATE_PER_MONTH(P_EMAIL => P_EMAIL, P_AA_COUNTRY_VP_INT_ID => S1.AA_COUNTRY_VP_INT_ID, P_DATE => V_MONTH); 
      else 
        V_AMOUNT_ADDED := P_AMOUNT_ADDED; 
      end if; 
 
 
      if V_MAX_OVERVIEW is not null then 
      -- If he has than we copy the leave_balance from the previous row and change the month 
        select LEAVE_BALANCE, GET_AMOUNT_TO_ADD(AA_OVERVIEW_ID, LEAVE_BALANCE),LAST_YEAR_LEAVE_BALANCE 
          into V_ACCRUED,V_AMOUNT_TO_ADD,V_LAST_YEAR_LEAVE_BALANCE 
          from AA_OVERVIEW 
          where AA_OVERVIEW_ID = V_MAX_OVERVIEW; 
      else 
      -- Use de defaults 
        if S1.AFFECT_LEAVE_BALANCE = 1 then 
          V_ACCRUED := NVL(P_ACCRUED, 0); 
        else 
          V_ACCRUED := 0; 
        end if; 
        V_AMOUNT_TO_ADD := 0; 
        V_LAST_YEAR_LEAVE_BALANCE := NVL(P_LAST_YEAR_LEAVE_BALANCE, 0); 
 
        V_SAME_VACATION_PLAN := false; 
 
      end if; 
 
 
      if V_SAME_VACATION_PLAN then 
 
          insert into AA_OVERVIEW (EMP_EMAIL 
                                   ,MONTH 
                                   ,ACCRUED 
                                   ,LEAVE_TAKEN 
                                   ,LEAVE_BALANCE 
                                   ,AMOUNT_ADDED 
                                   ,LAST_YEAR_LEAVE_BALANCE 
                                   ,AA_COUNTRY_VP_INT_ID) 
            values (P_EMAIL 
                   ,V_MONTH 
                   ,V_ACCRUED + V_AMOUNT_TO_ADD 
                   ,0 
                   ,V_ACCRUED + V_AMOUNT_TO_ADD 
                   ,V_AMOUNT_TO_ADD 
                   ,V_LAST_YEAR_LEAVE_BALANCE 
                   ,S1.AA_COUNTRY_VP_INT_ID); 
                    
      else 
      -- If he hasn't got a previous row we create one which defaults to 0 if the parameters aren't supplied and also fills in the previous month with the same values so that REDO_BALANCE works on this month also 
      -- If the call to the procedure contains alsi the AMOUNT_ADDED value then we update the row 
 
      -- APEX_DEBUG.ERROR('Not the same Vacation Plan'); 
 
        insert into AA_OVERVIEW (EMP_EMAIL 
                                ,MONTH 
                                ,ACCRUED 
                                ,LEAVE_TAKEN 
                                ,LEAVE_BALANCE 
                                ,AMOUNT_ADDED 
                                ,LAST_YEAR_LEAVE_BALANCE 
                                ,AA_COUNTRY_VP_INT_ID 
                                ,START_MONTH) 
          values (P_EMAIL 
                 ,V_PREV_MONTH 
                --  ,COALESCE(P_ACCRUED, V_ACCRUED, 0) 
                 ,V_ACCRUED 
                 -- ,NVL(P_ACCRUED,0)--V_AMOUNT_ADDED - V_AMOUNT_ADDED 
                 ,P_LEAVE_TAKEN 
                --  ,COALESCE(P_ACCRUED, V_ACCRUED, 0) 
                 ,V_ACCRUED 
                 -- ,NVL(P_ACCRUED,0)--V_AMOUNT_ADDED - V_AMOUNT_ADDED 
                 ,0 
                 ,P_LAST_YEAR_LEAVE_BALANCE 
                 ,S1.AA_COUNTRY_VP_INT_ID 
                 ,1); 
 
        insert into AA_OVERVIEW (EMP_EMAIL 
                                ,MONTH 
                                ,ACCRUED 
                                ,LEAVE_TAKEN 
                                ,LEAVE_BALANCE 
                                ,AMOUNT_ADDED 
                                ,LAST_YEAR_LEAVE_BALANCE 
                                ,AA_COUNTRY_VP_INT_ID) 
          values (P_EMAIL 
                 ,V_MONTH 
                 ,V_AMOUNT_ADDED 
                 ,P_LEAVE_TAKEN 
                 ,V_AMOUNT_ADDED 
                 ,0 
                 ,P_LAST_YEAR_LEAVE_BALANCE 
                 ,S1.AA_COUNTRY_VP_INT_ID); 
                  
       V_SAME_VACATION_PLAN:= true;           
          
 
      end if; 
 
    -- Redo the balance in case the employee has approved leaves in this month 
    -- Redo the balance for the previous month also 
      -- For Ukraine we need to redo the balance for the previous month also to add the entitlement at the end of the month 
      REDO_BALANCE(P_EMAIL,ADD_MONTHS(P_MONTH,-1),S1.AA_COUNTRY_VP_INT_ID); 
 
 
    end if; 
     
  end loop; 
 
  EXCEPTION 
    when E_EXIST 
      then null;--raise_application_error(-20005,v_month||' already exists for '||p_email); -- This would break the job 
 
end NEW_MONTH; 
 
 
 
 
--***************************************** 
-- 
-- Name:            approve_request 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns an employee's leave balance for a specific month 
-- 
--***************************************** 
procedure APPROVE_REQUEST(P_REQUEST_ID number) 
is 
 
  L_ID                    number; 
  V_EMP_EMAIL             T.EMAIL; 
  V_MONTH                 AA_REQUESTS.LEAVE_END%type; 
  V_AA_COUNTRY_VP_INT_ID  AA_REQUESTS.AA_COUNTRY_VP_INT_ID%type; 
  V_AA_COUNTRY_ID         AA_EMPLOYEES.AA_COUNTRY_ID%type; 
  --v_count_months    number; 
 
begin 
 
  update AA_REQUESTS 
    set AA_STATUS_ID = 2 /* Approved */, MANAGER_APPROVE = WS_TOOLS.GET_USER, APPROVE_DATE = localtimestamp 
    where AA_REQUEST_ID = P_REQUEST_ID 
    returning EMP_EMAIL,LEAVE_END,AA_COUNTRY_VP_INT_ID into V_EMP_EMAIL,V_MONTH,V_AA_COUNTRY_VP_INT_ID; 
 
-- Get the country of the employee 
  select AA_COUNTRY_ID 
    into V_AA_COUNTRY_ID 
    from AA_EMPLOYEES 
    where EMP_EMAIL = V_EMP_EMAIL; 
 
-- Check to see if the request date is in the months before the curent month 
  if LAST_DAY(TRUNC(V_MONTH)) < LAST_DAY(TRUNC(localtimestamp)) 
    then 
    -- If it is it will redo the balance starting with that month; 
      REDO_BALANCE_ALL(V_EMP_EMAIL,V_MONTH); 
  ELSIF LAST_DAY(TRUNC(V_MONTH)) > LAST_DAY(TRUNC(localtimestamp)) 
    then 
    -- If the request is for a future month don't do anything because the balance of that month will be updated once the new month is inserted 
      null; 
  else 
    -- Else it will update the month as usual 
    UPDATE_LEAVE_BALANCE(P_REQUEST_ID,C_APPROVE); 
  end if; 
 
 
-- Alert the user that his request has been approved 
  L_ID  := APEX_MAIL.SEND( 
                             P_TO => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_EMP_EMAIL else c_default_mail_list end), 
                             P_CC => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  GET_EMAIL_CC_APPROVED(V_AA_COUNTRY_ID) else c_default_mail_list end), 
                             --P_BCC => p_email_bcc, 
                             P_FROM => C_EML_FROM, 
                             P_BODY => TO_CLOB('Your leave request has been approved. Your email client doesn''t support HTML. Please use a client that does. Thank you.'), 
                             P_BODY_HTML => GET_EMPLOYEE_EMAIL(P_REQUEST_ID, C_EMP_APPROVE_ID), 
                             P_SUBJ => 'Annual Leave Request Approved'); 

  /* 
  for x in (select logo_name,logo,mime_type 
            from ment_logos 
            where ment_logo_id = 5) 
  loop 
    APEX_MAIL.ADD_ATTACHMENT( p_mail_id    => l_id, 
                              p_attachment => x.logo, 
                              p_filename   => x.logo_name, 
                              p_mime_type  => x.mime_type); 
  end loop;*/ 
  commit; 
 
  APEX_MAIL.PUSH_QUEUE('mail.oracle.com', 25); 
 
end APPROVE_REQUEST; 
 
 
 
--***************************************** 
-- 
-- Name:            approve_request 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns an employee's leave balance for a specific month 
-- 
--***************************************** 
procedure APPROVE_REQUEST_TEMP(P_REQUEST_ID number) 
is 
 
  L_ID                    number; 
  V_EMP_EMAIL             T.EMAIL; 
  V_MONTH                 AA_REQUESTS.LEAVE_END%type; 
  V_AA_COUNTRY_VP_INT_ID  AA_REQUESTS.AA_COUNTRY_VP_INT_ID%type; 
  V_AA_COUNTRY_ID         AA_EMPLOYEES.AA_COUNTRY_ID%type; 
  --v_count_months    number; 
 
begin 
 
  update AA_REQUESTS 
    set AA_STATUS_ID = 2 /* Approved */, MANAGER_APPROVE = WS_TOOLS.GET_USER, APPROVE_DATE = localtimestamp 
    where AA_REQUEST_ID = P_REQUEST_ID 
    returning EMP_EMAIL,LEAVE_END,AA_COUNTRY_VP_INT_ID into V_EMP_EMAIL,V_MONTH,V_AA_COUNTRY_VP_INT_ID; 
 
-- Get the country of the employee 
  select AA_COUNTRY_ID 
    into V_AA_COUNTRY_ID 
    from AA_EMPLOYEES 
    where EMP_EMAIL = V_EMP_EMAIL; 
 
-- Check to see if the request date is in the months before the curent month 
  if LAST_DAY(TRUNC(V_MONTH)) < LAST_DAY(TRUNC(localtimestamp)) 
    then 
    -- If it is it will redo the balance starting with that month; 
      REDO_BALANCE_ALL(V_EMP_EMAIL,V_MONTH); 
  ELSIF LAST_DAY(TRUNC(V_MONTH)) > LAST_DAY(TRUNC(localtimestamp)) 
    then 
    -- If the request is for a future month don't do anything because the balance of that month will be updated once the new month is inserted 
      null; 
  else 
    -- Else it will update the month as usual 
    UPDATE_LEAVE_BALANCE(P_REQUEST_ID,C_APPROVE); 
  end if; 
 
 

  commit; 
 
 
 
end APPROVE_REQUEST_TEMP; 
 
 
--***************************************** 
-- 
-- Name:            clear_approval 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Cleares the approval 
-- 
--***************************************** 
procedure CLEAR_APPROVAL(P_REQUEST_ID number) 
is 
 --2026.09.01 - 1.1 - Pragya Kapoor - Send notification when status is changed to Waiting Approval.  SR 180508

  V_EMP_EMAIL             T.EMAIL; 
  V_MONTH                 AA_REQUESTS.LEAVE_END%type; 
  V_STATUS                AA_REQUESTS.AA_STATUS_ID%type; 
  V_AA_COUNTRY_VP_INT_ID  AA_REQUESTS.AA_COUNTRY_VP_INT_ID%type; 
  L_ID          number;
  V_EMAIL_TO        AA_REQUESTS.EMAIL_TO%type; 
  V_EMAIL_CC       AA_REQUESTS.EMAIL_CC%type; 
  V_EMAIL_BCC        AA_REQUESTS.EMAIL_BCC%type; 
  V_EMP_NUMBER      AA_EMPLOYEES.EMP_NUMBER%type; 
  V_NO_WORK_DAYS_LEAVE NUMBER;
  V_LEAVE_START DATE;
  V_LEAVE_END DATE;
  V_EMP_COMMENTS  AA_REQUESTS.EMP_COMMENTS%type;
begin 
 
 select AA_STATUS_ID, EMP_EMAIL, LEAVE_END, AA_COUNTRY_VP_INT_ID, EMAIL_TO, EMP_NUMBER, NO_WORK_DAYS_LEAVE, LEAVE_START, LEAVE_END, EMP_COMMENTS, EMAIL_CC, EMAIL_BCC
    into V_STATUS, V_EMP_EMAIL, V_MONTH, V_AA_COUNTRY_VP_INT_ID, V_EMAIL_TO, V_EMP_NUMBER, V_NO_WORK_DAYS_LEAVE, V_LEAVE_START, V_LEAVE_END, V_EMP_COMMENTS, V_EMAIL_CC, V_EMAIL_BCC
    from AA_REQUESTS 
    where  AA_REQUEST_ID = P_REQUEST_ID; 
 
  update AA_REQUESTS 
    set MANAGER_APPROVE = null, APPROVE_DATE = null, AA_STATUS_ID = 1 
    where AA_REQUEST_ID = P_REQUEST_ID; 
 
-- If the status is APPROVED we need to redo the balance to substract the approved days 
  if V_STATUS = 2 
    then 
     REDO_BALANCE(V_EMP_EMAIL,V_MONTH,V_AA_COUNTRY_VP_INT_ID); 
  end if; 
bhu_logs(300110,'300110'||systimestamp,' V_EMAIL_TO '||V_EMAIL_TO ||'P_EMAIL_CC '||V_EMAIL_CC ||' P_EMAIL_BCC '||V_EMAIL_BCC);

  L_ID  := APEX_MAIL.SEND( 
                             P_TO => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_EMAIL_TO else c_default_mail_list end), 
                             P_CC => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_EMAIL_CC else c_default_mail_list end), 
                             P_BCC => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_EMAIL_BCC else c_default_mail_list end),
                             P_FROM => C_EML_FROM, 
                             P_BODY => TO_CLOB('Your email client doesn''t support HTML. Please use a client that does. Thank you.'), 
                             P_BODY_HTML => GET_MANAGER_EMAIL(V_EMAIL_TO, V_EMP_NUMBER, V_NO_WORK_DAYS_LEAVE, V_LEAVE_START, V_LEAVE_END, P_REQUEST_ID,V_EMP_EMAIL, V_EMP_COMMENTS), 
                             P_SUBJ => 'Approval Required: Annual Leave Template '||V_EMP_EMAIL); 
    APEX_MAIL.PUSH_QUEUE('mail.oracle.com'); 

end CLEAR_APPROVAL; 
 
 
 
--***************************************** 
-- 
-- Name:            reject_request 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Updates the status of a request to 3 - Not Approved 
-- 
--***************************************** 
procedure REJECT_REQUEST(P_REQUEST_ID number, P_COMMENTS varchar2, P_STATUS_ID number) 
is 
 
  L_ID                    number; 
  V_EMP_EMAIL             T.EMAIL; 
  V_MONTH                 AA_REQUESTS.LEAVE_END%type; 
  V_STATUS                AA_REQUESTS.AA_STATUS_ID%type; 
  V_AA_COUNTRY_VP_INT_ID  AA_REQUESTS.AA_COUNTRY_VP_INT_ID%type; 
 
begin 
 
  select AA_STATUS_ID 
        ,EMP_EMAIL 
        ,LEAVE_END 
        ,AA_COUNTRY_VP_INT_ID 
    into V_STATUS 
        ,V_EMP_EMAIL 
        ,V_MONTH 
        ,V_AA_COUNTRY_VP_INT_ID 
    from AA_REQUESTS 
    where  AA_REQUEST_ID = P_REQUEST_ID; 
 
-- Change the status to Not Approved 
  update AA_REQUESTS 
    set AA_STATUS_ID = P_STATUS_ID 
       ,MANAGER_APPROVE = WS_TOOLS.GET_USER 
       ,APPROVE_DATE = localtimestamp 
       ,COMMENTS = P_COMMENTS 
    where AA_REQUEST_ID = P_REQUEST_ID; 
 
-- If the status is APPROVED we need to redo the balance to substract the approved days 
  if V_STATUS = 2 
    then 
     REDO_BALANCE(V_EMP_EMAIL,V_MONTH,V_AA_COUNTRY_VP_INT_ID); 
  end if; 
 
  L_ID  := APEX_MAIL.SEND( 
                             P_TO => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_EMP_EMAIL else c_default_mail_list end), 
                             --P_CC => p_email_cc, 
                             --P_BCC => p_email_bcc, 
                             P_FROM => C_EML_FROM, 
                             P_BODY => TO_CLOB('Your leave request has been rejected. Your email client doesn''t support HTML. Please use a client that does. Thank you.'), 
                             P_BODY_HTML => GET_EMPLOYEE_EMAIL(P_REQUEST_ID, C_EMP_REJECTED_ID), 
                             P_SUBJ => 'Annual Leave Request Rejected'); 

  /* 
  for x in (select logo_name,logo,mime_type 
            from ment_logos 
            where ment_logo_id = 5) 
  loop 
    APEX_MAIL.ADD_ATTACHMENT( p_mail_id    => l_id, 
                              p_attachment => x.logo, 
                              p_filename   => x.logo_name, 
                              p_mime_type  => x.mime_type); 
  end loop;*/ 
  commit; 
 
  APEX_MAIL.PUSH_QUEUE('mail.oracle.com', 25); 
 
end REJECT_REQUEST; 
 
 
 
 
--***************************************** 
-- 
-- Name:            emp_cancel_request 
-- Type:            Procedure 
-- Creation date:   22-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Procedure used to cancel a request by the employee 
-- 
--***************************************** 
procedure EMP_CANCEL_REQUEST(P_REQUEST_ID number, P_EMP_EMAIL varchar2) 
is 
 
  V_TO            AA_REQUESTS.EMAIL_TO%type; 
  V_EMP_NUMBER    AA_REQUESTS.EMP_NUMBER%type; 
  V_NR_DAYS       AA_REQUESTS.NO_WORK_DAYS_LEAVE%type; 
  V_LEAVE_START   AA_REQUESTS.LEAVE_START%type; 
  V_LEAVE_END     AA_REQUESTS.LEAVE_END%type; 
  V_EMP_COMMENTS  AA_REQUESTS.EMP_COMMENTS%type; 
 
  V_COUNT       PLS_INTEGER; 
 
  E_NO_CANCEL   EXCEPTION; 
 
begin 
 
  select COUNT(*) over() 
        ,AR.EMAIL_TO 
        ,AE.EMP_NUMBER 
        ,AR.NO_WORK_DAYS_LEAVE 
        ,AR.LEAVE_START 
        ,AR.LEAVE_END 
        ,AR.EMP_COMMENTS 
    into V_COUNT 
        ,V_TO 
        ,V_EMP_NUMBER 
        ,V_NR_DAYS 
        ,V_LEAVE_START 
        ,V_LEAVE_END 
        ,V_EMP_COMMENTS 
    from AA_REQUESTS AR 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
    where AR.AA_REQUEST_ID = P_REQUEST_ID 
    and UPPER(AR.EMP_EMAIL) = UPPER(P_EMP_EMAIL) 
    and AR.AA_STATUS_ID = 1; 
 
  if V_COUNT > 0 then 
 
    update AA_REQUESTS 
      set AA_STATUS_ID = 5 -- Employee Canceled 
      where AA_REQUEST_ID = P_REQUEST_ID; 
 
  else 
 
    raise E_NO_CANCEL; 
 
  end if; 
 
 
-- Send an email notification to the manager that the employee canceled the request 
  APEX_MAIL.SEND( 
    P_TO => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_TO else c_default_mail_list end),
    --P_CC => p_email_cc, 
    --P_BCC => p_email_bcc, 
    P_FROM => C_EML_FROM, 
    P_BODY => TO_CLOB('Your leave request has been approved. Your email client doesn''t support HTML. Please use a client that does. Thank you.'), 
    P_BODY_HTML => GET_EMP_CANCELLED_EML(V_TO, V_EMP_NUMBER, V_NR_DAYS, V_LEAVE_START, V_LEAVE_END, P_REQUEST_ID,P_EMP_EMAIL, V_EMP_COMMENTS), 
    P_SUBJ => P_EMP_EMAIL||' - iVacation Rejected by Employee' 
  ); 

 
  APEX_MAIL .PUSH_QUEUE; 
 
  EXCEPTION 
    when E_NO_CANCEL then RAISE_APPLICATION_ERROR('-20004','You are not allowed to cancel this request.'); 
 
end EMP_CANCEL_REQUEST; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            get_emp_updated_eml 
-- Type:            Procedure 
-- Creation date:   24-Jun-2014 
-- Created by:      Alexandru Banu 
-- Description:     Produces the email template used when an employee updates a request 
-- 
--***************************************** 
function GET_EMP_UPDATED_EML(P_MANAGER_EMAIL varchar2, P_EMP_NUMBER varchar2, P_NO_WORK_DAYS_LEAVE number, P_LEAVE_START date, P_LEAVE_END date, P_REQUEST_ID number, P_EMP_EMAIL varchar2 default null, P_EMP_COMMENTS varchar2 default null) 
return clob 
is 
 
  V_CLOB            clob; 
  V_MANAGER_NAME    T.EMAIL; 
  V_EMP_NAME        T.EMAIL; 
  V_EMP_EMAIL       T.EMAIL; 
  V_START_DATE      varchar2(12); 
  V_END_DATE        varchar2(12); 
  V_LINK            varchar2(255); 
 
  V_VACATION_PLAN   AA_COUNTRY_VP_INT.PLAN_DESC%type; 
  V_COUNTRY_ID      AA_COUNTRY_VP_INT.AA_COUNTRY_ID%type; 
 
begin 
 
  select EMAIL_TEMPLATE 
    into V_CLOB 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = 9; -- Manager - Request Cancelled 
 
  select ACVI.PLAN_DESC, AA_COUNTRY_ID 
    into V_VACATION_PLAN, V_COUNTRY_ID 
    from AA_REQUESTS AR 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AR.AA_COUNTRY_VP_INT_ID 
    where AR.AA_REQUEST_ID = P_REQUEST_ID; 
 
 
  V_MANAGER_NAME := WS_TOOLS.GET_USER_NAME(P_MANAGER_EMAIL); 
  V_START_DATE := TO_CHAR(P_LEAVE_START,'DD-MON-YYYY'); 
  V_END_DATE := TO_CHAR(P_LEAVE_END,'DD-MON-YYYY'); 
  V_LINK := CONSTRUCT_LINK('3','PUBLIC_BOOKMARK',null,'P3_REQUEST_ID,P3_COUNTRY_ID:'||P_REQUEST_ID||','||V_COUNTRY_ID); 
 
 
  if P_EMP_EMAIL is not null 
    then 
      V_EMP_NAME := WS_TOOLS.GET_USER_NAME(P_EMP_EMAIL); 
      V_EMP_EMAIL := P_EMP_EMAIL; 
  else 
    V_EMP_NAME := WS_TOOLS.GET_USER_NAME(WS_TOOLS.GET_USER); 
    V_EMP_EMAIL := WS_TOOLS.GET_USER; 
  end if; 
 
 
  V_CLOB := replace(V_CLOB,'[[$$NAME]]',V_MANAGER_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_NAME]]',V_EMP_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$NAME]]',V_MANAGER_NAME); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_EMAIL]]',V_EMP_EMAIL); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_NUMBER]]',P_EMP_NUMBER); 
  V_CLOB := replace(V_CLOB,'[[$$WORKING_DAYS]]',TO_CHAR(P_NO_WORK_DAYS_LEAVE)); 
  V_CLOB := replace(V_CLOB,'[[$$START_DATE]]',V_START_DATE); 
  V_CLOB := replace(V_CLOB,'[[$$END_DATE]]',V_END_DATE); 
  V_CLOB := replace(V_CLOB,'[[$$LINK]]',V_LINK); 
  V_CLOB := replace(V_CLOB,'[[$$VACATION_PLAN]]',V_VACATION_PLAN); 
  V_CLOB := replace(V_CLOB,'[[$$EMP_COMMENTS]]',P_EMP_COMMENTS); 
 
 
  return V_CLOB; 
 
end GET_EMP_UPDATED_EML; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            EMP_UPDATE_REQUEST 
-- Type:            Procedure 
-- Creation date:   24-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     procedure to update the request 
-- 
--***************************************** 
procedure EMP_UPDATE_REQUEST(P_APP_USER     varchar2 
                            ,P_EMP_EMAIL    varchar2 
                            ,P_REQUEST_ID   number 
                            ,P_LEAVE_START  date 
                            ,P_LEAVE_END    date 
                            ,P_DAYS_LEAVE   number) 
is 
 
  V_TO            AA_REQUESTS.EMAIL_TO%type; 
  V_EMP_NUMBER    AA_REQUESTS.EMP_NUMBER%type; 
  V_EMP_COMMENTS  AA_REQUESTS.EMP_COMMENTS%type; 
 
  V_COUNT       PLS_INTEGER; 
 
  E_NO_RIGHT    EXCEPTION; 
 
begin 
-- Update only if something changes 
  select COUNT(*) over() 
        ,AR.EMAIL_TO 
        ,AE.EMP_NUMBER 
        ,AR.EMP_COMMENTS 
    into V_COUNT 
        ,V_TO 
        ,V_EMP_NUMBER 
        ,V_EMP_COMMENTS 
    from AA_REQUESTS AR 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
    where AR.AA_REQUEST_ID = P_REQUEST_ID 
    and AR.NO_WORK_DAYS_LEAVE||AR.LEAVE_START||AR.LEAVE_END != P_DAYS_LEAVE||P_LEAVE_START||P_LEAVE_END; 
 
  if P_APP_USER = P_EMP_EMAIL then 
 
    if V_COUNT > 0 then 
    -- Update the request 
      update AA_REQUESTS 
        set NO_WORK_DAYS_LEAVE = P_DAYS_LEAVE 
           ,LEAVE_START = P_LEAVE_START 
           ,LEAVE_END = P_LEAVE_END 
        where AA_REQUEST_ID = P_REQUEST_ID; 
 
 
 
    -- Send the update email notification to the manager 
      APEX_MAIL.SEND( 
        P_TO => (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_TO else c_default_mail_list end),
        --P_CC => p_email_cc, 
        --P_BCC => p_email_bcc, 
        P_FROM => C_EML_FROM, 
        P_BODY => TO_CLOB('Your leave request has been approved. Your email client doesn''t support HTML. Please use a client that does. Thank you.'), 
        P_BODY_HTML => GET_EMP_UPDATED_EML(V_TO, V_EMP_NUMBER, P_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, P_REQUEST_ID,P_EMP_EMAIL, V_EMP_COMMENTS), 
        P_SUBJ => P_EMP_EMAIL||' - iVacation Employee Updated Request' 
      ); 
 
      APEX_MAIL.PUSH_QUEUE; 
 
    end if; 
 
  else 
 
    raise E_NO_RIGHT; 
 
  end if; 
 
  EXCEPTION 
    when NO_DATA_FOUND then null; 
    when E_NO_RIGHT then RAISE_APPLICATION_ERROR('-20004',q'[Please select a status from the ones below.]'); 
 
 
end EMP_UPDATE_REQUEST; 
 
 
 
--***************************************** 
-- 
-- Name:            EMP_UPDATE_REQUEST 
-- Type:            Procedure 
-- Creation date:   24-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     procedure to update the request 
-- 
--***************************************** 
procedure EMP_UPDATE_REQUEST_TEMP(P_APP_USER     varchar2 
                            ,P_EMP_EMAIL    varchar2 
                            ,P_REQUEST_ID   number 
                            ,P_LEAVE_START  date 
                            ,P_LEAVE_END    date 
                            ,P_DAYS_LEAVE   number) 
is 
 
  V_TO            AA_REQUESTS.EMAIL_TO%type; 
  V_EMP_NUMBER    AA_REQUESTS.EMP_NUMBER%type; 
  V_EMP_COMMENTS  AA_REQUESTS.EMP_COMMENTS%type; 
 
  V_COUNT       PLS_INTEGER; 
 
  E_NO_RIGHT    EXCEPTION; 
 
begin 
-- Update only if something changes 
  select COUNT(*) over() 
        ,AR.EMAIL_TO 
        ,AE.EMP_NUMBER 
        ,AR.EMP_COMMENTS 
    into V_COUNT 
        ,V_TO 
        ,V_EMP_NUMBER 
        ,V_EMP_COMMENTS 
    from AA_REQUESTS AR 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
    where AR.AA_REQUEST_ID = P_REQUEST_ID 
    and AR.NO_WORK_DAYS_LEAVE||AR.LEAVE_START||AR.LEAVE_END != P_DAYS_LEAVE||P_LEAVE_START||P_LEAVE_END; 
 
  if P_APP_USER = P_EMP_EMAIL then 
 
    if V_COUNT > 0 then 
    -- Update the request 
      update AA_REQUESTS 
        set NO_WORK_DAYS_LEAVE = P_DAYS_LEAVE 
           ,LEAVE_START = P_LEAVE_START 
           ,LEAVE_END = P_LEAVE_END 
        where AA_REQUEST_ID = P_REQUEST_ID; 
 
 
 
 
 
    end if; 
 
  else 
 
    raise E_NO_RIGHT; 
 
  end if; 
 
  EXCEPTION 
    when NO_DATA_FOUND then null; 
    when E_NO_RIGHT then RAISE_APPLICATION_ERROR('-20004',q'[Please select a status from the ones below.]'); 
 
 
end EMP_UPDATE_REQUEST_TEMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            has_access_vac 
-- Type:            Function 
-- Creation date:   19-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Function that checks if an user has access to the request 
-- 
--***************************************** 
function HAS_ACCESS_VAC(P_REQUEST_ID number) 
return BOOLEAN 
is 
 
  V_COUNT PLS_INTEGER; 
 
begin 
 
  select COUNT(*) 
    into V_COUNT 
    from AA_REQUESTS AR 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
    where AR.AA_REQUEST_ID = P_REQUEST_ID 
    and (UPPER(AR.EMP_EMAIL) = WS_TOOLS.GET_USER 
      or UPPER(AR.EMAIL_TO) = WS_TOOLS.GET_USER 
      or IS_LOCAL_HR(AE.AA_COUNTRY_ID, '-1') = 1); 
 
  if V_COUNT > 0 then 
    return true; 
  else 
    return false; 
  end if; 
 
end HAS_ACCESS_VAC; 
 
 
 
 
--***************************************** 
-- 
-- Name:            is_db 
-- Type:            Function 
-- Creation date:   06-Oct-2016 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is a db account 
-- 
--***************************************** 
function IS_DB 
return BOOLEAN 
is 
 
begin 
 
  if WS_TOOLS.GET_USER = 'DATABASE ACCOUNT' then 
    return true; 
  end if; 
 
  return false; 
 
end IS_DB; 
 
 
 
 
--***************************************** 
-- 
-- Name:            is_approver 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is approver 
-- 
--***************************************** 
function IS_APPROVER 
return BOOLEAN 
is 
 
  V_COUNT   number; 
  V_COUNT2  number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_REQUESTS 
    where UPPER(EMAIL_TO) = UPPER(WS_TOOLS.GET_USER); 
 
  select COUNT(1) 
    into V_COUNT2 
    from AA_EMPLOYEES 
    where UPPER(emp_manager) = UPPER(WS_TOOLS.GET_USER); 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT + V_COUNT2 > 0 
    then return true; 
  else 
    return false; 
  end if; 
 
end IS_APPROVER; 
 
 
 
 
--***************************************** 
-- 
-- Name:            is_approver 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is approver 
-- 
--***************************************** 
function IS_APPROVER(P_COUNTRY_ID number) 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_REQUESTS 
    where UPPER(EMAIL_TO) = UPPER(WS_TOOLS.GET_USER); 
 
-- is_approver CONTAINS the local_hr team also 
  if IS_LOCAL_HR(P_COUNTRY_ID) then 
 
    V_COUNT := V_COUNT + 1; 
 
  end if; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return true; 
  else 
    return false; 
  end if; 
 
end IS_APPROVER; 
 
 
 
 
--***************************************** 
-- 
-- Name:            is_approver 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is approver 
-- 
--***************************************** 
function IS_APPROVER(P_COUNTRY_ID number, P_DUMMY number) 
return number 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_REQUESTS 
    where UPPER(EMAIL_TO) = UPPER(WS_TOOLS.GET_USER); 
 
-- is_approver CONTAINS the local_hr team also 
  if IS_LOCAL_HR(P_COUNTRY_ID) = true 
    then V_COUNT := V_COUNT + 1; 
  ELSIF WS_TOOLS.GET_USER = 'ROHIT.BQ.KUMAR@ORACLE.COM' 
    then V_COUNT := V_COUNT + 1; 
  end if; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return 1; 
  else 
    return 0; 
  end if; 
 
end IS_APPROVER; 
 
 
--***************************************** 
-- 
-- Name:            is_local_hr 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is loca_hr 
-- 
--***************************************** 
function IS_LOCAL_HR 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_USER_CT_ROLE_INT 
    where UPPER(EMP_EMAIL) = UPPER(WS_TOOLS.GET_USER) 
    and AA_ROLE_ID = 1 -- Country HR 
    and ACTIVE = 1; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return true; 
  else 
    return false; 
  end if; 
 
end IS_LOCAL_HR; 
 
 
 
--***************************************** 
-- 
-- Name:            is_local_hr 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is loca_hr 
-- 
--***************************************** 
function IS_LOCAL_HR(P_COUNTRY_ID number) 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_USER_CT_ROLE_INT 
    where UPPER(EMP_EMAIL) = UPPER(WS_TOOLS.GET_USER) 
    and AA_COUNTRY_ID = P_COUNTRY_ID 
    and AA_ROLE_ID = 1 -- Country HR 
    and ACTIVE = 1; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return true; 
  else 
    return false; 
  end if; 
 
end IS_LOCAL_HR; 
 
 
 
 
--***************************************** 
-- 
-- Name:            is_local_hr 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is loca_hr 
-- 
--***************************************** 
function IS_LOCAL_HR(P_COUNTRY_ID number, P_DUMMY number) 
return number 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_USER_CT_ROLE_INT 
    where UPPER(EMP_EMAIL) = UPPER(WS_TOOLS.GET_USER) 
    and AA_COUNTRY_ID = P_COUNTRY_ID 
    and AA_ROLE_ID = 1 -- Country HR 
    and ACTIVE = 1; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return 1; 
  else 
    return 0; 
  end if; 
 
end IS_LOCAL_HR; 
 
 
--***************************************** 
-- 
-- Name:            IS_PAYROLL 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is payroll including HR 
-- 
--***************************************** 
function IS_PAYROLL 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_USER_CT_ROLE_INT 
    where UPPER(EMP_EMAIL) = UPPER(WS_TOOLS.GET_USER) 
    and AA_ROLE_ID in (1,2) -- Country Payroll + Country HR 
    and ACTIVE = 1; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return true; 
  else 
    return false; 
  end if; 
 
end IS_PAYROLL; 
 
 
 
--***************************************** 
-- 
-- Name:            IS_PAYROLL 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is payroll including HR 
-- 
--***************************************** 
function IS_PAYROLL(P_COUNTRY_ID number) 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_USER_CT_ROLE_INT 
    where UPPER(EMP_EMAIL) = UPPER(WS_TOOLS.GET_USER) 
    and AA_COUNTRY_ID = P_COUNTRY_ID 
    and AA_ROLE_ID in (1,2) -- Country Payroll + Country HR 
    and ACTIVE = 1; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return true; 
  else 
    return false; 
  end if; 
 
end IS_PAYROLL; 
 
 
 
 
--***************************************** 
-- 
-- Name:            IS_PAYROLL 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if the user is payroll including HR 
-- 
--***************************************** 
function IS_PAYROLL(P_COUNTRY_ID number, P_DUMMY number) 
return number 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_USER_CT_ROLE_INT 
    where UPPER(EMP_EMAIL) = UPPER(WS_TOOLS.GET_USER) 
    and AA_COUNTRY_ID = P_COUNTRY_ID 
    and AA_ROLE_ID in (1,2) -- Country Payroll + Country HR 
    and ACTIVE = 1; 
 
-- If it is a DB Account then grant access 
  if IS_DB then 
    V_COUNT := V_COUNT + 1; 
  end if; 
 
  if V_COUNT > 0 
    then return 1; 
  else 
    return 0; 
  end if; 
 
end IS_PAYROLL; 
 
 
 
 
--***************************************** 
-- 
-- Name:            exist_local_hr_rep 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if a HR Rep exists 
-- 
--***************************************** 
function EXIST_LOCAL_HR_REP (P_EMAIL varchar2) 
return BOOLEAN 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_LOCAL_HR_REP 
    where UPPER(EMAIL) = UPPER(P_EMAIL); 
 
    if V_COUNT > 0 
      then return true; 
    else 
      return false; 
    end if; 
 
end EXIST_LOCAL_HR_REP; 
 
 
 
--***************************************** 
-- 
-- Name:            new_local_hr_rep 
-- Type:            Procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Create a new hr rep 
-- 
--***************************************** 
procedure NEW_LOCAL_HR_REP (P_EMAIL varchar) 
is 
 
  V_EMAIL         AA_LOCAL_HR_REP.EMAIL%type; 
  E_EXIST         EXCEPTION; 
 
begin 
 
  V_EMAIL := WS_TOOLS.TRIM_ALL(UPPER(P_EMAIL)); 
 
  if EXIST_LOCAL_HR_REP(V_EMAIL) = false 
    then 
      insert into AA_LOCAL_HR_REP (EMAIL) values (V_EMAIL); 
  else 
    RAISE E_EXIST; 
  end if; 
 
  EXCEPTION 
    when E_EXIST 
      then RAISE_APPLICATION_ERROR(-20001, 'The hr rep "'||V_EMAIL||'" already exists'); 
 
end NEW_LOCAL_HR_REP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            exist_emp 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if employee already exists 
-- 
--***************************************** 
function EXIST_EMP (P_EMP_EMAIL varchar2) 
return BOOLEAN 
is 
 
    V_COUNT number; 
 
begin 
 
    select COUNT(1) 
    into V_COUNT 
    from AA_EMPLOYEES 
    where EMP_EMAIL = P_EMP_EMAIL; 
 
    if V_COUNT > 0 
        then return true; 
    else 
        return false; 
  end if; 
 
 
end EXIST_EMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            exist_emp 
-- Type:            Function 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Checks to see if employee already exists 
-- 
--***************************************** 
function EXIST_EMP (P_EMP_ID number) 
return BOOLEAN 
is 
 
    V_COUNT number; 
 
begin 
 
    select COUNT(1) 
    into V_COUNT 
    from AA_EMPLOYEES 
    where AA_EMPLOYEE_ID = P_EMP_ID; 
 
    if V_COUNT > 0 
        then return true; 
    else 
        return false; 
  end if; 
 
 
end EXIST_EMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            CREATE_EMP 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Creates the actual empployee 
-- 
--***************************************** 
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
) 
is 
 
  E_EXIST                   EXCEPTION; 
  V_EMP_EMAIL               AA_EMPLOYEES.EMP_EMAIL%type; 
  V_LEVAE_BALANCE           AA_EMPLOYEES.STARTING_VAC_BALANCE%type; 
 
begin 
 
  V_EMP_EMAIL := WS_TOOLS.TRIM_ALL(UPPER(P_EMP_EMAIL)); 
 
  V_LEVAE_BALANCE := P_LEVAE_BALANCE + NVL(P_LAST_YEAR_LEAVE_BALANCE,0); 

-- If the employee does not exist create him and create a month for him in the overview table 
  if EXIST_EMP(V_EMP_EMAIL) = true 
      then RAISE E_EXIST; 
  else 
 

     insert into AA_EMPLOYEES(EMP_NUMBER,EMP_NAME,EMP_EMAIL,START_DATE,AA_COUNTRY_ID,COST_CENTER,EMP_MANAGER,STARTING_VAC_BALANCE, TENURE_BEFORE_ORACLE_MONTHS) 
        values (P_EMP_NUMBER, P_EMP_NAME, V_EMP_EMAIL, P_START_DATE, P_COUNTRY_ID, P_COST_CENTER, P_MANAGER,V_LEVAE_BALANCE, P_TENURE_BEFORE_ORACLE_MONTHS); 

  end if; 
 
  EXCEPTION 
      when E_EXIST 
          then RAISE_APPLICATION_ERROR(-20001,P_EMP_EMAIL || ' already exists.'); 
 
end CREATE_EMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            ADD_EMP_MONTHS 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Creates the starting months for a new employee 
-- 
--***************************************** 
procedure ADD_EMP_START_MONTHS( 
  P_EMP_EMAIL                 AA_EMPLOYEES.EMP_EMAIL%type 
 ,P_START_DATE                AA_EMPLOYEES.START_DATE%type 
 ,P_LEAVE_BALANCE             AA_OVERVIEW.LEAVE_BALANCE%type default 0 
 ,P_LAST_YEAR_LEAVE_BALANCE   AA_EMPLOYEES.STARTING_VAC_BALANCE%type default 0 
) 
is 
 
  V_MONTHS_BETWEEN INTEGER; 
 
begin 
  -- APEX_DEBUG.ERROR('Inside ADD_EMP_START_MONTHS'); 
-- If the insert date of the new employee is in a prior moth to his begin_date 
-- Then insert all the months from begin date to sysdate 
  V_MONTHS_BETWEEN := FLOOR(MONTHS_BETWEEN(LAST_DAY(localtimestamp),TRUNC(P_START_DATE))); 
  -- APEX_DEBUG.ERROR('V_MONTHS_BETWEEN: '||V_MONTHS_BETWEEN); 
 
  if V_MONTHS_BETWEEN >= 1 -- Employee has a begin_date lower than sysdate. We add all the months between begin_date and sysdate 
    then 
      for I in 0..V_MONTHS_BETWEEN 
      LOOP 
 
 
        if I = 0 then 
 
          NEW_MONTH( 
            P_EMAIL                   => P_EMP_EMAIL 
           ,P_MONTH                   => P_START_DATE 
           ,P_ACCRUED                 => P_LEAVE_BALANCE 
           ,P_LAST_YEAR_LEAVE_BALANCE => P_LAST_YEAR_LEAVE_BALANCE 
           ,P_AMOUNT_ADDED            => P_LEAVE_BALANCE 
          ); 
 
 
        else 
       
          NEW_MONTH( 
            P_EMAIL                   => P_EMP_EMAIL 
           ,P_MONTH                   => ADD_MONTHS(TRUNC(P_START_DATE,'mm'),I) 
           ,P_ACCRUED                 => P_LEAVE_BALANCE 
           ,P_LAST_YEAR_LEAVE_BALANCE => P_LAST_YEAR_LEAVE_BALANCE 
           ,P_AMOUNT_ADDED            => P_LEAVE_BALANCE 
          ); 
 
        end if; 
 
      end LOOP; 
  ELSIF V_MONTHS_BETWEEN = 0 -- Employee has the begin_date in the same month as sysdate. We add only the begin_date month because it is sysdate month 
    then 
 
 
      -- APEX_DEBUG.ERROR('Same month'); 
      -- APEX_DEBUG.ERROR('P_START_DATE: '||P_START_DATE); 
 
      NEW_MONTH( 
        P_EMAIL                   => P_EMP_EMAIL 
       ,P_MONTH                   => P_START_DATE 
       ,P_ACCRUED                 => P_LEAVE_BALANCE 
       ,P_LAST_YEAR_LEAVE_BALANCE => P_LAST_YEAR_LEAVE_BALANCE 
       ,P_AMOUNT_ADDED            => P_LEAVE_BALANCE 
      ); 
 
  else -- If it's greater than sysdate the employee begins work in the future and we don't do nothing. 
    null; 
  end if; 
 
end ADD_EMP_START_MONTHS; 
 
 
 
--***************************************** 
-- 
-- Name:            add_emp 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Creates a new employee 
-- 
--***************************************** 
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
) 
is 
 
begin 
 
    -- APEX_DEBUG.ERROR('P_START_DATE - '||TO_CHAR(P_START_DATE,'dd-Mon-yyyy')); 
-- Create the actual employee 
  CREATE_EMP( 
    P_EMP_NUMBER                    => P_EMP_NUMBER 
   ,P_EMP_NAME                      => P_EMP_NAME 
   ,P_EMP_EMAIL                     => P_EMP_EMAIL 
   ,P_START_DATE                    => P_START_DATE 
   ,P_COUNTRY_ID                    => P_COUNTRY_ID 
   ,P_COST_CENTER                   => P_COST_CENTER 
   ,P_MANAGER                       => P_MANAGER 
   ,P_LEVAE_BALANCE                 => P_LEVAE_BALANCE 
   ,P_LAST_YEAR_LEAVE_BALANCE       => P_LAST_YEAR_LEAVE_BALANCE 
   ,P_TENURE_BEFORE_ORACLE_MONTHS   => P_TENURE_BEFORE_ORACLE_MONTHS 
  ); 
 

    -- APEX_DEBUG.ERROR('P_START_DATE - '||TO_CHAR(P_START_DATE,'dd-Mon-yyyy')); 
 
-- Add the months for the starting months of a new employee 
  ADD_EMP_START_MONTHS( 
    P_EMP_EMAIL               => P_EMP_EMAIL 
   ,P_START_DATE              => P_START_DATE 
   ,P_LEAVE_BALANCE           => P_LEVAE_BALANCE 
   ,P_LAST_YEAR_LEAVE_BALANCE => P_LAST_YEAR_LEAVE_BALANCE 
  ); 
 
end ADD_EMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            UPDATE_EMP_EMAIL 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Updates the email of an employee 
-- 
--***************************************** 
procedure UPDATE_EMP_EMAIL_TRIGGER(P_OLD_EMAIL varchar2, P_NEW_EMAIL varchar2) 
is 
 
begin 
 
  update AA_EMP_STATUS_INT 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
   
  update AA_EMP_STATUS_INT_JNL 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
 
  update AA_EMP_CUST_ACCRUAL 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
   
  update AA_EMP_CUST_ACCRUAL_JNL 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
   
  update AA_REQUESTS 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
 
  update AA_OVERVIEW 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
 
  update AA_SICK_LEAVE 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
 
  update AA_OOH_REQUESTS 
  set EMP_EMAIL = UPPER(P_NEW_EMAIL) 
  where EMP_EMAIL = UPPER(P_OLD_EMAIL); 
 
end UPDATE_EMP_EMAIL_TRIGGER; 
 
 
 
 
--***************************************** 
-- 
-- Name:            UPDATE_MNG_EMAIL_TRIGGER 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Updates the email of a manager 
-- 
--***************************************** 
procedure UPDATE_MNG_EMAIL_TRIGGER(P_EMP_EMAIL varchar2, P_NEW_EMAIL varchar2) 
is 
 
begin 
 
  if NVL(P_NEW_EMAIL,'-1') != '1' then 
 
    update AA_REQUESTS 
    set EMAIL_TO = UPPER(P_NEW_EMAIL) 
    where EMP_EMAIL = UPPER(P_EMP_EMAIL); 
 
    update AA_OOH_REQUESTS 
    set EMP_MNG = UPPER(P_NEW_EMAIL) 
    where EMP_EMAIL = UPPER(P_EMP_EMAIL); 
 
  end if; 
 
end UPDATE_MNG_EMAIL_TRIGGER; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            inactivate_emp 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Updates an employee with his leave date 
-- 
--***************************************** 
procedure INACTIVATE_EMP (P_EMPLOYEE_ID number, P_END_DATE date) 
is 
 
  E_EXIST EXCEPTION; 
 
begin 
 
    if EXIST_EMP(P_EMPLOYEE_ID) = false 
        then RAISE E_EXIST; 
    else 
 
        update AA_EMPLOYEES 
        set END_DATE = P_END_DATE 
        where AA_EMPLOYEE_ID = P_EMPLOYEE_ID; 
 
    end if; 
 
 
    EXCEPTION 
        when E_EXIST 
            then RAISE_APPLICATION_ERROR(-20002,'Employee doesn''t exist.'); 
 
end INACTIVATE_EMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            count_previous_wa_requests 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Counts the number of requests that are still waiting approval from the previous months 
-- 
--***************************************** 
function COUNT_PREVIOUS_WA_REQUESTS(P_EMAIL varchar2, P_MONTH date, P_AA_COUNTRY_VP_INT_ID number) 
return number 
is 
 
  V_COUNT number; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_REQUESTS 
    where EMP_EMAIL = P_EMAIL 
    and AA_STATUS_ID = 1 -- Waiting Approval 
    and TO_CHAR(LEAVE_START,'mm yyyy') = TO_CHAR(P_MONTH,'mm yyyy') --add_months(last_day(localtimestamp),-1); 
    and AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID; 
 
    -- Count all the request that started before localtimestamp and are still waiting approval for the specific vacation plan 
 
  return V_COUNT; 
 
end COUNT_PREVIOUS_WA_REQUESTS; 
 
 
 
 
--***************************************** 
-- 
-- Name:            delete_emp 
-- Type:            procedure 
-- Creation date:   14-MAR-2013 
-- Created by:      Alexandru Banu 
-- Description:     Deletes all traces of an employee 
-- 
--***************************************** 
procedure DELETE_EMP(P_EMAIL varchar2) 
is 
 
  V_EMAIL T.EMAIL; 
 
begin 
 
  V_EMAIL := WS_TOOLS.TRIM_ALL(UPPER(P_EMAIL)); 
 
  delete from AA_OVERVIEW 
  where EMP_EMAIL = V_EMAIL; 
 
  delete from AA_OVERVIEW_JNL 
  where EMP_EMAIL = V_EMAIL; 
 
  delete from AA_REQUESTS 
  where EMP_EMAIL = V_EMAIL; 
 
  delete from AA_EMPLOYEES 
  where EMP_EMAIL = V_EMAIL; 
 
end DELETE_EMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_COUNTRY_ADMIN 
-- Type:            procedure 
-- Creation date:   13-NOV-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns the administrators for a given country 
-- 
--***************************************** 
function GET_COUNTRY_ADMIN(P_COUNTRY_ID number) 
return varchar2 
is 
 
  V_RETURN  varchar2(1000); 
  V_ARRAY   APEX_APPLICATION_GLOBAL.VC_ARR2; 
 
begin 
 
  select EMP_EMAIL 
    bulk collect into V_ARRAY 
    from AA_USER_CT_ROLE_INT 
    where AA_COUNTRY_ID = P_COUNTRY_ID 
    and AA_ROLE_ID = 1 -- Country HR 
    and ACTIVE = 1; 
 
  V_RETURN := APEX_UTIL.TABLE_TO_STRING(V_ARRAY,','); 
 
  return V_RETURN; 
 
end GET_COUNTRY_ADMIN; 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_EMAIL_CC 
-- Type:            procedure 
-- Creation date:   13-NOV-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns the administrators for a given country 
-- 
--***************************************** 
function GET_EMAIL_CC(P_COUNTRY_ID number) 
return varchar2 
is 
 
  V_RETURN  varchar2(1000); 
  V_ARRAY   APEX_APPLICATION_GLOBAL.VC_ARR2; 
 
begin 
 
   select EMP_EMAIL 
    bulk collect into V_ARRAY 
    from AA_USER_CT_ROLE_INT 
    where AA_COUNTRY_ID = P_COUNTRY_ID 
    and ((P_COUNTRY_ID not in (30,31) -- AZ 
          and AA_ROLE_ID = 1) -- Country HR 
        or 
        (P_COUNTRY_ID in (30,31)) 
        ) 
    and ACTIVE = 1 
    and RECEIVE_EML = 1; 
 
  V_RETURN := APEX_UTIL.TABLE_TO_STRING(V_ARRAY,','); 
 
  return V_RETURN; 
 
end GET_EMAIL_CC; 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_EMAIL_CC 
-- Type:            procedure 
-- Creation date:   13-NOV-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns the administrators for a given country 
-- 
--***************************************** 
function GET_EMAIL_CC_APPROVED(P_COUNTRY_ID number) 
return varchar2 
is 
 
begin 
 
  if P_COUNTRY_ID = 31 then 
 
    return GET_EMAIL_CC(P_COUNTRY_ID); 
 
  end if; 
 
  return null; 
 
end GET_EMAIL_CC_APPROVED; 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_COUNTRY_ADMIN 
-- Type:            procedure 
-- Creation date:   13-NOV-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns the administrators for a given country 
-- 
--***************************************** 
function GET_COUNTRY_ADMIN_EML(P_COUNTRY_ID number) 
return varchar2 
is 
 
  V_RETURN  varchar2(1000); 
  V_ARRAY   APEX_APPLICATION_GLOBAL.VC_ARR2; 
 
begin 
 
   select EMP_EMAIL 
    bulk collect into V_ARRAY 
    from AA_USER_CT_ROLE_INT 
    where AA_COUNTRY_ID = P_COUNTRY_ID 
    and AA_ROLE_ID = 1 -- Country HR 
    and ACTIVE = 1 
    and RECEIVE_EML = 1; 
 
  V_RETURN := APEX_UTIL.TABLE_TO_STRING(V_ARRAY,','); 
 
  return V_RETURN; 
 
end GET_COUNTRY_ADMIN_EML; 
 
 
 
--***************************************** 
-- 
-- Name:            get_user_country_id 
-- Type:            procedure 
-- Creation date:   13-NOV-2013 
-- Created by:      Alexandru Banu 
-- Description:     Returns the country for a user 
-- 
--***************************************** 
function GET_USER_COUNTRY_ID(P_EMAIL varchar2) 
return number 
is 
 
  V_AA_COUNTRY_ID AA_EMPLOYEES.AA_COUNTRY_ID%type; 
 
begin 
 
  select AA_COUNTRY_ID 
    into V_AA_COUNTRY_ID 
    from AA_EMPLOYEES 
    where EMP_EMAIL = P_EMAIL 
    and NVL(trunc(END_DATE),trunc(sysdate) + 1) > trunc(sysdate); 
 
  return V_AA_COUNTRY_ID; 
 
end GET_USER_COUNTRY_ID; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PROCESS_EMP_PENDING_REQUESTS_HTML 
-- Type:            procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Processes and appends to the final email template the pending requests 
-- 
--***************************************** 
procedure PROCESS_EMP_PENDING_REQUESTS(P_EMP_EMAIL varchar2, P_EML_HTML in OUT clob, P_EML_TEXT in OUT clob) 
is 
 
  V_WAITING_APPROVAL  AA_REQUESTS.AA_STATUS_ID%type; 
 
  V_HTML              clob; 
  V_TEXT              varchar2(255); 
  V_LINE              clob; 
  V_COUNT             PLS_INTEGER; 
  V_MOD               PLS_INTEGER; 
  V_BG_COLOR          varchar2(30); 
 
begin 
-- Initialize variables 
  V_WAITING_APPROVAL := 1; 
  V_COUNT            := 0; 
 
V_HTML := '<tr> 
  <td align="center" valign="top" style="padding: 0 18px 18px 18px;"> 
  
    <p style="font-size: 12px; font-family: Arial, Helvetica, sans-serif; color: #000000; line-height:18px; margin-bottom:8px; text-align:justify;"> 
      Please find below the <span style="font-size: 12px; font-weight: bold; color: #A45A52;">Vacation Leave Days</span> that are pending approval from your manager: 
    </p> 
    <table width="90%" border="0" cellpadding="0" cellspacing="0" 
           style="font-size: 12px; font-family: Arial, Helvetica, sans-serif; color: #000000; line-height:18px; margin-bottom:8px; padding:0 0 18px 0;"> 
      <tr width="100%" bgcolor="#F5EAE7"> 
        <td align="middle" width="20%" style="padding:5px; color:#A45A52;"><strong>First Day of Leave</strong></td> 
        <td align="middle" width="20%" style="padding:5px; color:#A45A52;"><strong>Last Day of Leave</strong></td> 
        <td align="middle" width="20%" style="padding:5px; color:#A45A52;"><strong>Number of Leave Days</strong></td> 
        <td align="middle" width="40%" style="padding:5px; color:#A45A52;"><strong>Approver</strong></td> 
      </tr>';

 
  for X in (select TO_CHAR(LEAVE_START,'dd-Mon-yyyy') LEAVE_START 
                  ,TO_CHAR(LEAVE_END,'dd-Mon-yyyy') LEAVE_END 
                  ,NO_WORK_DAYS_LEAVE 
                  ,LOWER(EMAIL_TO) EMAIL_TO 
              from AA_REQUESTS 
              where LOWER(EMP_EMAIL) = LOWER(P_EMP_EMAIL) 
              and AA_STATUS_ID = V_WAITING_APPROVAL 
              order by LEAVE_START 
            ) 
  LOOP 
  -- Set the background color for the rows 
    -- if MOD(V_COUNT,2) = 0 
    --   then 
        V_BG_COLOR := '#FBF9F3'; 
    -- else 
    --   V_BG_COLOR := '#dddddd'; 
    -- end if; 
 
    V_LINE := ' 
        <tr bgcolor="'||V_BG_COLOR||'"> 
          <td align="middle" width="20%" style="padding:5px;color:#000000;"><strong>'||X.LEAVE_START||'</strong></td> 
          <td align="middle" width="20%" style="padding:5px;color:#000000;"><strong>'||X.LEAVE_END||'</strong></td> 
          <td align="middle" width="20%" style="padding:5px;color:#000000;"><strong>'||X.NO_WORK_DAYS_LEAVE||'</strong></td> 
          <td align="middle" width="40%" style="padding:5px;color:#000000;"><strong>'||X.EMAIL_TO||'</strong></td> 
        </tr>'; 
 
    V_HTML := V_HTML||V_LINE; 
 
    V_COUNT := V_COUNT + 1; 
 
  end loop; 
 
  V_HTML := V_HTML||' 
      </table> 
    </td> 
  </tr>'; 
 
-- If there is at least one pending request fill it in the final email template 
  if V_COUNT > 0 
    then 
 
      V_TEXT     := 'You have '||V_COUNT||' vacation leave days that are pending approval from your manager. Please use the link below to see which requests are pending.'; 
 
--      P_EML_HTML := replace(P_EML_HTML,'[[$$PENDING_REQUESTS]]',V_HTML); 
      P_EML_HTML := WS_TOOLS.CLOB_REPLACE(P_EML_HTML,TO_CLOB('[[$$PENDING_REQUESTS]]'),V_HTML); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$PENDING_REQUESTS]]',V_TEXT); 
 
  else 
  -- Otherwise remove the wording "[[$$PENDING_REQUESTS]]" 
      P_EML_HTML := replace(P_EML_HTML,'[[$$PENDING_REQUESTS]]'); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$PENDING_REQUESTS]]'); 
 
  end if; 
 
 
end PROCESS_EMP_PENDING_REQUESTS; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PROCESS_DETAILED_REQUESTS_HTML 
-- Type:            procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Processes and appends to the final email template the detailed leave days for the month 
-- 
--***************************************** 
procedure PROCESS_DETAILED_REQUESTS(P_EMP_EMAIL varchar2, P_MONTH date, P_EML_HTML in OUT clob, P_EML_TEXT in OUT clob) 
is 
 
  V_APPROVED          AA_REQUESTS.AA_STATUS_ID%type; 
  V_HAS_OOH           AA_COUNTRIES.OOH%type; 
 
  V_HTML              clob; 
  V_TEXT              varchar2(255); 
  V_LINE              clob; 
  V_COUNT             PLS_INTEGER; 
  V_MOD               PLS_INTEGER; 
  V_BG_COLOR          varchar2(30); 
  V_EMP_TYPE          varchar2(3); 
 
begin 
-- Initialize variables 
  V_APPROVED := 2; 
  V_COUNT    := 0; 
  V_EMP_TYPE := 'EMP'; 
 
V_HTML := '<tr> 
  <td align="center" valign="top" style="padding: 0 18px 18px 18px;"> 
  
    <p style="font-size: 12px; font-family: Arial, Helvetica, sans-serif; color: #000000; line-height:18px; margin-bottom:8px; text-align:justify;"> 
      Please find below the detailed <span style="font-size: 12px; font-weight: bold; color: #A45A52;">Vacation Leave Days</span> for this month: 
    </p> 
    <table width="90%" border="0" cellpadding="0" cellspacing="0" 
           style="font-size: 12px; font-family: Arial, Helvetica, sans-serif; color: #000000; line-height:18px; margin-bottom:8px; padding:0 0 18px 0;"> 
      <tr width="100%" bgcolor="#F5EAE7"> 
        <td align="middle" width="25%" style="padding:5px; color:#A45A52;"><strong>First Day of Leave</strong></td> 
        <td align="middle" width="25%" style="padding:5px; color:#A45A52;"><strong>Last Day of Leave</strong></td> 
        <td align="middle" width="25%" style="padding:5px; color:#A45A52;"><strong>Number of Leave Days</strong></td> 
        <td align="middle" width="25%" style="padding:5px; color:#A45A52;"><strong>Vacation Plan</strong></td> 
      </tr>';

 
  for X in (select TO_CHAR(AR.LEAVE_START,'dd-Mon-yyyy') LEAVE_START 
                  ,TO_CHAR(AR.LEAVE_END,'dd-Mon-yyyy') LEAVE_END 
                  ,AR.NO_WORK_DAYS_LEAVE 
                  ,ACVI.PLAN_DESC 
              from AA_REQUESTS AR 
              join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AR.AA_COUNTRY_VP_INT_ID 
              where LOWER(AR.EMP_EMAIL) = LOWER(P_EMP_EMAIL) 
              and AR.AA_STATUS_ID = V_APPROVED 
              and TRUNC(AR.LEAVE_START,'mm') = TRUNC(P_MONTH,'mm') 
              order by AR.LEAVE_START 
            ) 
  loop 
  -- Set the background color for the rows 
    -- if MOD(V_COUNT,2) = 0 
    --   then 
        V_BG_COLOR := '#FBF9F3'; 
    -- else 
    --   V_BG_COLOR := '#dddddd'; 
    -- end if; 
 
    V_LINE := ' 
        <tr bgcolor="'||V_BG_COLOR||'"> 
          <td align="middle" width="25%" style="padding:5px;color:#000000;"><strong>'||X.LEAVE_START||'</strong></td> 
          <td align="middle" width="25%" style="padding:5px;color:#000000;"><strong>'||X.LEAVE_END||'</strong></td> 
          <td align="middle" width="25%" style="padding:5px;color:#000000;"><strong>'||X.NO_WORK_DAYS_LEAVE||'</strong></td> 
          <td align="middle" width="25%" style="padding:5px;color:#000000;"><strong>'||X.PLAN_DESC||'</strong></td> 
        </tr>'; 
 
    V_HTML := V_HTML||V_LINE; 
 
    V_COUNT := V_COUNT + 1; 
 
  end loop; 
 
  V_HTML := V_HTML||' 
      </table> 
    </td> 
  </tr>'; 
 
-- If there is at least one pending request fill it in the final email template 
  if V_COUNT > 0 
    then 
 
      V_TEXT     := 'To see your detailed requests please use the link below.'; 
 
--      P_EML_HTML := replace(P_EML_HTML,'[[$$DETAILED_REQUESTS]]',V_HTML); 
      P_EML_HTML := WS_TOOLS.CLOB_REPLACE(P_EML_HTML,TO_CLOB('[[$$DETAILED_REQUESTS]]'),V_HTML); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$DETAILED_REQUESTS]]',V_TEXT); 
 
  else 
  -- Otherwise remove the wording "[[$$DETAILED_REQUESTS]]" 
      P_EML_HTML := replace(P_EML_HTML,'[[$$DETAILED_REQUESTS]]'); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$DETAILED_REQUESTS]]'); 
 
  end if; 
 
-- Check if the country has Out Of Hours and if it has process the requests 
  IVACATION_OOH.PROCESS_MONTLHY_EMAIL( 
    P_EMP_EMAIL => P_EMP_EMAIL 
   ,P_MONTH     => P_MONTH 
   ,P_TYPE      => V_EMP_TYPE 
   ,P_EML_HTML  => P_EML_HTML 
   ,P_EML_TEXT  => P_EML_TEXT 
  ); 
 
end PROCESS_DETAILED_REQUESTS; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_EMP_MONTHLY_REV_EML 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Creates the html for the employees monthly vacation summary email 
-- 
--***************************************** 
procedure GET_EMP_MONTHLY_REV_EML(P_EMP_EMAIL varchar2 
                                 ,P_MONTH date 
                                 ,P_EML_HTML OUT clob 
                                 ,P_EML_TEXT OUT clob) 
is 
 
  V_TEMPLATE_ID   number; 
  V_LINK          varchar2(1000); 
  V_EMP_DETAILS_LINK varchar2(1000); 
  V_MONTH         varchar2(30); 
  V_HTML          clob; 
  V_TEXT          clob; 
  V_COPY_YEAR     varchar2(4); 
 
  V_EML_HTML      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
 
begin 
-- Initialize the variables 
  V_TEMPLATE_ID := 4; -- Employee Monthly Review 
  V_LINK        := CONSTRUCT_LINK('14'); 
  V_EMP_DETAILS_LINK := CONSTRUCT_LINK('8'); 
  V_MONTH       := TO_CHAR(P_MONTH,'fmMonth YYYY'); 
  V_COPY_YEAR   := TO_CHAR(sysdate,'yyyy'); 
  V_HTML        := ''; 
  V_TEXT        := ''; 
 
-- Get the email templates 
  select EMAIL_TEMPLATE, EMAIL_TEMPLATE_TEXT 
    into V_EML_HTML, V_EML_TEXT 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = V_TEMPLATE_ID; 
 
-- Loop through all the vacation plans 
  for S1 in (select ACVI.AA_COUNTRY_VP_INT_ID  AA_COUNTRY_VP_INT_ID 
                   ,ACVI.PLAN_DESC||':'        PLAN_DESC 
                   ,ROUND(ACCRUED,2)           ACCRUED 
                   ,LEAVE_TAKEN                LEAVE_TAKEN 
                   ,ROUND(LEAVE_BALANCE,2)     LEAVE_BALANCE 
                from AA_EMPLOYEES AE 
                join AA_OVERVIEW AO on AE.EMP_EMAIL = AO.EMP_EMAIL 
                join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = AO.AA_COUNTRY_VP_INT_ID 
                where AE.EMP_EMAIL = P_EMP_EMAIL 
                and TRUNC(AO.month,'mm') = TRUNC(P_MONTH,'mm') 
                and nvl(AO.START_MONTH,0) != 1 
                and AE.AA_COUNTRY_ID != 28
                order by ACVI.AA_COUNTRY_VP_INT_ID) 
  LOOP 
 
    V_HTML := V_HTML||'<table width="100%" style="font-family:Oracle Sans, Noto Sans, Helvetica, Arial, Sans; font-size:16px; color: #000000; line-height:18px; margin-bottom:8px;">'; 
    V_HTML := V_HTML||'  <tr><td width="100%" align="left" style="padding:5px; color: #A45A52;" colspan="2">'||S1.PLAN_DESC||'</td></tr>'; 
    V_HTML := V_HTML||'  <tr><td width="60%" align="right" style="padding:5px;">Leave Balance at the beginning of the month:</td><td width="40%" align="left" style="padding:5px;">'||S1.ACCRUED||'</td></tr>'; 
    V_HTML := V_HTML||'  <tr><td width="60%" align="right" style="padding:5px;">Leave Taken during the month:</td><td width="40%" align="left" style="padding:5px;">'||S1.LEAVE_TAKEN||'</td></tr>'; 
    V_HTML := V_HTML||'  <tr><td width="60%" align="right" style="padding:5px;">Leave Balance at the end of the month:</td><td width="40%" align="left" style="padding:5px;">'||S1.LEAVE_BALANCE||'</td></tr>'; 
    V_HTML := V_HTML||'</table>'; 
 
    V_TEXT := V_TEXT||S1.PLAN_DESC; 
    V_TEXT := V_TEXT||'Leave Balance at the beginning of the month: '||S1.ACCRUED; 
    V_TEXT := V_TEXT||'Leave Taken during the month: '||S1.LEAVE_TAKEN; 
    V_TEXT := V_TEXT||'Leave Balance at the end of the month: '||S1.LEAVE_BALANCE||CHR(10)||CHR(13); 
 
  end LOOP; 
 
--  V_EML_HTML := replace(V_EML_HTML,'[[$$OVERVIEW]]',V_HTML); 
  V_EML_HTML := WS_TOOLS.CLOB_REPLACE(V_EML_HTML,TO_CLOB('[[$$OVERVIEW]]'),V_HTML); 
  V_EML_TEXT := replace(V_EML_TEXT,'[[$$OVERVIEW]]',V_TEXT); 
 
  V_EML_HTML := replace(V_EML_HTML,'[[$$MONTH_AND_YEAR]]',V_MONTH); 
  V_EML_TEXT := replace(V_EML_TEXT,'[[$$MONTH_AND_YEAR]]',V_MONTH); 
 
  V_EML_HTML := replace(V_EML_HTML,'[[$$COPYRIGHT]]',V_COPY_YEAR); 
 
-- Process pending requests and detailed leaves 
  PROCESS_DETAILED_REQUESTS(P_EMP_EMAIL,P_MONTH,V_EML_HTML,V_EML_TEXT); 
  PROCESS_EMP_PENDING_REQUESTS(P_EMP_EMAIL,V_EML_HTML,V_EML_TEXT); 
 
-- Replace the Link 
--   V_EML_HTML := replace(V_EML_HTML,'[[$$LINK]]','<a href="'||V_LINK||'">link</a>'); 

  ---rohit commit -> update V_HTML_EML , remove '<a href="'||V_LINK||'">link</a>' 
  V_EML_HTML := replace(V_EML_HTML,'[[$$LINK]]','<a href="'||V_LINK||'" style="color: #00688C;">link</a>'); 

  V_EML_HTML := replace(V_EML_HTML,'[[$$EMP_DETAILS_LINK]]','<a href="'||V_EMP_DETAILS_LINK||'" style="color: #00688C;">Employee Details</a>'); 
 
  V_EML_TEXT := replace(V_EML_TEXT,'[[$$LINK]]',V_LINK); 
  V_EML_TEXT := replace(V_EML_TEXT,'[[$$EMP_DETAILS_LINK]]',V_EMP_DETAILS_LINK); 
 
-- Return the final email templates 
  P_EML_HTML := V_EML_HTML; 
  P_EML_TEXT := V_EML_TEXT; 
 
end GET_EMP_MONTHLY_REV_EML; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            SEND_EMP_MONTHLY_REV_EML 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to send emails to all employees with their vacation entitlement 
-- 
--***************************************** 
procedure SEND_EMP_MONTHLY_REV_EML(P_DATE date default localtimestamp) 
is 
 
  V_EMP_ARRAY     APEX_APPLICATION_GLOBAL.VC_ARR2; 
  V_SUBJECT       varchar2(100); 
 
  V_EML_HTML      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
begin 
-- Initialize variables 
  V_SUBJECT := 'iVacation Monthly Summary - '||to_char(P_DATE,'fmMonth YYYY'); 
 

  -- Get all the active employees 
    select distinct(EMP_EMAIL) 
      bulk collect into V_EMP_ARRAY 
      from AA_EMPLOYEES 
      where NVL(TRUNC(END_DATE,'mm'), trunc(P_DATE,'mm') + 1) > trunc(P_DATE,'mm') 
      and TRUNC(P_DATE,'MM') >= TRUNC(START_DATE,'MM') and AA_COUNTRY_ID != 28  ; -- Send the email only starting with the month when the employee joined Oracle 
 
 
-- Send an email to all employees 
  for I in V_EMP_ARRAY.first..V_EMP_ARRAY.last 
  LOOP 
    -- Process the emails 
    GET_EMP_MONTHLY_REV_EML(P_EMP_EMAIL => V_EMP_ARRAY(I) 
                           ,P_MONTH     => P_DATE 
                           ,P_EML_HTML  => V_EML_HTML 
                           ,P_EML_TEXT  => V_EML_TEXT 
                           ); 
     bhu_logs(6002,'log6002 : '||systimestamp|| ' :- ADD_MONTH_4JOB > SEND_EMP_MONTHLY_REV_EML ', 'from - ' || C_EML_FROM ||' To -'|| V_EMP_ARRAY(I));
      APEX_MAIL.SEND(
                     P_TO =>  (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then V_EMP_ARRAY(I) else c_default_mail_list end)
                    ,P_FROM       => C_EML_FROM 
                    ,P_BODY       => V_EML_TEXT 
                    ,P_BODY_HTML  => V_EML_HTML 
                    ,P_SUBJ       => V_SUBJECT 
                  ); 
                   
    end loop;               
 
  APEX_MAIL.PUSH_QUEUE; 
 
end SEND_EMP_MONTHLY_REV_EML; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PROCESS_MNG_PENDING_REQUESTS_HTML 
-- Type:            procedure 
-- Creation date:   23-Jul-2014-- Created by:      Alexandru Banu 
-- Description:     Processes and appends to the final email template the pending requests 
-- 
--***************************************** 
procedure PROCESS_MNG_PENDING_REQUESTS(P_MNG_EMAIL varchar2, P_EML_HTML in OUT clob, P_EML_TEXT in OUT clob) 
is 
 
  V_WAITING_APPROVAL  AA_REQUESTS.AA_STATUS_ID%type; 
  V_HTML              clob; 
  V_TEXT              varchar2(255); 
  V_LINE              clob; 
  V_COUNT             PLS_INTEGER; 
  V_MOD               PLS_INTEGER; 
  V_BG_COLOR          varchar2(30); 
 
begin 
-- Initialize variables 
  V_WAITING_APPROVAL := 1; 
  V_COUNT            := 0; 
 
V_HTML := '<tr> 
    <td align="center" valign="top" style="padding: 0 18px 18px 18px;"> 
      
      <p style="font-size: 16px; font-family:Oracle Sans, Noto Sans, Helvetica, Arial, Sans; color: #000000; line-height:18px; margin-bottom:8px; text-align:justify;"> 
        Please find below the <span style="font-size: 16px;  color: #A45A52;">Vacation Leave Days</span> that are <font style="color:#A45A52;">pending approval on your side</font>. Please login into the tool using the link below and take the necessary steps to approve or reject these requests. 
      </p> 
      <table width="90%" border="0" cellpadding="0" cellspacing="0" style="font-size: 16px; font-family:Oracle Sans, Noto Sans, Helvetica, Arial, Sans; color: #000000; line-height:18px; margin-bottom:8px; padding:0 0 18px 0;"> 
        <tr width="100%" bgcolor="#F5EAE7"> 
          <td align="middle" width="40%" style="padding:5px; color:#A45A52;">Employee Email</td> 
          <td align="middle" width="20%" style="padding:5px; color:#A45A52;">First Day of Leave</td> 
          <td align="middle" width="20%" style="padding:5px; color:#A45A52;">Last Day of Leave</td> 
          <td align="middle" width="20%" style="padding:5px; color:#A45A52;">Number of Leave Days</td> 
        </tr>';

 
  for X in (select lower(AR.EMP_EMAIL) EMP_EMAIL 
                  ,TO_CHAR(AR.LEAVE_START,'dd-Mon-yyyy') LEAVE_START 
                  ,TO_CHAR(AR.LEAVE_END,'dd-Mon-yyyy') LEAVE_END 
                  ,AR.NO_WORK_DAYS_LEAVE 
              from AA_REQUESTS AR JOIN AA_EMPLOYEES AE ON AR.EMP_EMAIL = AE.EMP_EMAIL
              where LOWER(AR.EMAIL_TO) = LOWER(P_MNG_EMAIL) 
              and AR.AA_STATUS_ID = V_WAITING_APPROVAL AND AR.EMAIL_TO != '-1' AND AE.AA_COUNTRY_ID != 28
              order by AR.EMP_EMAIL, AR.LEAVE_START 
            ) 
  LOOP 

    bhu_logs(6004,'log6004 : '||systimestamp|| ' :- GET_MNG_NO_ACTION_EML ',X.EMP_EMAIL);
    V_BG_COLOR := '#FBF9F3'; 
 
 
    V_LINE := ' 
        <tr bgcolor="'||V_BG_COLOR||'"> 
          <td align="middle" width="40%" style="padding:5px;color:#000000;">'||X.EMP_EMAIL||'</td> 
          <td align="middle" width="20%" style="padding:5px;color:#000000;">'||X.LEAVE_START||'</td> 
          <td align="middle" width="20%" style="padding:5px;color:#000000;">'||X.LEAVE_END||'</td> 
          <td align="middle" width="20%" style="padding:5px;color:#000000;">'||X.NO_WORK_DAYS_LEAVE||'</td> 
        </tr>'; 
 
    V_HTML := V_HTML||V_LINE; 
 
    V_COUNT := V_COUNT + 1; 
 
  end loop; 
 
  V_HTML := V_HTML||' 
      </table> 
    </td> 
  </tr>'; 
 
-- If there is at least one pending request fill it in the final email template 
  if V_COUNT > 0 
    then 
 
      V_TEXT     := 'You have '||V_COUNT||' vacation leave days that are pending your approval. Please use the link below to see which requests are pending and take the necessary actions to approve or reject them.'; 
 
--      P_EML_HTML := replace(P_EML_HTML,'[[$$PENDING_REQUESTS]]',V_HTML); 
      P_EML_HTML := WS_TOOLS.CLOB_REPLACE(P_EML_HTML,TO_CLOB('[[$$PENDING_REQUESTS]]'),V_HTML); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$PENDING_REQUESTS]]',V_TEXT); 
 
  else 
  -- Otherwise remove the wording "[[$$PENDING_REQUESTS]]" 
      P_EML_HTML := replace(P_EML_HTML,'[[$$PENDING_REQUESTS]]'); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$PENDING_REQUESTS]]'); 
 
  end if; 
 
-- Call IVACATION_OOH.PROCESS_MNG_PENDING_REQUESTS to process any pending OOH requests 
  IVACATION_OOH.PROCESS_MNG_PENDING_REQUESTS( 
    P_MNG_EMAIL => P_MNG_EMAIL 
   ,P_EML_HTML  => P_EML_HTML 
   ,P_EML_TEXT  => P_EML_TEXT 
  ); 
 
end PROCESS_MNG_PENDING_REQUESTS; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PROCESS_MANAGER_SUMMARY 
-- Type:            procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Processes and appends to the final email template the directs of the manager 
-- 
--***************************************** 
procedure PROCESS_MANAGER_SUMMARY(P_MANAGER_EMAIL varchar2, P_MONTH date, P_EML_HTML in OUT clob, P_EML_TEXT in OUT clob) 
is 
 
  V_APPROVED          AA_REQUESTS.AA_STATUS_ID%type; 
 
  V_HTML              clob; 
  V_TEXT              varchar2(255); 
  V_LINE              clob; 
  V_COUNT             PLS_INTEGER; 
  V_MOD               PLS_INTEGER; 
  V_BG_COLOR          varchar2(30); 
  V_MNG_TYPE      varchar2(3); 
 
begin 
-- Initialize variables 
  V_APPROVED := 2; 
  V_COUNT    := 0; 
  V_MNG_TYPE    := 'MNG'; 
 
-- Create the heding of the report 
  V_HTML := '<tr> 
  <td align="center" valign="top" style="padding: 0 18px 18px 18px;"> 
  
    <p style="font-size: 16px; font-family:Oracle Sans, Noto Sans, Helvetica, Arial, Sans; color: #000000; line-height:18px; margin-bottom:8px; text-align:justify;"> 
      Please find below the <span style="font-size: 16px; color: #A45A52;">Vacation Balances</span> for all of your directs in countries that use iVacation for the month of <span style="color: #A45A52;">[[$$MONTH_AND_YEAR]]</span>: 
    </p> 
    <table width="90%" border="0" cellpadding="0" cellspacing="0" style="font-size: 16px; font-family:Oracle Sans, Noto Sans, Helvetica, Arial, Sans; color: #000000; line-height:18px; margin-bottom:8px; padding:0 0 18px 0;"> 
      <tr width="100%" bgcolor="#F5EAE7"> 
        <td align="middle" width="30%" style="padding:5px; color:#A45A52;">Employee Email</td> 
        <td align="middle" width="18%" style="padding:5px; color:#A45A52;">Leave Balance at the beginning of the month</td> 
        <td align="middle" width="18%" style="padding:5px; color:#A45A52;">Leave Taken during the month</td> 
        <td align="middle" width="18%" style="padding:5px; color:#A45A52;">Leave Balance at the end of the month</td> 
        <td align="middle" width="16%" style="padding:5px; color:#A45A52;">Vacation Plan</td> 
      </tr>'; 
 
-- Construct all the rows for all the direct employees 
  for X in (select LOWER(E.EMP_EMAIL) EMP_EMAIL 
                  ,ROUND(O.ACCRUED,2) ACCRUED 
                  ,O.LEAVE_TAKEN 
                  ,ROUND(O.LEAVE_BALANCE,2) LEAVE_BALANCE 
                  ,ACVI.PLAN_DESC 
              from AA_EMPLOYEES E 
              join AA_OVERVIEW O on E.EMP_EMAIL = O.EMP_EMAIL 
              join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_VP_INT_ID = O.AA_COUNTRY_VP_INT_ID 
              where LOWER(E.EMP_MANAGER) = lower(P_MANAGER_EMAIL) 
              and TRUNC(O.month,'mm') = TRUNC(P_MONTH,'mm') 
              and E.END_DATE is null 
              and E.AA_COUNTRY_ID != 28
              order by E.EMP_EMAIL 
            ) 
  loop 
  -- Set the background color for the rows 
    -- if MOD(V_COUNT,2) = 0 
    --   then 
        V_BG_COLOR := '#FBF9F3'; 
    -- else 
    --   V_BG_COLOR := '#dddddd'; 
    -- end if; 
 
    V_LINE := ' 
        <tr bgcolor="'||V_BG_COLOR||'"> 
          <td align="middle" width="30%" style="padding:5px;color:#000000;">'||X.EMP_EMAIL||'</td> 
          <td align="middle" width="18%" style="padding:5px;color:#000000;">'||X.ACCRUED||'</td> 
          <td align="middle" width="18%" style="padding:5px;color:#000000;">'||X.LEAVE_TAKEN||'</td> 
          <td align="middle" width="18%" style="padding:5px;color:#000000;">'||X.LEAVE_BALANCE||'</td> 
          <td align="middle" width="16%" style="padding:5px;color:#000000;">'||X.PLAN_DESC||'</td> 
        </tr>'; 
 
    V_HTML := V_HTML||V_LINE; 
 
    V_COUNT := V_COUNT + 1; 
 
  end loop; 
 
  V_HTML := V_HTML||' 
      </table> 
    </td> 
  </tr>'; 
 
-- If the manager has at leat one direct employee add the table with the vacation balance 
  if V_COUNT > 0 
    then 
 
      V_TEXT     := 'To see your directs detailed requests please use the link below.'; 
 
--      P_EML_HTML := replace(P_EML_HTML,'[[$$DIRECT_EMPS_REQUESTS]]',V_HTML); 
      P_EML_HTML := WS_TOOLS.CLOB_REPLACE(P_EML_HTML,TO_CLOB('[[$$DIRECT_EMPS_REQUESTS]]'),V_HTML); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$DIRECT_EMPS_REQUESTS]]',V_TEXT); 
 
  else 
  -- Otherwise remove the wording "[[$$DIRECT_EMPS_REQUESTS]]" 
      P_EML_HTML := replace(P_EML_HTML,'[[$$DIRECT_EMPS_REQUESTS]]'); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$DIRECT_EMPS_REQUESTS]]'); 
 
  end if; 
 
-- Check if the country has Out Of Hours and if it has process the requests 
  IVACATION_OOH.PROCESS_MONTLHY_EMAIL( 
    P_EMP_EMAIL => P_MANAGER_EMAIL 
   ,P_MONTH     => P_MONTH 
   ,P_TYPE      => V_MNG_TYPE 
   ,P_EML_HTML  => P_EML_HTML 
   ,P_EML_TEXT  => P_EML_TEXT 
  ); 
 
end PROCESS_MANAGER_SUMMARY; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_MNG_MONTHLY_REV_EML 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Creates the html for the manager monthly vacation summary email 
-- 
--***************************************** 
procedure GET_MNG_MONTHLY_REV_EML(P_MNG_EMAIL varchar2 
                                 ,P_MONTH date 
                                 ,P_EML_HTML OUT clob 
                                 ,P_EML_TEXT OUT clob) 
is 
 
  V_TEMPLATE_ID   number; 
  V_LINK          varchar2(1000); 
  V_MONTH         varchar2(30); 
 
  V_EML_HTML      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
  V_ACCRUED       AA_OVERVIEW.ACCRUED%type; 
  V_LEAVE_TAKEN   AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_LEAVE_BALANCE AA_OVERVIEW.LEAVE_BALANCE%type; 
 
begin 
-- Initialize the variables 
  V_TEMPLATE_ID := 5; -- Manager Monthly Review 
  V_LINK        := CONSTRUCT_LINK('14'); 
  V_MONTH       := TO_CHAR(P_MONTH,'fmMonth YYYY'); 
 
-- Get the email templates 
  select EMAIL_TEMPLATE, EMAIL_TEMPLATE_TEXT 
    into V_EML_HTML, V_EML_TEXT 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = V_TEMPLATE_ID; 
 
-- Process pending requests and detailed leaves 
  PROCESS_MANAGER_SUMMARY(P_MNG_EMAIL,P_MONTH,V_EML_HTML,V_EML_TEXT); 
  PROCESS_MNG_PENDING_REQUESTS(P_MNG_EMAIL,V_EML_HTML,V_EML_TEXT); 
 
-- Replace the placeholders 
  V_EML_HTML := replace(V_EML_HTML,'[[$$MONTH_AND_YEAR]]',V_MONTH); 
  V_EML_TEXT := replace(V_EML_TEXT,'[[$$MONTH_AND_YEAR]]',V_MONTH); 
 
-- Replace the Link 
--   V_EML_HTML := replace(V_EML_HTML,'[[$$LINK]]','<a href="'||V_LINK||'">link</a>'); 

  ---rohit commit -> update V_EML_HTML , remove '<a href="'||V_LINK||'">link</a>' 
  V_EML_HTML := replace(V_EML_HTML,'[[$$LINK]]',V_LINK); 


  V_EML_TEXT := replace(V_EML_TEXT,'[[$$LINK]]',V_LINK); 
 
-- Return the final email templates 
  P_EML_HTML := V_EML_HTML; 
  P_EML_TEXT := V_EML_TEXT; 
 
end GET_MNG_MONTHLY_REV_EML; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            SEND_MNG_MONTHLY_REV_EML 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to send emails to all managers with their directs vacation summary 
-- 
--***************************************** 
procedure SEND_MNG_MONTHLY_REV_EML(P_DATE date default localtimestamp) 
is 
 
  V_MNG_ARRAY   APEX_APPLICATION_GLOBAL.VC_ARR2; 
  V_SUBJECT     varchar2(100); 
 
  V_EML_HTML      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
begin 
-- Initialize variables 
  V_SUBJECT := 'iVacation Manager Monthly Summary - '||to_char(P_DATE,'fmMonth YYYY'); 
 
 
  -- Get all the active employees 
    select distinct(EMP_MANAGER) 
     bulk collect into V_MNG_ARRAY 
     from AA_EMPLOYEES 
     where END_DATE is null 
     and NVL(EMP_MANAGER,'-1') != '-1' 
     and TRUNC(P_DATE,'MM') >= TRUNC(START_DATE,'MM') and AA_COUNTRY_ID != 28 ; -- Send the email only starting with the month when the employee joined Oracle; 
 
-- Send an email to all employees 
  for I in V_MNG_ARRAY.first..V_MNG_ARRAY.last 
  LOOP 
    -- Process the emails 
    GET_MNG_MONTHLY_REV_EML(P_MNG_EMAIL => V_MNG_ARRAY(I) 
                           ,P_MONTH     => P_DATE 
                           ,P_EML_HTML  => V_EML_HTML 
                           ,P_EML_TEXT  => V_EML_TEXT 
                           ); 
     bhu_logs(6003,'log6003 : '||systimestamp|| ' :- ADD_MONTH_4JOB > SEND_MNG_MONTHLY_REV_EML ', 'from - ' || C_EML_FROM ||' To -'|| V_MNG_ARRAY(I));
      APEX_MAIL.SEND(
                    P_TO =>  (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_MNG_ARRAY(I) else c_default_mail_list end)
                   ,P_FROM       => C_EML_FROM 
                   ,P_BODY       => to_clob(' ')--V_EML_TEXT 
                   ,P_BODY_HTML  => V_EML_HTML 
                   ,P_SUBJ       => V_SUBJECT 
                  ); 
 
  end loop; 
 
  APEX_MAIL.PUSH_QUEUE; 
 
end SEND_MNG_MONTHLY_REV_EML; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PROCESS_MANAGER_SUMMARY 
-- Type:            procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Processes and appends to the final email template the directs of the manager 
-- 
--***************************************** 
procedure PROCESS_EMPS_NO_MANAGER(P_COUNTRIES   varchar2, P_EML_HTML in OUT clob, P_EML_TEXT in OUT clob) 
is 
 
  V_APPROVED          AA_REQUESTS.AA_STATUS_ID%type; 
 
  V_HTML              clob; 
  V_TEXT              varchar2(255); 
  V_LINE              clob; 
  V_COUNT             PLS_INTEGER; 
  V_MOD               PLS_INTEGER; 
  V_BG_COLOR          varchar2(30); 
 
  E_NO_MAIL           exception; 
 
begin 
-- Initialize variables 
  V_APPROVED := 2; 
  V_COUNT    := 0; 
 
-- Create the heding of the report 
V_HTML := '<tr>
  <td align="center" valign="top" style="padding: 0 18px 18px 18px;">
    <p style="font-family:Oracle Sans, Noto Sans, Helvetica, Arial, Sans; color: #000000; line-height: 20px; margin-bottom: 12px; text-align: justify;">
      Manager email not found in the application for the below employees. Please review.</span>
    </p>

    <table width="90%" border="0" cellpadding="0" cellspacing="0"
           style="font-family:Oracle Sans, Noto Sans, Helvetica, Arial, Sans; color: #333333; border-collapse: collapse; margin-bottom: 16px;">
      <tr style="background-color: #F5EAE7;">
        <th align="left" width="33%" style="padding: 10px; border: 1px solid #ddd;  color: #A45A52;">Employee Name</th>
        <th align="left" width="33%" style="padding: 10px; border: 1px solid #ddd;  color: #A45A52;">Employee Email</th>
        <th align="left" width="34%" style="padding: 10px; border: 1px solid #ddd;  color: #A45A52;">Country</th>
      </tr>';

-- Construct the rows for the employees that don't have a manager and don't have an END_DATE 
  for X in (select E.EMP_NAME 
                  ,LOWER(E.EMP_EMAIL) EMP_EMAIL 
                  ,to_char(E.START_DATE,'dd-Mon-yyyy') START_DATE 
                  ,C.COUNTRY_NAME 
              from AA_EMPLOYEES E 
              join AA_COUNTRIES c on C.AA_COUNTRY_ID = E.AA_COUNTRY_ID 
              where NVL(E.EMP_MANAGER,'-1') = '-1' 
              and E.END_DATE is null 
              and c.aa_country_id in (select COLUMN_VALUE  
                                      from table(APEX_STRING.SPLIT(P_COUNTRIES,',')))             
              order by C.COUNTRY_NAME, E.EMP_EMAIL 
            ) 
  loop 
  -- Set the background color for the rows 
   
        V_BG_COLOR := '#FBF9F3'; 
    
 
    V_LINE := ' 
        <tr bgcolor="'||V_BG_COLOR||'"> 
          <td align="middle" width="33%" style="padding:5px;color:#000000;">'||X.EMP_NAME||'</td> 
          <td align="middle" width="33%" style="padding:5px;color:#000000;">'||X.EMP_EMAIL||'</td> 
          <td align="middle" width="33%" style="padding:5px;color:#000000;">'||X.COUNTRY_NAME||'</td> 
        </tr>'; 
 
    V_HTML := V_HTML||V_LINE; 
 
    V_COUNT := V_COUNT + 1; 
 
  end loop; 
 
  V_HTML := V_HTML||' 
      </table> 
    </td> 
  </tr>'; 
 
-- If the manager has at leat one direct employee add the table with the vacation balance 
  if V_COUNT > 0 
    then 
 
      V_TEXT     := 'There are '||V_COUNT||' employees that dont''t have an end_date nor a manager. Please use the link below to check if they are still active employees.'; 
 
--      P_EML_HTML := replace(P_EML_HTML,'[[$$EMPLOYEE_LIST]]',V_HTML); 
      P_EML_HTML := WS_TOOLS.CLOB_REPLACE(P_EML_HTML,TO_CLOB('[[$$EMPLOYEE_LIST]]'),V_HTML); 
      P_EML_TEXT := replace(P_EML_TEXT,'[[$$EMPLOYEE_LIST]]',V_TEXT); 
 

          bhu_logs(1,'log1'||systimestamp,P_EML_HTML);
          bhu_logs(2,'log2'||systimestamp,P_EML_TEXT);
  else 
  -- Otherwise return parameters null 
        
      P_EML_HTML := null; 
      P_EML_TEXT := null; 
 
  end if; 
 
 
end PROCESS_EMPS_NO_MANAGER; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_EMPS_NO_MANAGER_EML 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Creates the html for the employees without a manager 
-- 
--***************************************** 
procedure GET_EMPS_NO_MANAGER_EML(P_COUNTRIES varchar2 
                                 ,P_EML_HTML OUT clob 
                                 ,P_EML_TEXT OUT clob) 
is 
 
  V_TEMPLATE_ID   number; 
  V_LINK          varchar2(1000); 
 
  V_EML_HTML      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
  V_ACCRUED       AA_OVERVIEW.ACCRUED%type; 
  V_LEAVE_TAKEN   AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_LEAVE_BALANCE AA_OVERVIEW.LEAVE_BALANCE%type; 
 
begin 
-- Initialize the variables 
  V_TEMPLATE_ID := 6; -- Employees with no manager 
  V_LINK        := CONSTRUCT_LINK('14'); 
 
-- Get the email templates 
  select EMAIL_TEMPLATE, EMAIL_TEMPLATE_TEXT 
    into V_EML_HTML, V_EML_TEXT 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = V_TEMPLATE_ID; 
 
-- Process pending requests and detailed leaves 
  PROCESS_EMPS_NO_MANAGER(P_COUNTRIES, V_EML_HTML,V_EML_TEXT); 
 
-- Replace the Link 
  V_EML_HTML := replace(V_EML_HTML,'[[$$LINK]]',V_LINK); 
 
  V_EML_TEXT := replace(V_EML_TEXT,'[[$$LINK]]',V_LINK); 
 
-- Return the final email templates 
  P_EML_HTML := V_EML_HTML; 
  P_EML_TEXT := V_EML_TEXT; 
 
end GET_EMPS_NO_MANAGER_EML; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            SEND_MNG_MONTHLY_REV_EML 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to send emails to all managers with their directs vacation summary 
-- 
--***************************************** 
procedure SEND_EMPS_NO_MANAGER_EML 
is 
 
  V_MNG_ARRAY   APEX_APPLICATION_GLOBAL.VC_ARR2; 
  V_SUBJECT     varchar2(100); 
  V_TO          varchar2(100); 
 
  V_EML_HTML    AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT    AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
  ALL_MANAGERS_ACCOUNTED_FOR  EXCEPTION; 
  PRAGMA        EXCEPTION_INIT(all_managers_accounted_for, -20131); 
 
begin 
-- Initialize variables 
  V_SUBJECT := 'iVacation Employees without a manager'; 
  --V_TO      := 'hrops-support-emea_ww@oracle.com'; 
 
-- Set the security id to be able to send emails without an apex session 
  SET_SECURITY_ID; 
   
  for x in (select nvl(GENERIC_EMAIL_ADDRESS,'hrops-support-emea_ww@oracle.com') GENERIC_EMAIL_ADDRESS , 
                    listagg(aa_country_id,',') countries 
            from AA_COUNTRIES  
            where ACTIVE = 1 and AA_COUNTRY_ID != 28
            group by nvl(GENERIC_EMAIL_ADDRESS,'hrops-support-emea_ww@oracle.com')) loop 
     
-- Get the filled in email templates 
  GET_EMPS_NO_MANAGER_EML(P_COUNTRIES => x.COUNTRIES 
                         ,P_EML_HTML => V_EML_HTML 
                         ,P_EML_TEXT => V_EML_TEXT); 
  
     bhu_logs(6001,'log6001 : '||systimestamp|| ' :- UPDATE_EMP_INFO_4JOB > SEND_EMPS_NO_MANAGER_EML ', x.GENERIC_EMAIL_ADDRESS);
    if V_EML_HTML is not null then 
        APEX_MAIL.SEND(
                       P_TO =>  (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then x.GENERIC_EMAIL_ADDRESS else c_default_mail_list end)
                      ,P_FROM       => C_EML_FROM 
                      ,P_BODY       => to_clob(' ')--V_EML_TEXT 
                      ,P_BODY_HTML  => V_EML_HTML 
                      ,P_SUBJ       => V_SUBJECT 
                    ); 
    bhu_logs(44,'if mail sent SEND_EMPS_NO_MANAGER_EML'||systimestamp,x.GENERIC_EMAIL_ADDRESS );

     end if;            
   
  end loop; 
 
  APEX_MAIL.PUSH_QUEUE; 
 
-- Handle the E_NO_MAIL exception raised in PROCESS_EMPS_NO_MANAGER 
-- This means that there are no employees without manager and the procedure shouldn't do anything 
  EXCEPTION 
    when ALL_MANAGERS_ACCOUNTED_FOR 
      then null; 
 
end SEND_EMPS_NO_MANAGER_EML; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_MNG_NO_ACTION_EML 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Creates the html for the manager no action email 
-- 
--***************************************** 
procedure GET_MNG_NO_ACTION_EML(P_MNG_MAIL varchar2 
                               ,P_EML_HTML OUT clob 
                               ,P_EML_TEXT OUT clob) 
is 
 
  V_TEMPLATE_ID   number; 
  V_LINK          varchar2(1000); 
 
  V_EML_HTML      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT      AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
  V_ACCRUED       AA_OVERVIEW.ACCRUED%type; 
  V_LEAVE_TAKEN   AA_OVERVIEW.LEAVE_BALANCE%type; 
  V_LEAVE_BALANCE AA_OVERVIEW.LEAVE_BALANCE%type; 
 
begin 
-- Initialize the variables 
  V_TEMPLATE_ID := 7; -- Manager No Action 
  V_LINK        := CONSTRUCT_LINK('14'); 
 
-- Get the email templates 
  select EMAIL_TEMPLATE, EMAIL_TEMPLATE_TEXT 
    into V_EML_HTML, V_EML_TEXT 
    from AA_EMAIL_TEMPLATES 
    where EMAIL_TEMPLATE_ID = V_TEMPLATE_ID; 
 
-- Process pending requests and detailed leaves 
  PROCESS_MNG_PENDING_REQUESTS(P_MNG_MAIL,V_EML_HTML,V_EML_TEXT); 
 
-- Replace the Link 
--   V_EML_HTML := replace(V_EML_HTML,'[[$$LINK]]','<a href="'||V_LINK||'">link</a>'); 
  V_EML_HTML := replace(V_EML_HTML,'[[$$LINK]]',V_LINK); 
 
  V_EML_TEXT := replace(V_EML_TEXT,'[[$$LINK]]',V_LINK); 
 
-- Return the final email templates 
  P_EML_HTML := V_EML_HTML; 
  P_EML_TEXT := V_EML_TEXT; 
 
end GET_MNG_NO_ACTION_EML; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            SEND_MNG_NO_ACTION_EML_4JOB 
-- Type:            function 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to send emails to all managers with their directs vacation summary 
-- 
--***************************************** 
procedure SEND_MNG_NO_ACTION_EML_4JOB 
is 
 
  V_MNG_ARRAY         APEX_APPLICATION_GLOBAL.VC_ARR2; 
  V_SUBJECT           varchar2(100); 
  V_REMINDER_INTERVAL PLS_INTEGER; 
  V_DAYS_TO_LEAVE     PLS_INTEGER; 
 
  V_EML_HTML          AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE%type; 
  V_EML_TEXT          AA_EMAIL_TEMPLATES.EMAIL_TEMPLATE_TEXT%type; 
 
begin 
-- Initialize variables 
  V_SUBJECT              := 'iVacation Requests pending your attention'; 
  V_REMINDER_INTERVAL    := 4; 
  V_DAYS_TO_LEAVE        := 16; 
 
-- Set the security id to be able to send emails without an apex session 
  SET_SECURITY_ID; 
 
-- Get all the managers that need to receive a reminder 
-- Managers that have vacation or OOH requests pending 
  select EML 
    bulk collect into V_MNG_ARRAY 
    from ( 
         select a.EML from
        (select distinct(EMAIL_TO) EML 
            from AA_REQUESTS 
            where AA_STATUS_ID = 1 
            and MOD(TRUNC(sysdate) - TRUNC(CREATION_DATE),V_REMINDER_INTERVAL) = 0 
            and TRUNC(LEAVE_START) - TRUNC(sysdate) <= V_DAYS_TO_LEAVE AND EMAIL_TO != '-1' 
 
          UNION 
 
          select distinct(EMP_MNG) EML 
            from AA_OOH_REQUESTS 
            where AA_OOH_STATUS_ID = 6 -- Pending Manager Approval 
            and MOD(TRUNC(sysdate) - TRUNC(CREATION_DATE),V_REMINDER_INTERVAL) = 0 
            and TRUNC(START_DATE) - TRUNC(sysdate) <= V_DAYS_TO_LEAVE AND EMP_MNG != '-1' ) a join AA_EMPLOYEES b on a.EML = b.EMP_EMAIL and b.AA_COUNTRY_ID != 28 
         
         ); 
 
-- Get the filled in email templates 
for I in V_MNG_ARRAY.first..V_MNG_ARRAY.last 
  LOOP 
 
  -- Get the email templates 
    GET_MNG_NO_ACTION_EML(P_MNG_MAIL => V_MNG_ARRAY(I) 
                         ,P_EML_HTML => V_EML_HTML 
                         ,P_EML_TEXT => V_EML_TEXT 
                         ); 
    bhu_logs(6000,'log6000 : '||systimestamp|| ' :- SEND_MNG_NO_ACTION_EML_4JOB ',V_MNG_ARRAY(I));
    APEX_MAIL.SEND(
                   P_TO         =>  (case when WS_TOOLS.is_prod_env = WS_TOOLS.c_Yes then  V_MNG_ARRAY(I) else c_default_mail_list end)
                  ,P_FROM       => C_EML_FROM 
                  ,P_BODY       => V_EML_TEXT 
                  ,P_BODY_HTML  => V_EML_HTML 
                  ,P_SUBJ       => V_SUBJECT 
                 ); 
 
  end loop; 
 
  APEX_MAIL.PUSH_QUEUE; 
 
end SEND_MNG_NO_ACTION_EML_4JOB; 
 
 
 
 
 
----------- This procedure has been moved to use the HR_SECURED_VIEWS for 
----------- performance and accuracy reasons 
----------- Alex Banu - 23-Oct-2017 
 
--***************************************** 
-- 
-- Name:            UPDATE_MANAGER 
-- Type:            Procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to update the all of the employees managers 
-- 
--***************************************** 
-- procedure UPDATE_MANAGER 
-- is 
-- 
--   V_EMP_LIST      APEX_APPLICATION_GLOBAL.VC_ARR2; 
--   V_EX_EMP_LIST   APEX_APPLICATION_GLOBAL.VC_ARR2; 
--   V_MANAGER       varchar2(100); 
--   V_PENDING       PLS_INTEGER := 1; 
-- 
-- begin 
-- -- Get all the employees 
--   select EMP_EMAIL 
--     bulk collect into V_EMP_LIST 
--     from AA_EMPLOYEES 
--     where END_DATE is null; 
-- 
-- -- Loop through the employees 
--   for I in V_EMP_LIST.first..V_EMP_LIST.last 
--   LOOP 
--   -- Get the manager 
--     V_MANAGER := LDAP.GET_MANAGER(V_EMP_LIST(I)); 
-- 
--     if V_MANAGER != '-1' then 
--     -- Update the manager on the employee record 
--       update AA_EMPLOYEES 
--         set EMP_MANAGER = V_MANAGER 
--         where EMP_EMAIL = V_EMP_LIST(I); 
-- 
-- -- No need to do it here as I moved it to the AA_EMPLOYEES_IU trigger 
--     -- Update the EMAIL_TO field in the requests table 
--     --  where the current manager is different fromt the approver 
--     --  and the status is Waiting Approver 
-- --      update AA_REQUESTS 
-- --        set EMAIL_TO = V_MANAGER 
-- --        where EMP_EMAIL = V_EMP_LIST(I) 
-- --        and AA_STATUS_ID = V_PENDING 
-- --        and EMAIL_TO != V_MANAGER; 
-- 
--     end if; 
-- 
--     --DBMS_OUTPUT.PUT_LINE(rpad(i||'.',4)||rpad(V_EMP_LIST(I),40)||' - manager: '||WS_TOOLS.GET_LDAP_MANAGER(V_EMP_LIST(I))); 
--   end LOOP; 
-- 
-- -- Send email with all the active employees without managers 
--   SEND_EMPS_NO_MANAGER_EML; 
-- 
-- end UPDATE_MANAGER; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            UPDATE_EMP_INFO 
-- Type:            Procedure 
-- Creation date:   23-Oct-2017 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to update the all of the employees managers 
-- 
--***************************************** 
procedure UPDATE_EMP_INFO 
is 
 
begin 
   merge into AA_EMPLOYEES AE 
    using ( select upper(AE.EMP_EMAIL) EMP_EMAIL 
                  ,NVL(MD.MANAGER_EMAIL_ADDRESS,'-1') EMP_DIRECT_MANAGER 
                  ,MD.LEGACY_COST_CENTER COST_CENTRE 
            from AA_EMPLOYEES AE 
            left join MD_EMPLOYEES MD on UPPER(AE.EMP_EMAIL) = upper(MD.EMP_EMAIL_ADDRESS) and MD.IS_ACTIVE = 'Y'
            where NVL(END_DATE,trunc(SYSDATE + 1)) >= trunc(SYSDATE)  and upper(MD.MANAGER_EMAIL_ADDRESS) not in ('FATIMA.MOUAK@ORACLE.COM' , 'SARA.OUMINA@ORACLE.COM') and AE.AA_COUNTRY_ID != 28 
          ) S1 
    on (AE.EMP_EMAIL = S1.EMP_EMAIL) 
    when matched then update set EMP_MANAGER = upper(S1.EMP_DIRECT_MANAGER) 
                                ,COST_CENTER = S1.COST_CENTRE 
                      where (upper(AE.EMP_MANAGER) != upper(S1.EMP_DIRECT_MANAGER) 
                          or AE.COST_CENTER != S1.COST_CENTRE 
                            ); 

 
 


-- Send email for employees without managers 
  SEND_EMPS_NO_MANAGER_EML; 
 
end UPDATE_EMP_INFO; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            UPDATE_EMP_INFO 
-- Type:            Procedure 
-- Creation date:   23-Oct-2017 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to update the manager of an employee 
-- 
--***************************************** 
procedure UPDATE_EMP_INFO( 
  P_EMP_EMAIL AA_EMPLOYEES.EMP_EMAIL%type 
) 
is 
 
begin 
 
   merge into AA_EMPLOYEES AE 
    using ( select upper(AE.EMP_EMAIL) EMP_EMAIL 
                  ,NVL(MD.MANAGER_EMAIL_ADDRESS,'-1') EMP_DIRECT_MANAGER 
                  ,MD.LEGACY_COST_CENTER COST_CENTRE 
            from AA_EMPLOYEES AE 
            left join MD_EMPLOYEES MD on UPPER(AE.EMP_EMAIL) = upper(MD.EMP_EMAIL_ADDRESS) and MD.IS_ACTIVE = 'Y'
            where NVL(END_DATE,trunc(SYSDATE + 1)) >= trunc(SYSDATE) 
            and upper(AE.EMP_EMAIL) = upper(P_EMP_EMAIL) and upper(MD.MANAGER_EMAIL_ADDRESS) not in ('FATIMA.MOUAK@ORACLE.COM' , 'SARA.OUMINA@ORACLE.COM') and AE.AA_COUNTRY_ID != 28 
          ) S1 
    on (AE.EMP_EMAIL = S1.EMP_EMAIL) 
    when matched then update set EMP_MANAGER = upper(S1.EMP_DIRECT_MANAGER) 
                                ,COST_CENTER = S1.COST_CENTRE 
                      where (upper(AE.EMP_MANAGER) != upper(S1.EMP_DIRECT_MANAGER) 
                          or AE.COST_CENTER != S1.COST_CENTRE 
                            ); 
     



end UPDATE_EMP_INFO; 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            UPDATE_EMP_INFO_4JOB 
-- Type:            Procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to update the all of the employees managers 
-- 
--***************************************** 
procedure UPDATE_EMP_INFO_4JOB 
is 
 
 V_MONDAY  varchar2(1) := '2'; 


 
begin 
-- If it's monday 
  if TO_CHAR(sysdate,'d') = V_MONDAY 
    then 
 
      UPDATE_EMP_INFO; 
 
  end if; 
 
end UPDATE_EMP_INFO_4JOB; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            ADD_MONTH_4JOB 
-- Type:            Procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to add a new month on the first day of the month 
--                  and send summary notifications to employees and managers 
-- 
--***************************************** 
procedure ADD_MONTH_4JOB 
is 
 
  V_ARRAY                  APEX_APPLICATION_GLOBAL.VC_ARR2; 
  V_DATE                   date; 
 
begin 

-- If it's the first day of the month 
  if TRUNC(sysdate) = TRUNC(sysdate,'mm') 
    then 
    -- Get the list of employees that have a monthly accrual vacation plan 
      select distinct AE.EMP_EMAIL 
        bulk collect into V_ARRAY 
        from AA_EMPLOYEES AE 
        where (AE.END_DATE is null or TRUNC(AE.END_DATE) > TRUNC(sysdate)) and AE.AA_COUNTRY_ID != 28 ; 

 
    -- Construct the date 
    -- This guarantees that the new month starts on the first each time 
    V_DATE := TO_DATE('01'||TO_CHAR(TRUNC(sysdate + 2),'mm.yyyy'),'dd.mm.yyyy'); 
 
    -- For each create a new month 
      for I in 1..V_ARRAY.COUNT 
      LOOP 
 
        IVACATION.NEW_MONTH(V_ARRAY(I),V_DATE); 
 
      end LOOP; 
    --Send employee and manager sumary notification for the previous month 
    SEND_EMP_MONTHLY_REV_EML(P_DATE => TRUNC(sysdate - 2)); 
    SEND_MNG_MONTHLY_REV_EML(P_DATE => TRUNC(sysdate - 2));  
    
 end if; 

   
end ADD_MONTH_4JOB; 
 
 
 
 
--***************************************** 
-- 
-- Name:            PRINT_HTML 
-- Type:            Procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to generate the HTML for own vacation balance 
-- 
--***************************************** 
procedure PRINT_HTML(P_CLOB clob) 
is 
 
  V_START   PLS_INTEGER; 
  V_END     PLS_INTEGER; 
  V_LENGTH  PLS_INTEGER; 
  V_AMOUNT  PLS_INTEGER; 
  V_BUFFER  varchar2(255); 
 
begin 
-- Get the length of the clob 
  V_LENGTH := DBMS_LOB.GETLENGTH(P_CLOB); 
  V_AMOUNT := 255; 
  --V_START  := 0; 
  V_END    := 1; 
 
--      DBMS_OUTPUT.PUT_LINE('V_LENGTH -> '||V_LENGTH); 
 
  WHILE V_END <= V_LENGTH 
  LOOP 
 
    V_BUFFER := DBMS_LOB.SUBSTR (LOB_LOC => P_CLOB 
                                ,AMOUNT  => V_AMOUNT 
                                ,OFFSET  => V_END); 
      /* 
      DBMS_OUTPUT.PUT_LINE('V_END -> '||V_END); 
      DBMS_OUTPUT.PUT_LINE('V_BUFFER -> '||V_BUFFER); 
      */ 
 
    V_END := V_END + V_AMOUNT; 
 
  end LOOP; 
 
end PRINT_HTML; 
 
 
 
 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            GENERATE_OWN_VACATION 
-- Type:            Procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to generate the HTML for own vacation balance 
-- 
--***************************************** 
procedure GENERATE_OWN_VACATION(P_EMP_EMAIL varchar2 
                               ,P_MONTH     date) 
is 
 
  V_HTML    clob; 
  V_DUMMY   clob; -- We don't need this variable but we need to provide a paramtere to PROCESS_DETAILED_REQUESTS 
 
begin 
-- Begin HTML 
  V_HTML := '<div id="mainVacation"> 
  [[$$DETAILED_REQUESTS]]'; 
 
-- Process the detailed requests 
  PROCESS_DETAILED_REQUESTS(P_EMP_EMAIL => P_EMP_EMAIL 
                           ,P_MONTH     => P_MONTH 
                           ,P_EML_HTML  => V_HTML 
                           ,P_EML_TEXT  => V_DUMMY); 
 
  V_HTML := V_HTML||'</div>'; 
 
  PRINT_HTML(V_HTML); 
 
end GENERATE_OWN_VACATION; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            IVACATION_MAINTENANCE 
-- Type:            Procedure 
-- Creation date:   23-Jul-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure for daily job that does all the maintenance for the application 
-- 
--***************************************** 
 
 
 
 
--***************************************** 
-- 
-- Name:            JURNALIZE_EMP_COUNTRY 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Move the information from AA_EMPLOYEES to AA_EMPLOYEES_JNL 
-- 
--***************************************** 
procedure JURNALIZE_EMP_COUNTRY(P_EMP_EMAIL varchar2, P_WHO varchar2, P_BATCH_CODE number) 
is 
 
begin 
-- Move the Employee info to the jnl table 
  insert into AA_EMPLOYEES_JNL 
    select a.* 
          ,localtimestamp 
          ,P_WHO 
          ,P_BATCH_CODE 
    from AA_EMPLOYEES a 
    where UPPER(a.EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
-- Move the custome accrual information 
  insert into AA_EMP_CUST_ACCRUAL_JNL 
    select AE.* 
          ,localtimestamp 
          ,P_WHO 
          ,P_BATCH_CODE 
    from AA_EMP_CUST_ACCRUAL AE 
    where upper(AE.EMP_EMAIL) = upper(P_EMP_EMAIL); 
 
-- Delete the jurnalized info 
  delete from AA_EMP_CUST_ACCRUAL 
    where upper(EMP_EMAIL) = upper(P_EMP_EMAIL); 
 
  delete from AA_EMPLOYEES 
     where UPPER(EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
end JURNALIZE_EMP_COUNTRY; 
 
 
 
 
--***************************************** 
-- 
-- Name:            JURNALIZE_EMP_COUNTRY 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Move the information from AA_EMPLOYEES to AA_EMPLOYEES_JNL 
-- 
--***************************************** 
procedure JURNALIZE_EMP_STATUS(P_EMP_EMAIL varchar2, P_WHO varchar2, P_BATCH_CODE number) 
is 
 
begin 
-- Move the Overview info to the jnl table 
  insert into AA_EMP_STATUS_INT_JNL 
    select a.* 
          ,localtimestamp 
          ,P_WHO 
          ,P_BATCH_CODE 
    from AA_EMP_STATUS_INT a 
    where UPPER(a.EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
-- Delete the jurnalized info 
  delete from AA_EMP_STATUS_INT 
     where UPPER(EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
end JURNALIZE_EMP_STATUS; 
 
 
 
 
--***************************************** 
-- 
-- Name:            JURNALIZE_REQUESTS 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Move the information from AA_REQUESTS to AA_REQUESTS_JNL 
-- 
--***************************************** 
procedure JURNALIZE_REQUESTS(P_EMP_EMAIL varchar2, P_WHO varchar2, P_BATCH_CODE number) 
is 
 
begin 
-- Move the Overview info to the jnl table 
  insert into AA_REQUESTS_JNL 
    select a.AA_REQUEST_ID, 
           a.EMP_EMAIL, 
           a.EMAIL_TO, 
           a.EMAIL_CC, 
           a.EMAIL_BCC, 
           a.EMP_NUMBER, 
           a.NO_WORK_DAYS_LEAVE, 
           a.LEAVE_START, 
           a.LEAVE_END, 
           a.MANAGER_APPROVE, 
           a.APPROVE_DATE, 
           a.AA_STATUS_ID, 
           a.CREATED_BY, 
           a.CREATION_DATE, 
           a.LAST_UPDATED_BY, 
           a.LAST_UPDATE_DATE, 
           localtimestamp, 
           a.AA_COUNTRY_VP_INT_ID 
           ,P_WHO 
           ,P_BATCH_CODE 
    from AA_REQUESTS a 
    where UPPER(a.EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
-- Delete the jurnalized info 
  delete from AA_REQUESTS 
    where UPPER(EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
end JURNALIZE_REQUESTS; 
 
 
 
 
--***************************************** 
-- 
-- Name:            JURNALIZE_OVERVIEW 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Move the information from AA_OVERVIEW to AA_OVERVIEW_JNL 
-- 
--***************************************** 
procedure JURNALIZE_OVERVIEW(P_EMP_EMAIL varchar2, P_WHO varchar2, P_BATCH_CODE number) 
is 
 
begin 
 
-- Move the Overview info to the jnl table 
  insert into AA_OVERVIEW_JNL 
    select AA_OVERVIEW_ID_JNL_SEQ.NEXTVAL 
          ,a.AA_OVERVIEW_ID 
          ,a.EMP_EMAIL 
          ,a.month 
          ,a.ACCRUED 
          ,a.LEAVE_TAKEN 
          ,a.LEAVE_BALANCE 
          ,a.CREATED_BY 
          ,a.CREATION_DATE 
          ,a.LAST_UPDATED_BY 
          ,a.LAST_UPDATE_DATE 
          ,localtimestamp 
          ,WS_TOOLS.GET_USER 
          ,P_WHO 
          ,a.AMOUNT_ADDED 
          ,a.LAST_YEAR_LEAVE_BALANCE 
          ,a.AA_COUNTRY_VP_INT_ID 
          ,P_BATCH_CODE 
    from AA_OVERVIEW a 
    where UPPER(a.EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
-- Delete the jurnalized info 
  delete from AA_OVERVIEW 
    where UPPER(EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
end JURNALIZE_OVERVIEW; 
 
 
 
 
--***************************************** 
-- 
-- Name:            JURNALIZE_OOH 
-- Type:            procedure 
-- Creation date:   27-Oct-2015 
-- Created by:      Alexandru Banu 
-- Description:     Move the information from AA_OOH_REQUESTS to AA_OOH_REQUESTS_JNL 
-- 
--***************************************** 
procedure JURNALIZE_OOH(P_EMP_EMAIL varchar2, P_WHO varchar2, P_BATCH_CODE number) 
is 
 
begin 
-- Move the Overview info to the jnl table 
  insert into AA_OOH_REQUESTS_JNL 
    select a.* 
          ,localtimestamp 
          ,P_WHO 
          ,P_BATCH_CODE 
    from AA_OOH_REQUESTS a 
    where UPPER(a.EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
-- Delete the jurnalized info 
  delete from AA_OOH_REQUESTS 
     where UPPER(EMP_EMAIL) = UPPER(P_EMP_EMAIL); 
 
end JURNALIZE_OOH; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            JURNALIZE_EMP 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Jurnalizes all the information for an employee 
-- 
--***************************************** 
procedure JURNALIZE_EMP(P_EMP_EMAIL varchar2, P_WHO varchar2 default null) 
is 
 
  V_WHO         varchar2(20); 
  V_BATCH_CODE  number; 
 
begin 
-- Initialize the variables 
  if P_WHO is null then 
    V_WHO := 'JNL_EMP'; 
  else 
    V_WHO := P_WHO; 
  end if; 
 
  V_BATCH_CODE := AA_JNL_BATCH_CODE_SEQ.nextval; 
 
-- Move the inforamtion from AA_OOH_REQUESTS to AA_REQUESTS_JNL 
  JURNALIZE_OOH(P_EMP_EMAIL, V_WHO, V_BATCH_CODE); 
-- Move the information of AA_OVERVIEW to AA_OVERVIEW_JNL 
  JURNALIZE_OVERVIEW(P_EMP_EMAIL, V_WHO, V_BATCH_CODE); 
-- Move the information of AA_REQUESTS to AA_REQUESTS_JNL 
  JURNALIZE_REQUESTS(P_EMP_EMAIL, V_WHO, V_BATCH_CODE); 
-- Move the information of AA_EMP_STATUS_INT to AA_EMP_STATUS_INT_JNL 
  JURNALIZE_EMP_STATUS(P_EMP_EMAIL, V_WHO, V_BATCH_CODE); 
-- Move the information of AA_EMPLOYEES to AA_EMPLOYEES_JNL 
  JURNALIZE_EMP_COUNTRY(P_EMP_EMAIL, V_WHO, V_BATCH_CODE); 
 
end JURNALIZE_EMP; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            CHANGE_EMPLOYEE_COUNTRY 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     The procedure will jurnalize the employee and will create a new record for the employee in the new country 
-- 
--***************************************** 
procedure CHANGE_EMPLOYEE_COUNTRY(P_EMP_EMAIL               varchar2 
                                 ,P_EMP_NUMBER              varchar2 
                                 ,P_EMP_NAME                varchar2 
                                 ,P_START_DATE              date 
                                 ,P_COUNTRY_ID              number 
                                 ,P_COST_CENTER             varchar2 
                                 ,P_MANAGER                 varchar2 
                                 ,P_LEVAE_BALANCE           number default 0 
                                 ,P_LAST_YEAR_LEAVE_BALANCE number default 0) 
is 
 
  V_WHO varchar2(20); 
 
begin 
-- Initialize Variables 
  V_WHO := 'INT_TRANSF'; 
 
-- Jurnalize the employee 
  JURNALIZE_EMP(P_EMP_EMAIL, V_WHO); 
 
-- Create the new user 
  ADD_EMP (P_EMP_NUMBER               => P_EMP_NUMBER 
          ,P_EMP_NAME                 => P_EMP_NAME 
          ,P_EMP_EMAIL                => P_EMP_EMAIL 
          ,P_START_DATE               => P_START_DATE 
          ,P_COUNTRY_ID               => P_COUNTRY_ID 
          ,P_COST_CENTER              => P_COST_CENTER 
          ,P_MANAGER                  => P_MANAGER 
          ,P_LEVAE_BALANCE            => P_LEVAE_BALANCE 
          ,P_LAST_YEAR_LEAVE_BALANCE  => P_LAST_YEAR_LEAVE_BALANCE 
          ); 
 
end CHANGE_EMPLOYEE_COUNTRY; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            ASSOCIATE_EVENT_TO_COUNTRY 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     The procedure will associate an event to a country with a specific unit of measure 
-- 
--***************************************** 
procedure ASSOCIATE_EVENT_TO_COUNTRY(P_AA_COUNTRY_ID          number 
                                    ,P_AA_EVENT_TYPE_ID       number 
                                    ,P_AA_UNIT_OF_MEASURE_ID  number) 
is 
 
begin 
 
  insert into AA_COUNTRY_EVENTS_INT(AA_COUNTRY_ID,AA_EVENT_TYPE_ID,AA_UNIT_OF_MEASURE_ID) 
    values(P_AA_COUNTRY_ID,P_AA_EVENT_TYPE_ID,P_AA_UNIT_OF_MEASURE_ID); 
 
end ASSOCIATE_EVENT_TO_COUNTRY; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            IS_ELIG_SUSPEND_ASSIG 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Check to see if the user is eligible for suspend assignment 
-- 
--***************************************** 
function IS_ELIG_SUSPEND_ASSIG(P_EMP_EMAIL varchar2) 
return boolean 
is 
 
  V_COUNT PLS_INTEGER; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_EMPLOYEES AE 
    join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
    where AE.EMP_EMAIL = UPPER(P_EMP_EMAIL) 
    and ACVI.SUSPEND_ASSIGNMENT = 1 
    and ACVI.ACTIVE = 1; 
 
  if V_COUNT > 0 then 
    return true; 
  else 
    return false; 
  end if; 
 
end IS_ELIG_SUSPEND_ASSIG; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            CHECK_SUSPEND_ASSIG 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Check if the submitted request overlaps any existing suspend assignment 
-- 
--***************************************** 
function EXIST_SUSPEND_PERIOD(P_EMP_EMAIL   varchar2 
                             ,P_START_DATE  date default null 
                             ,P_END_DATE    date default null) 
return boolean 
is 
 
  V_COUNT PLS_INTEGER; 
 
begin 
 
  select COUNT(1) 
    into V_COUNT 
    from AA_EMP_STATUS_INT 
    where EMP_EMAIL = UPPER(P_EMP_EMAIL) 
    and ( 
         (TRUNC(P_START_DATE) <= TRUNC(BEGIN_DATE) 
          and 
          NVL(P_END_DATE,TO_DATE('9999','yyyy')) >= TRUNC(BEGIN_DATE)) 
 
         or 
 
         (TRUNC(P_START_DATE) >= TRUNC(BEGIN_DATE) 
          and 
          TRUNC(P_START_DATE) <= NVL(END_DATE,TO_DATE('9999','yyyy'))) 
        ); 
 
 
  if V_COUNT > 0 then 
    return true; 
  else 
    return false; 
  end if; 
 
end EXIST_SUSPEND_PERIOD; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            CHECK_SUSPEND_ASSIG 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     FUnction that checks if the employee is on suspend assignment or not 
-- 
--***************************************** 
function CHECK_SUSPEND_PERIOD(P_EMP_EMAIL   varchar2 
                             ,P_START_DATE  date) 
return number 
is 
 
  V_ID  AA_EMP_STATUS_INT.AA_EMP_STATUS_INT_ID%type; 
 
begin 
-- Get the id of the suspend assignemnt of the employee 
  select AA_EMP_STATUS_INT_ID 
    into V_ID 
    from AA_EMP_STATUS_INT 
    where EMP_EMAIL = UPPER(P_EMP_EMAIL) 
    and trunc(BEGIN_DATE) = trunc(P_START_DATE); 
 
  return V_ID; 
 
  EXCEPTION 
    when NO_DATA_FOUND then 
      return -1; 
 
end CHECK_SUSPEND_PERIOD; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            CHECK_SUSPEND_ASSIG 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     FUnction that checks if the employee is on suspend assignment or not 
-- 
--***************************************** 
function CHECK_SUSPEND_ASSIG(P_EMP_EMAIL varchar2) 
return boolean 
is 
 
  V_RETURN BOOLEAN := false; 
 
begin 
-- Loop through all the suspend assignments and check if today is between any of the begin and end dates 
  for S1 in (select BEGIN_DATE 
                   ,NVL(END_DATE,localtimestamp + 7) END_DATE 
               from AA_EMP_STATUS_INT 
               where EMP_EMAIL = UPPER(P_EMP_EMAIL) 
               order by AA_EMP_STATUS_INT_ID desc) 
  LOOP 
 
    if TRUNC(localtimestamp) >= S1.BEGIN_DATE and 
       TRUNC(localtimestamp) <= S1.END_DATE then 
 
       V_RETURN := true; 
 
    end if; 
 
  end LOOP; 
 
  return V_RETURN; 
 
end CHECK_SUSPEND_ASSIG; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            SET_SUSPEND_ASSIG 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to handle the suspend assignemnt action 
-- 
--***************************************** 
procedure PROCESS_SUSPEND_ASSIG(P_EMP_ID      number 
                               ,P_START_DATE  date default null 
                               ,P_END_DATE    date default null) 
is 
 
  C_SUSPENDED           CONSTANT PLS_INTEGER := 1; 
 
  V_ID                  AA_EMP_STATUS_INT.AA_EMP_STATUS_INT_ID%type; 
 
  V_EMP_EMAIL           AA_EMPLOYEES.EMP_EMAIL%type; 
 
  E_EXIST               exception; 
 
begin 
-- Get the employee email 
  select UPPER(EMP_EMAIL) 
    into V_EMP_EMAIL 
    from AA_EMPLOYEES 
    where AA_EMPLOYEE_ID = P_EMP_ID; 
 
-- If the start date is null it means that it is regular process that is calling the procedure and we don't need to update the actual suspend assignment 
  if P_START_DATE is not null then 
 
    -- Get the id of the row that is going to be updated 
      V_ID := CHECK_SUSPEND_PERIOD(P_EMP_EMAIL => V_EMP_EMAIL, P_START_DATE => P_START_DATE); 
 
    -- If there is a previous row update it 
    -- otherwise add a new line in the table 
      if V_ID != -1 then 
 
        update AA_EMP_STATUS_INT 
          set BEGIN_DATE = TRUNC(P_START_DATE) 
             ,END_DATE = TRUNC(P_END_DATE) 
          where AA_EMP_STATUS_INT_ID = V_ID; 
 
      else 
 
        if EXIST_SUSPEND_PERIOD(P_EMP_EMAIL   => V_EMP_EMAIL 
                               ,P_START_DATE  => P_START_DATE 
                               ,P_END_DATE    =>P_END_DATE) then 
          raise E_EXIST; 
 
        end if; 
 
        insert into AA_EMP_STATUS_INT(EMP_EMAIL, AA_EMP_STATUS_ID, BEGIN_DATE, END_DATE) 
          values(V_EMP_EMAIL, C_SUSPENDED, TRUNC(P_START_DATE), TRUNC(P_END_DATE)); 
 
      end if; 
 
  -- Redo the balance 
    REDO_BALANCE_ALL(V_EMP_EMAIL,P_START_DATE); 
 
  end if; 
 
  EXCEPTION 
    when E_EXIST then 
      RAISE_APPLICATION_ERROR(-20001,'There is another Suspend Assignment Overlapping the same period.'); 
 
 
end PROCESS_SUSPEND_ASSIG; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            DELETE_SUSPEND_ASSIG 
-- Type:            procedure 
-- Creation date:   12-Aug-2014 
-- Created by:      Alexandru Banu 
-- Description:     Delete the suspend assignemnt 
-- 
--***************************************** 
procedure DELETE_SUSPEND_ASSIG(P_EMP_ID      number 
                              ,P_START_DATE  date default null 
                              ,P_END_DATE    date default null) 
is 
 
  C_SUSPENDED           CONSTANT PLS_INTEGER := 1; 
 
  V_ID                  AA_EMP_STATUS_INT.AA_EMP_STATUS_INT_ID%type; 
 
  V_EMP_EMAIL           AA_EMPLOYEES.EMP_EMAIL%type; 
 
begin 
-- Get the employee email 
  select UPPER(EMP_EMAIL) 
    into V_EMP_EMAIL 
    from AA_EMPLOYEES 
    where AA_EMPLOYEE_ID = P_EMP_ID; 
 
-- Delete the suspend assignment lines 
  delete from AA_EMP_STATUS_INT 
    where EMP_EMAIL = V_EMP_EMAIL 
    and TRUNC(BEGIN_DATE) = TRUNC(P_START_DATE) 
    and NVL(TRUNC(END_DATE),IVACATION.DEFAULT_DATE) = TRUNC(P_END_DATE); 
 
-- Redo the balance 
  REDO_BALANCE_ALL(V_EMP_EMAIL,P_START_DATE); 
 
end DELETE_SUSPEND_ASSIG; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            HAS_FUTURE_BALANCE 
-- Type:            Function 
-- Creation date:   21-Apr-2015 
-- Created by:      Alexandru Banu 
-- Description:     Check if the vacation plan is suitable for calculating the leave balance in the future 
-- 
--***************************************** 
function HAS_FUTURE_BALANCE(P_VP_INT_ID number) 
return BOOLEAN 
is 
 
  V_COUNT PLS_INTEGER; 
 
begin 
 
  select COUNT(*) 
    into V_COUNT 
    from AA_COUNTRY_VP_INT 
    where AA_COUNTRY_VP_INT_ID = P_VP_INT_ID 
    and FUTURE_BALANCE = 1; 
 
  if V_COUNT > 0 then 
    return true; 
  end if; 
 
  return false; 
 
end HAS_FUTURE_BALANCE; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PRINT_EMP_BALANCE 
-- Type:            Function 
-- Creation date:   21-Apr-2015 
-- Created by:      Alexandru Banu 
-- Description:     Print the HTML for the employee balance 
-- 
--***************************************** 
procedure PRINT_EMP_BALANCE(P_EMP_EMAIL varchar2, P_COUNTRY_ID number) 
is 
 
  V_COUNT PLS_INTEGER := 0; 
 
begin 
-- Print the fix HTML Markup 
  HTP.P('<html>'); 
  HTP.P('  <head>'); 
  HTP.P('    <style>'); 
  HTP.P('      div#leaveBalanceWrapper {'); 
  --HTP.P('        text-shadow: rgba(0, 0, 0, 0.2) 0.1em 0.1em 0.1em;'); 
  --HTP.P('        -webkit-text-shadow: rgba(0, 0, 0, 0.4) 0.1em 0.1em 0.2em;'); 
  --HTP.P('        -moz-text-shadow: rgba(0, 0, 0, 0.4) 0.1em 0.1em 0.2em;'); 
  --HTP.P('        padding: 20px;'); 
  HTP.P('        text-align: left;'); 
  --HTP.P('        font-size: 14pt;'); 
  HTP.P('      }'); 
  HTP.P('      p.subscript {'); 
  --HTP.P('        font-size: 12pt;'); 
  HTP.P('      }'); 
  HTP.P('      span.emph {'); 
  --HTP.P('        font-weight: bold;'); 
  HTP.P('        color: #A45A52;'); 
  HTP.P('      }'); 
  HTP.P('    </style>'); 
  HTP.P('  </head>'); 
  HTP.P('  <body>'); 
  HTP.P('    <div id="leaveBalanceWrapper">'); 
  HTP.P('      <p>Today <span class="emph">'||to_char(sysdate,'DD-MON-YYYY')||'</span>, you have'); 
 
-- Loop through all the vacation Plans 
  for S1 in (select ACVI.AA_COUNTRY_VP_INT_ID 
                   ,ACVI.PLAN_DESC PLAN_DESC 
                   ,COUNT(*) over() NR_VP 
              from AA_EMPLOYEES AE 
              join AA_COUNTRY_VP_INT ACVI on ACVI.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
              where AE.EMP_EMAIL = P_EMP_EMAIL 
              and ACVI.AFFECT_LEAVE_BALANCE = 1 
              and trunc(sysdate) between trunc(ACVI.BEGIN_DATE) and NVL(trunc(ACVI.END_DATE),trunc(sysdate)) 
    ) -- Print the message only for vacation plans that affect leave balance 
  LOOP 
  -- Increment the counter 
    V_COUNT := V_COUNT + 1; 
 
  -- Print the number of leave days that the employee has in the vacation plan 
    HTP.P('<span class="emph">'); 
    HTP.P(GET_EMP_LEAVE_BALANCE(P_EMAIL => P_EMP_EMAIL, P_MONTH => TRUNC(sysdate), P_AA_COUNTRY_VP_INT_ID =>S1.AA_COUNTRY_VP_INT_ID)); 
    HTP.P('</span> working days of leave available out of the '||S1.PLAN_DESC); 
 
  -- If the employee has more than one vacation plan print the name of the vacation plan also 
--    if S1.NR_VP > 1 then 
 
    -- If this isnt't the last vacation plan add an "and" for future vacation plans 
      if V_COUNT < S1.NR_VP and S1.NR_VP > 1 then 
        HTP.P(' and '); 
      else 
 
        if HAS_FUTURE_BALANCE(P_VP_INT_ID => S1.AA_COUNTRY_VP_INT_ID) then 
          HTP.P(' and a balance of '); 
          HTP.P('<span class="emph">'); 
          HTP.P(GET_FUTURE_EMP_LEAVE_BALANCE(P_EMAIL => P_EMP_EMAIL, P_MONTH => TRUNC(sysdate), P_AA_COUNTRY_VP_INT_ID =>S1.AA_COUNTRY_VP_INT_ID)); 
          HTP.P('</span> working days of leave taking into account future approved leaves.</p>'); 
        else 
          HTP.P('      .</p><p class="subscript">This leave balance doesn''t take into account leaves that will occur in future months.</p>'); 
        end if; 
 
      end if; 
 
--    end if; 
 
  end LOOP; 
 
--  HTP.P('.</p>'); 
 
  if V_COUNT = 0 then 
    HTP.P('<span class="emph">!!! Error regarding the vacation balance! Please contact your HR Representative !!!</span></p>'); 
  end if; 
 
  if P_COUNTRY_ID = 20 then -- Ukraine 
    HTP.P('      <p class="subscript" style="text-decoration:underline;">Attention: public holidays shall be excluded from the Number of Days Leave</p>'); 
  end if; 
 
-- Print the fix HTML Markup 
  HTP.P('    </div>'); 
  HTP.P('  </body>'); 
  HTP.P('</html>'); 
 
end PRINT_EMP_BALANCE; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            HAS_SICK_LEAVE_ELIG 
-- Type:            function 
-- Creation date:   27-Apr-2015 
-- Created by:      Alexandru Banu 
-- Description:     Returns true if the employee's country has Sick Leave in the applicaion 
-- 
--***************************************** 
function HAS_SICK_LEAVE_ELIG(P_EMP_EMAIL varchar2) 
return BOOLEAN 
is 
 
  V_COUNT_EMP   PLS_INTEGER; 
  V_COUNT_ADMIN PLS_INTEGER; 
 
begin 
-- Check the employee in the country 
  select COUNT(*) 
    into V_COUNT_EMP 
    from AA_EMPLOYEES AE 
    join AA_COUNTRIES AC on AC.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
    where AE.EMP_EMAIL = P_EMP_EMAIL 
    and AC.SICK_LEAVE = 1; 
 
-- Check the Country Administrator 
  select COUNT(*) 
    into V_COUNT_ADMIN 
    from AA_USER_CT_ROLE_INT ADCI 
    join AA_COUNTRIES AC on AC.AA_COUNTRY_ID = ADCI.AA_COUNTRY_ID 
    where ADCI.EMP_EMAIL = P_EMP_EMAIL 
    and ADCI.AA_ROLE_ID in (1,2) -- Country HR 
    and ADCI.ACTIVE = 1 
    and AC.SICK_LEAVE = 1; 
 
  if V_COUNT_EMP + V_COUNT_ADMIN > 0 then 
    return true; 
  else 
    return false; 
  end if; 
 
  EXCEPTION 
    when NO_DATA_FOUND then 
      return false; 
 
end HAS_SICK_LEAVE_ELIG; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            HAS_OOH_ELIG_MNG 
-- Type:            function 
-- Creation date:   26-May-2015 
-- Created by:      Alexandru Banu 
-- Description:     Returns true if the employee's country has Out of Hours in the applicaion 
-- 
--***************************************** 
function HAS_OOH_ELIG_MNG(P_EMP_EMAIL varchar2) 
return BOOLEAN 
is 
 
  V_COUNT_MNG   PLS_INTEGER; 
  V_COUNT_ADMIN PLS_INTEGER; 
 
begin 
-- Check the employee in the country 
  select COUNT(*) 
    into V_COUNT_MNG 
    from AA_EMPLOYEES AE 
    join AA_COUNTRIES AC on AC.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
    where UPPER(AE.EMP_MANAGER) = UPPER(P_EMP_EMAIL) 
    and AC.OOH = 1; 
 
-- Check the Country Administrator 
  select COUNT(*) 
    into V_COUNT_ADMIN 
    from AA_USER_CT_ROLE_INT ADCI 
    join AA_COUNTRIES AC on AC.AA_COUNTRY_ID = ADCI.AA_COUNTRY_ID 
    where ADCI.EMP_EMAIL = P_EMP_EMAIL 
    and ADCI.AA_ROLE_ID in (1,2) -- Country HR, Country Payroll 
    and ADCI.ACTIVE = 1 
    and AC.OOH = 1; 
 
  if V_COUNT_MNG + V_COUNT_ADMIN > 0 then 
    return true; 
  else 
    return false; 
  end if; 
 
  EXCEPTION 
    when NO_DATA_FOUND then 
      return false; 
 
end HAS_OOH_ELIG_MNG; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            HAS_OOH_ELIG 
-- Type:            function 
-- Creation date:   26-May-2015 
-- Created by:      Alexandru Banu 
-- Description:     Returns true if the employee's country has Out of Hours in the applicaion 
-- 
--***************************************** 
function HAS_OOH_ELIG(P_EMP_EMAIL varchar2) 
return BOOLEAN 
is 
 
  V_COUNT_EMP   PLS_INTEGER; 
  V_COUNT_ADMIN PLS_INTEGER := 0; 
 
begin 
-- Check the employee in the country 
  select COUNT(*) 
    into V_COUNT_EMP 
    from AA_EMPLOYEES AE 
    join AA_COUNTRIES AC on AC.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
    where AE.EMP_EMAIL = P_EMP_EMAIL 
    and AC.OOH = 1; 
 
-- Check the Country Administrator and the Manager 
  if HAS_OOH_ELIG_MNG(P_EMP_EMAIL => P_EMP_EMAIL) then 
    V_COUNT_ADMIN := 1; 
  end if; 
 
  if V_COUNT_EMP + V_COUNT_ADMIN > 0 then 
    return true; 
  else 
    return false; 
  end if; 
 
  EXCEPTION 
    when NO_DATA_FOUND then 
      return false; 
 
end HAS_OOH_ELIG; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            GET_EMP_LEAVE_TYPES 
-- Type:            function 
-- Creation date:   27-Apr-2015 
-- Created by:      Alexandru Banu 
-- Description:     Function that returns the types of leaves that the employee/manager/admin is entitled to 
-- 
--***************************************** 
function GET_EMP_LEAVE_TYPES(P_EMP_EMAIL varchar2) 
return varchar2 
is 
 
  V_SICK_LEAVE AA_COUNTRIES.SICK_LEAVE%type; 
  V_OOH        AA_COUNTRIES.OOH%type; 
 
  V_RETURN     varchar2(255); 
 
begin 
-- Get the flags 
  for S1 in (select SICK_LEAVE 
                   ,OOH 
                into V_SICK_LEAVE 
                    ,V_OOH 
                from AA_EMPLOYEES AE 
                join AA_COUNTRIES AC on AC.AA_COUNTRY_ID = AE.AA_COUNTRY_ID 
                where IS_PAYROLL(AE.AA_COUNTRY_ID, '-1') = 1 -- Payroll contains IS_LOCAL_HR 
                  or UPPER(AE.EMP_MANAGER) = UPPER(P_EMP_EMAIL) 
                  or AE.EMP_EMAIL = UPPER(P_EMP_EMAIL) 
              ) 
  LOOP 
 
    if S1.SICK_LEAVE = 1 then 
      V_SICK_LEAVE := 1; 
    end if; 

    if S1.OOH = 1 then 
      V_OOH := 1; 
    end if; 

  end LOOP; 
  
-- All employees have vacation by default 
  V_RETURN := IVACATION.C_VACATION; 
 
-- Add any other types of leaves 
  if V_SICK_LEAVE = 1 then 
    V_RETURN := V_RETURN||','||IVACATION.C_SICK_LEAVE; 
  end if; 
 
-- Add any other types of leaves 
  if V_OOH = 1 then 
    V_RETURN := V_RETURN||','||IVACATION.C_OOH; 
  end if; 
 
  return V_RETURN || '$' || V_SICK_LEAVE || V_OOH; 
 


end GET_EMP_LEAVE_TYPES; 
 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PRINT_PORTAL 
-- Type:            procedure 
-- Creation date:   27-Apr-2015 
-- Created by:      Alexandru Banu 
-- Description:     Print the portal HTML 
-- 
--***************************************** 
procedure PRINT_PORTAL(P_EMP_EMAIL varchar2) 
is 
 
  V_EMP_LEAVE_TYPES   varchar2(255); 
  V_SECURITY_ID       number; 
 
  V_VACATION_LOGO     varchar2(100) := 'vacationLogo.svg'; 
  V_VSICK_LEAVE_LOGO  varchar2(100) := 'sickLeaveLogo.svg'; 
  V_OOH_LOGO          varchar2(100) := 'outOfHoursLogo.svg'; 
 
  V_VACATION_PAGE     varchar2(4) := 'AREC'; 
  V_SICK_LEAVE_PAGE   varchar2(4) := 'SKLV'; 
  V_OUT_OF_HOURS_PAGE varchar2(3) := 'OOH'; 
 
begin 
-- Get the Security ID 
  select WORKSPACE_ID 
    into V_SECURITY_ID 
    from APEX_WORKSPACES; 
 
-- Print the text of the portal 
  HTP.P('<div id="textContainer">'); 
  HTP.P('	<p>Please select a type of leave from the ones below.</p>'); 
  HTP.P('</div>'); 
 
-- Get the Leave Types that the employee should have access to 
  V_EMP_LEAVE_TYPES := GET_EMP_LEAVE_TYPES(P_EMP_EMAIL); 
 
-- Go through all the leave types and build the HTML 
  HTP.P('<div id="buttonContainer">'); 
 
-- Vacation 
  if instr(V_EMP_LEAVE_TYPES,IVACATION.C_VACATION) > 0 then 
 
    HTP.P('	<div id="vacation">'); 
    HTP.P('   <a href="f?p='||c_APP_ID||':'||V_VACATION_PAGE||':'||V('APP_SESSION')||'">'); 
    HTP.P('		<img src="wwv_flow_file_mgr.get_file?p_security_group_id='||V_SECURITY_ID||'&p_flow_id='||c_APP_ID||'&p_fname='||V_VACATION_LOGO||'" alt="Vacation">'); 
    HTP.P('   </a>'); 
    HTP.P('		<div class="imgWording">Vacation</div>'); 
    HTP.P('	</div>'); 
 
  end if; 
 
-- Sick Leave 
  if instr(V_EMP_LEAVE_TYPES,IVACATION.C_SICK_LEAVE) > 0 then 
 
    HTP.P('	<div id="sickLeave">'); 
    HTP.P('   <a href="f?p='||c_APP_ID||':'||V_SICK_LEAVE_PAGE||':'||V('APP_SESSION')||'">'); 
    HTP.P('		<img src="wwv_flow_file_mgr.get_file?p_security_group_id='||V_SECURITY_ID||'&p_flow_id='||c_APP_ID||'&p_fname='||V_VSICK_LEAVE_LOGO||'" alt="Sick Leave">'); 
    HTP.P('   </a>'); 
    HTP.P('		<div class="imgWording">Sick Leave</div>'); 
    HTP.P('	</div>'); 
 
  end if; 
 
-- Out of Hours 
  if instr(V_EMP_LEAVE_TYPES,IVACATION.C_OOH) > 0 then 
 
    HTP.P('	<div id="sickLeave">'); 
    HTP.P('   <a href="f?p='||c_APP_ID||':'||V_OUT_OF_HOURS_PAGE||':'||V('APP_SESSION')||'">'); 
    HTP.P('		<img src="wwv_flow_file_mgr.get_file?p_security_group_id='||V_SECURITY_ID||'&p_flow_id='||c_APP_ID||'&p_fname='||V_OOH_LOGO||'" alt="Out of Hours">'); 
    HTP.P('   </a>'); 
    HTP.P('		<div class="imgWording">Out of Hours</div>'); 
    HTP.P('	</div>'); 
 
  end if; 
 
  HTP.P('</div>'); 
 
end PRINT_PORTAL; 
 
 
 
 
---***************************************** 
--- 
--- Name:            GET_STATUS_LIST 
--- Type:            procedure 
--- Creation date:   22-Jun-2015 
--- Created by:      Alexandru Banu 
--- Description:     Function that returns the list of statuses available for each request 
--- 
---***************************************** 
function GET_STATUS_LIST(P_REQUEST_ID number 
                        ,P_EMP_EMAIL  varchar2 
                        ,P_QUERY      number) 
return varchar2 
is 
 
  V_STATUS_ID     AA_REQUESTS.AA_STATUS_ID%type; 
  V_EMP_EMAIL     AA_REQUESTS.EMP_EMAIL%type; 
  V_MNG_EMAIL     AA_REQUESTS.EMAIL_TO%type; 
  V_LEAVE_START   AA_REQUESTS.LEAVE_START%type; 
 
  V_COUNTRY_ID    AA_EMPLOYEES.AA_COUNTRY_ID%type; 
 
  V_RETURN_A      APEX_APPLICATION_GLOBAL.VC_ARR2; 
  V_RETURN        varchar2(1000); 
 
begin 
-- Get the status 
  select AR.AA_STATUS_ID 
        ,AR.EMP_EMAIL 
        ,AR.EMAIL_TO 
        ,AR.LEAVE_START 
        ,AE.AA_COUNTRY_ID 
    into V_STATUS_ID 
        ,V_EMP_EMAIL 
        ,V_MNG_EMAIL 
        ,V_LEAVE_START 
        ,V_COUNTRY_ID 
    from AA_REQUESTS AR 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
    where AR.AA_REQUEST_ID = P_REQUEST_ID; 
 
-- Build the status list 
-- Employee Status 
  if UPPER(P_EMP_EMAIL) = UPPER(V_EMP_EMAIL) then 
 
    if V_STATUS_ID = 1 then -- Waiting Approval 
      V_RETURN_A(V_RETURN_A.count + 1) := '5'; 
    end if; 
  end if; 
 
-- Manager status 
  if UPPER(P_EMP_EMAIL) = UPPER(V_MNG_EMAIL) then 
 
    if V_STATUS_ID = 1 then -- Waiting Approval 
      V_RETURN_A(V_RETURN_A.count + 1) := '2,3'; 
    ELSIF V_LEAVE_START > TRUNC(sysdate) then 
      if V_STATUS_ID = 2 then -- Approved 
        V_RETURN_A(V_RETURN_A.count + 1) := '3'; 
      ELSIF V_STATUS_ID = 3 then -- Not Approved 
        V_RETURN_A(V_RETURN_A.count + 1) := '2'; 
      end if; 
    end if; 
 
  end if; 
-- HR Status 
  if INSTR(UPPER(IVACATION.GET_COUNTRY_ADMIN(P_COUNTRY_ID => V_COUNTRY_ID)),UPPER(P_EMP_EMAIL)) > 0 then 
 
    V_RETURN_A(V_RETURN_A.count + 1) := '1,2,3,4'; 
 
  end if; 
-- If it's null it means that we don't have any statuses 
  if V_RETURN_A.count = 0 then 
 
    V_RETURN := '-1'; 
 
  else 
 
    V_RETURN := APEX_UTIL.TABLE_TO_STRING(V_RETURN_A,','); 
 
  end if; 
 
  if P_QUERY = 1 then 
    if V_RETURN = '-1' then 
      return V_RETURN; 
    else 
      return 'select STATUS_TYPE, AA_STATUS_ID from AA_STATUS_TYPES where AA_STATUS_ID in ('||V_RETURN||') and AA_STATUS_ID != '||V_STATUS_ID; 
    end if; 
  else 
    return V_RETURN; 
  end if; 
 
end GET_STATUS_LIST; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            EDIT_REQUEST 
-- Type:            procedure 
-- Creation date:   10-Ovt-2017 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to process update a request 
-- 
--***************************************** 
procedure EDIT_REQUEST( 
  P_REQUEST_ID varchar2 
 ,P_LEAVE_START date 
 ,P_LEAVE_END date 
 ,P_DAYS_LEAVE number 
) 
is 
 
  V_EMP_EMAIL AA_REQUESTS.EMP_EMAIL%type; 
  V_OLD_LEAVE_START AA_REQUESTS.LEAVE_START%type; 
 
begin 
 
   select LEAVE_START 
   into V_OLD_LEAVE_START 
   from AA_REQUESTS 
   where AA_REQUEST_ID = P_REQUEST_ID; 
    
-- Update the request 
  update AA_REQUESTS 
    set LEAVE_START = P_LEAVE_START 
       ,LEAVE_END = P_LEAVE_END 
       ,NO_WORK_DAYS_LEAVE = P_DAYS_LEAVE 
    where AA_REQUEST_ID = P_REQUEST_ID 
    returning EMP_EMAIL into V_EMP_EMAIL; 
 
-- Redo the balance 
  REDO_BALANCE_ALL(V_EMP_EMAIL, least(trunc(V_OLD_LEAVE_START,'mm'),trunc(P_LEAVE_START,'mm'))); 
 
end EDIT_REQUEST; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            PROCESS_REQUEST 
-- Type:            procedure 
-- Creation date:   22-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to process the request(Approve, Reject...) 
-- 
--***************************************** 
procedure PROCESS_REQUEST( 
  P_EMP_EMAIL varchar2 
 ,P_REQUEST_ID varchar2 
 ,P_STATUS_ID number 
 ,P_DAYS_LEAVE number default null 
 ,P_LEAVE_START date default null 
 ,P_LEAVE_END date default null 
 ,P_COMMENTS  varchar2 default null 
) 
is 
 
  V_STATUS_ID           AA_REQUESTS.AA_STATUS_ID%type; 
  V_EMP_EMAIL           AA_REQUESTS.EMP_EMAIL%type; 
  V_LEAVE_START         AA_REQUESTS.LEAVE_START%type; 
  V_LEAVE_END           AA_REQUESTS.LEAVE_END%type; 
  V_NO_WORK_DAYS_LEAVE  AA_REQUESTS.NO_WORK_DAYS_LEAVE%type; 
  V_COUNTRY_ID          AA_EMPLOYEES.AA_COUNTRY_ID%type; 
 
  V_STATUS_TYPE         AA_STATUS_TYPES.STATUS_TYPE%type; 
 
  E_NO_ACTION           EXCEPTION; 
  E_WRONG_STATUS        EXCEPTION; 
 
begin 
-- Get the current Status 
  select AR.AA_STATUS_ID 
        ,AR.EMP_EMAIL 
        ,AR.LEAVE_START 
        ,AR.LEAVE_END 
        ,AR.NO_WORK_DAYS_LEAVE 
        ,AE.AA_COUNTRY_ID 
    into V_STATUS_ID 
        ,V_EMP_EMAIL 
        ,V_LEAVE_START 
        ,V_LEAVE_END 
        ,V_NO_WORK_DAYS_LEAVE 
        ,V_COUNTRY_ID 
    from AA_REQUESTS AR 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
    where AA_REQUEST_ID = P_REQUEST_ID; 
 
-- Check if the admin has modified the request 
  if IS_LOCAL_HR(V_COUNTRY_ID) 
    and to_char(P_LEAVE_START,'dd-mon-yyyy')||'|'|| 
         to_char(P_LEAVE_END,'dd-mon-yyyy')||'|'|| 
         to_char(P_DAYS_LEAVE) 
         != 
         to_char(V_LEAVE_START,'dd-mon-yyyy')||'|'|| 
         to_char(V_LEAVE_END,'dd-mon-yyyy')||'|'|| 
         to_char(V_NO_WORK_DAYS_LEAVE) 
  then 
  -- Update the request 
    EDIT_REQUEST( 
      P_REQUEST_ID  => P_REQUEST_ID 
     ,P_LEAVE_START => P_LEAVE_START 
     ,P_LEAVE_END   => P_LEAVE_END 
     ,P_DAYS_LEAVE  => P_DAYS_LEAVE 
    ); 
 
  end if; 
 
  if P_STATUS_ID is not null then 
 
    select STATUS_TYPE 
      into V_STATUS_TYPE 
      from AA_STATUS_TYPES 
      where AA_STATUS_ID = P_STATUS_ID; 
 
  -- Check if the status has changed 
    if V_STATUS_ID = P_STATUS_ID then 
      RAISE E_NO_ACTION; 
    end if; 
 
  -- Check if the status is valid for the user 
    if INSTR(GET_STATUS_LIST(P_REQUEST_ID => P_REQUEST_ID, P_EMP_EMAIL => P_EMP_EMAIL, P_QUERY => 0),P_STATUS_ID) = 0 then 
      RAISE E_WRONG_STATUS; 
    end if; 
 
    if P_STATUS_ID = 2 then -- Approved 
      APPROVE_REQUEST(P_REQUEST_ID => P_REQUEST_ID); 
    ELSIF P_STATUS_ID in (3,4) then -- Not approved 
      REJECT_REQUEST(P_REQUEST_ID => P_REQUEST_ID, P_COMMENTS => P_COMMENTS, P_STATUS_ID => P_STATUS_ID); 
    ELSIF P_STATUS_ID = 1 then -- Waiting Approval 
      CLEAR_APPROVAL(P_REQUEST_ID => P_REQUEST_ID); 
    ELSIF P_STATUS_ID = 5 then -- Employee Canceled 
      EMP_CANCEL_REQUEST(P_REQUEST_ID => P_REQUEST_ID, P_EMP_EMAIL => P_EMP_EMAIL); 
    end if; 
 
  else 
 
    EMP_UPDATE_REQUEST( 
      P_APP_USER    => P_EMP_EMAIL 
     ,P_EMP_EMAIL   => V_EMP_EMAIL 
     ,P_REQUEST_ID  => P_REQUEST_ID 
     ,P_LEAVE_START => P_LEAVE_START 
     ,P_LEAVE_END   => P_LEAVE_END 
     ,P_DAYS_LEAVE  => P_DAYS_LEAVE 
    ); 
 
  end if; 
 
 
  EXCEPTION 
    when E_NO_ACTION then null; 
    when E_WRONG_STATUS then RAISE_APPLICATION_ERROR('-20003','You used an invalid status: '||V_STATUS_TYPE); 
 
end PROCESS_REQUEST; 
 

--***************************************** 
-- 
-- Name:            PROCESS_REQUEST 
-- Type:            procedure 
-- Creation date:   22-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to process the request(Approve, Reject...) 
-- 
--***************************************** 
procedure PROCESS_REQUEST_TEMP( 
  P_EMP_EMAIL varchar2 
 ,P_REQUEST_ID varchar2 
 ,P_STATUS_ID number 
 ,P_DAYS_LEAVE number default null 
 ,P_LEAVE_START date default null 
 ,P_LEAVE_END date default null 
 ,P_COMMENTS  varchar2 default null 
) 
is 
 
  V_STATUS_ID           AA_REQUESTS.AA_STATUS_ID%type; 
  V_EMP_EMAIL           AA_REQUESTS.EMP_EMAIL%type; 
  V_LEAVE_START         AA_REQUESTS.LEAVE_START%type; 
  V_LEAVE_END           AA_REQUESTS.LEAVE_END%type; 
  V_NO_WORK_DAYS_LEAVE  AA_REQUESTS.NO_WORK_DAYS_LEAVE%type; 
  V_COUNTRY_ID          AA_EMPLOYEES.AA_COUNTRY_ID%type; 
 
  V_STATUS_TYPE         AA_STATUS_TYPES.STATUS_TYPE%type; 
 
  E_NO_ACTION           EXCEPTION; 
  E_WRONG_STATUS        EXCEPTION; 
 
begin 
-- Get the current Status 
  select AR.AA_STATUS_ID 
        ,AR.EMP_EMAIL 
        ,AR.LEAVE_START 
        ,AR.LEAVE_END 
        ,AR.NO_WORK_DAYS_LEAVE 
        ,AE.AA_COUNTRY_ID 
    into V_STATUS_ID 
        ,V_EMP_EMAIL 
        ,V_LEAVE_START 
        ,V_LEAVE_END 
        ,V_NO_WORK_DAYS_LEAVE 
        ,V_COUNTRY_ID 
    from AA_REQUESTS AR 
    join AA_EMPLOYEES AE on AE.EMP_EMAIL = AR.EMP_EMAIL 
    where AA_REQUEST_ID = P_REQUEST_ID; 
 
-- Check if the admin has modified the request 
  if IS_LOCAL_HR(V_COUNTRY_ID) 
    and to_char(P_LEAVE_START,'dd-mon-yyyy')||'|'|| 
         to_char(P_LEAVE_END,'dd-mon-yyyy')||'|'|| 
         to_char(P_DAYS_LEAVE) 
         != 
         to_char(V_LEAVE_START,'dd-mon-yyyy')||'|'|| 
         to_char(V_LEAVE_END,'dd-mon-yyyy')||'|'|| 
         to_char(V_NO_WORK_DAYS_LEAVE) 
  then 
  -- Update the request 
    EDIT_REQUEST( 
      P_REQUEST_ID  => P_REQUEST_ID 
     ,P_LEAVE_START => P_LEAVE_START 
     ,P_LEAVE_END   => P_LEAVE_END 
     ,P_DAYS_LEAVE  => P_DAYS_LEAVE 
    ); 
 
  end if; 
 
  if P_STATUS_ID is not null then 
 
    select STATUS_TYPE 
      into V_STATUS_TYPE 
      from AA_STATUS_TYPES 
      where AA_STATUS_ID = P_STATUS_ID; 
 
  -- Check if the status has changed 
    if V_STATUS_ID = P_STATUS_ID then 
      RAISE E_NO_ACTION; 
    end if; 
 
  -- Check if the status is valid for the user 
    if INSTR(GET_STATUS_LIST(P_REQUEST_ID => P_REQUEST_ID, P_EMP_EMAIL => P_EMP_EMAIL, P_QUERY => 0),P_STATUS_ID) = 0 then 
      RAISE E_WRONG_STATUS; 
    end if; 
 
    if P_STATUS_ID = 2 then -- Approved 
      APPROVE_REQUEST_TEMP(P_REQUEST_ID => P_REQUEST_ID); 
    ELSIF P_STATUS_ID in (3,4) then -- Not approved 
      REJECT_REQUEST(P_REQUEST_ID => P_REQUEST_ID, P_COMMENTS => P_COMMENTS, P_STATUS_ID => P_STATUS_ID); 
    ELSIF P_STATUS_ID = 1 then -- Waiting Approval 
      CLEAR_APPROVAL(P_REQUEST_ID => P_REQUEST_ID); 
    ELSIF P_STATUS_ID = 5 then -- Employee Canceled 
      EMP_CANCEL_REQUEST(P_REQUEST_ID => P_REQUEST_ID, P_EMP_EMAIL => P_EMP_EMAIL); 
    end if; 
 
  else 
 
    EMP_UPDATE_REQUEST_TEMP( 
      P_APP_USER    => P_EMP_EMAIL 
     ,P_EMP_EMAIL   => V_EMP_EMAIL 
     ,P_REQUEST_ID  => P_REQUEST_ID 
     ,P_LEAVE_START => P_LEAVE_START 
     ,P_LEAVE_END   => P_LEAVE_END 
     ,P_DAYS_LEAVE  => P_DAYS_LEAVE 
    ); 
 
  end if; 
 
 
  EXCEPTION 
    when E_NO_ACTION then null; 
    when E_WRONG_STATUS then RAISE_APPLICATION_ERROR('-20003','You used an invalid status: '||V_STATUS_TYPE); 
 
end PROCESS_REQUEST_TEMP; 
 
 
 
 
--***************************************** 
-- 
-- Name:            NEW_REQUEST_NO_MAIL 
-- Type:            procedure 
-- Creation date:   22-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to submit a new request without an email notification to the manager 
-- Uodated by:      Cristina Ursulescu 
-- Update Date:     08-JUL-2022 
-- Description:     Changed the procedure to be used from Administration module 
--***************************************** 
procedure NEW_REQUEST_NO_MAIL(P_EMAIL_TO varchar2 
                             ,P_NO_WORK_DAYS_LEAVE number 
                             ,P_LEAVE_START date 
                             ,P_LEAVE_END date 
                             ,P_AA_COUNTRY_VP_INT_ID number 
                             ,P_EMP_EMAIL varchar2 default null 
                             ,P_EMP_COMMENTS varchar2 default null 
                             ,P_REQUEST_ID out number) 
is 
 
  L_ID          number; 
 
  V_EMAIL_TO        AA_REQUESTS.EMAIL_TO%type; 
  V_EMP_EMAIL       T.EMAIL; 
  V_STATUS_ID       AA_REQUESTS.AA_STATUS_ID%type; 
  V_REQUEST_ID      AA_REQUESTS.AA_REQUEST_ID%type; 
  V_EMP_NUMBER      AA_EMPLOYEES.EMP_NUMBER%type; 
  V_MESSAGE          VARCHAR2(300); 
  V_NEGATIVE_BALANCE AA_COUNTRY_VP_INT.NEGATIVE_BALANCE%type; 
 
  E_NOT_SAME_MONTH  EXCEPTION; 
  E_EXIST           EXCEPTION; 
  E_ALLOW_NEGATIVE_BALANCE  EXCEPTION; 
 
begin 
 
-- Begin and End date must be in the same month else through exception 
  if TO_CHAR(P_LEAVE_START,'mm') != TO_CHAR(P_LEAVE_END,'mm') 
  then 
    RAISE E_NOT_SAME_MONTH; 
  end if; 
 
  V_EMAIL_TO := WS_TOOLS.TRIM_ALL(UPPER(P_EMAIL_TO)); 
  V_STATUS_ID := 1; -- Waiting Approval 
 
  if P_EMP_EMAIL is not null 
    then 
      V_EMP_EMAIL := WS_TOOLS.TRIM_ALL(UPPER(P_EMP_EMAIL)); 
  else 
     V_EMP_EMAIL := WS_TOOLS.GET_USER; 
  end if; 
   
  if EXIST_VAC_PERIOD(P_EMP_EMAIL   => V_EMP_EMAIL 
                     ,P_LEAVE_START => P_LEAVE_START 
                     ,P_LEAVE_END   => P_LEAVE_END) then 
    RAISE E_EXIST; 
  end if;  
   
 if not ALLOW_NEGATIVE_BALANCE (P_NO_WORK_DAYS_LEAVE   => P_NO_WORK_DAYS_LEAVE 
                                ,P_AA_COUNTRY_VP_INT_ID => P_AA_COUNTRY_VP_INT_ID 
                                ,P_EMP_EMAIL            => V_EMP_EMAIL) then 
      select NEGATIVE_BALANCE 
      into V_NEGATIVE_BALANCE 
      from AA_COUNTRY_VP_INT 
      where AA_COUNTRY_VP_INT_ID = P_AA_COUNTRY_VP_INT_ID;  
       
      if V_NEGATIVE_BALANCE > 0 then          
            V_MESSAGE := 'The employee is entitled to take '|| V_NEGATIVE_BALANCE ||' days from the next Fiscal Year.';          
      else        
           V_MESSAGE := null;        
       end if;     
       
       
      V_MESSAGE := V_MESSAGE || 
                    ' Employee''s vacation in amount of ' || P_NO_WORK_DAYS_LEAVE || ' days would lower the balance below '|| V_NEGATIVE_BALANCE; 
                                 
    RAISE E_ALLOW_NEGATIVE_BALANCE; 
  end if;   
 
  select EMP_NUMBER 
    into V_EMP_NUMBER 
    from AA_EMPLOYEES 
    where EMP_EMAIL = V_EMP_EMAIL; 
   
       
  insert into AA_REQUESTS (EMP_EMAIL, EMAIL_TO, NO_WORK_DAYS_LEAVE, LEAVE_START, LEAVE_END, AA_STATUS_ID, AA_COUNTRY_VP_INT_ID, EMP_COMMENTS) 
    values (V_EMP_EMAIL, V_EMAIL_TO, P_NO_WORK_DAYS_LEAVE, P_LEAVE_START, P_LEAVE_END, V_STATUS_ID, P_AA_COUNTRY_VP_INT_ID, P_EMP_COMMENTS) 
    returning AA_REQUEST_ID into V_REQUEST_ID; 
 
 
  P_REQUEST_ID :=  V_REQUEST_ID; 
 
  EXCEPTION 
    when E_NOT_SAME_MONTH then 
      RAISE_APPLICATION_ERROR(-20006,'First day on leave and Last day on leave must be in the same month. If the leave crosses into another month please submit 2 requests (one for each month)'); 
    when E_EXIST then 
      RAISE_APPLICATION_ERROR(-20007,'The employee has already submitted a Vacation Request that is overlapping the same dates as the current one.'); 
   when E_ALLOW_NEGATIVE_BALANCE then RAISE_APPLICATION_ERROR(-20008, V_MESSAGE); 
 
end NEW_REQUEST_NO_MAIL; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            APPROVE_REQUEST_NO_MAIL 
-- Type:            procedure 
-- Creation date:   22-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Approve the request without no notification 
-- 
--***************************************** 
procedure APPROVE_REQUEST_NO_MAIL(P_REQUEST_ID number) 
is 
 
L_ID                    number; 
V_EMP_EMAIL             T.EMAIL; 
V_MONTH                 AA_REQUESTS.LEAVE_END%type; 
V_AA_COUNTRY_VP_INT_ID  AA_REQUESTS.AA_COUNTRY_VP_INT_ID%type; 
--v_count_months    number; 
 
begin 
 
  update AA_REQUESTS 
    set AA_STATUS_ID = 2 /* Approved */, MANAGER_APPROVE = WS_TOOLS.GET_USER, APPROVE_DATE = localtimestamp 
    where AA_REQUEST_ID = P_REQUEST_ID 
    returning EMP_EMAIL,LEAVE_END,AA_COUNTRY_VP_INT_ID into V_EMP_EMAIL,V_MONTH,V_AA_COUNTRY_VP_INT_ID; 
 
-- Check to see if the request date is in the months before the curent month 
  if LAST_DAY(TRUNC(V_MONTH)) < LAST_DAY(TRUNC(localtimestamp)) 
    then 
    -- If it is it will redo the balance starting with that month; 
      IVACATION.REDO_BALANCE_ALL(V_EMP_EMAIL,V_MONTH); 
  ELSIF LAST_DAY(TRUNC(V_MONTH)) > LAST_DAY(TRUNC(localtimestamp)) 
    then 
    -- If the request is for a future month don't do anything because the balance of that month will be updated once the new month is inserted 
      null; 
  else 
    -- Else it will update the month as usual 
    UPDATE_LEAVE_BALANCE(P_REQUEST_ID,C_APPROVE); 
 
  end if; 
 
end APPROVE_REQUEST_NO_MAIL; 
 
 
 
 
 
--***************************************** 
-- 
-- Name:            NEW_APPROVED_REQUEST_NO_MAIL 
-- Type:            procedure 
-- Creation date:   22-Jun-2015 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to process the request(Approve, Reject...) 
-- 
--***************************************** 
procedure NEW_APPROVED_REQUEST_NO_MAIL(P_EMAIL_TO varchar2 
                                      ,P_NO_WORK_DAYS_LEAVE number 
                                      ,P_LEAVE_START date 
                                      ,P_LEAVE_END date 
                                      ,P_AA_COUNTRY_VP_INT_ID number 
                                      ,P_EMP_EMAIL varchar2 default null) 
is 
 
  V_REQUEST_ID number; 
  C_APPROVE            varchar2(20) := 'APPROVE_REQUEST'; 
 
begin 
 
  NEW_REQUEST_NO_MAIL( 
    P_EMAIL_TO => P_EMAIL_TO 
   ,P_NO_WORK_DAYS_LEAVE => P_NO_WORK_DAYS_LEAVE 
   ,P_LEAVE_START => P_LEAVE_START 
   ,P_LEAVE_END => P_LEAVE_END 
   ,P_AA_COUNTRY_VP_INT_ID => P_AA_COUNTRY_VP_INT_ID 
   ,P_EMP_EMAIL => P_EMP_EMAIL 
   ,P_REQUEST_ID => V_REQUEST_ID 
  ); 
 
  APPROVE_REQUEST_NO_MAIL(V_REQUEST_ID); 
 
end NEW_APPROVED_REQUEST_NO_MAIL; 
 
 
 
 
--***************************************** 
-- 
-- Name:            JNL_MONTHS_AFTER_END 
-- Type:            Procedure 
-- Creation date:   02-Dec-2015 
-- Created by:      Alexandru Banu 
-- Description:     Procedure to jurnalize the months greater than the end date 
-- 
--***************************************** 
procedure JNL_MONTHS_AFTER_END(P_EMP_EMAIL  varchar2) 
is 
 
begin 
 
-- Delete the records that are older than the END_DATE 
  delete from AA_OVERVIEW 
  where AA_OVERVIEW_ID in (select AA_OVERVIEW_ID 
                            from AA_OVERVIEW A 
                            join AA_EMPLOYEES AE on AE.EMP_EMAIL = a.EMP_EMAIL 
                            where a.EMP_EMAIL = P_EMP_EMAIL 
                            and AE.END_DATE is not null 
                            and TRUNC(AE.END_DATE,'mm') < TRUNC(a.month,'mm') 
                          ); 
 
end JNL_MONTHS_AFTER_END; 
 
 
--***************************************** 
-- 
-- Name:            UPLOAD_BULK_REQUESTS 
-- Type:            Procedure 
-- Creation date:   27-Jul-2022 
-- Created by:      Cristina Ursulescu 
-- Description:     Procedure to upload file for vacation requests 
-- 
--***************************************** 
 
procedure UPLOAD_BULK_REQUESTS  
    (P_AA_COUNTRY_ID         aa_countries.aa_country_id%type 
    ,P_FILE_NAME             varchar2 
    ,P_APPROVED              number) 
is 
 
 V_BLOB        BLOB;    
  
 E_FILE_NOT_FOUND EXCEPTION; 
 
begin 
     
    BEGIN 
        select  to_blob(BLOB_CONTENT) 
        into    V_BLOB 
        from    APEX_APPLICATION_TEMP_FILES     
        where   name = P_FILE_NAME; 
    EXCEPTION 
      WHEN NO_DATA_FOUND THEN raise E_FILE_NOT_FOUND; 
    END; 
     
    insert into AA_REQUESTS_TMP 
        (aa_country_id, emp_email, no_work_days_leave, leave_start, leave_end, vacation_plan, approved, submitted) 
    (SELECT P_AA_COUNTRY_ID 
          ,col001 emp_email 
          ,col003 no_work_days_leave 
          ,to_date(col004,'DD-MON-YYYY') leave_start 
          ,to_date(col005,'DD-MON-YYYY') leave_end 
          ,col002 vacation_plan 
          ,P_APPROVED 
          ,0 
            FROM TABLE( 
            apex_data_parser.parse( p_content            => V_BLOB 
                                   ,p_file_name          => p_file_name 
                                   ,p_add_headers_row    => 'N' 
                                   ,p_csv_col_delimiter  => ',' 
                                   ,p_store_profile_to_collection  => 'FILE_PARSER_COLLECTION' 
                                   ,p_skip_rows => 1)  )) ;    
     
exception 
    when E_FILE_NOT_FOUND then 
      apex_debug.error('IVACATION.UPLOAD_BULK_REQUESTS - file not found'||P_FILE_NAME, sqlerrm); 
       raise_application_error('-20015','You must upload a file.'); 
    when others then     
        raise_application_error('-20019','There is a problem with file upload. Please check the formatting of the columns!'); 
 
end UPLOAD_BULK_REQUESTS; 
 
--***************************************** 
-- 
-- Name:            VALIDATE_BULK_REQUESTS 
-- Type:            Procedure 
-- Creation date:   27-Jul-2022 
-- Created by:      Cristina Ursulescu 
-- Description:     Procedure to validate the uploaded upload file for vacation requests 
-- 
--***************************************** 
 
procedure VALIDATE_BULK_REQUESTS  
    (P_AA_COUNTRY_ID       aa_requests_tmp.aa_country_id%type) 
    
is 
 
V_MESSAGE               aa_requests_tmp.error_message%type; 
V_ACVI                  number; 
V_NEGATIVE_BALANCE      aa_country_vp_int.negative_balance%type; 
 
begin 
  --reset the values of error_message column in case the file was uploaded and validated before 
  update AA_REQUESTS_TMP 
  set ERROR_MESSAGE = null 
  where AA_COUNTRY_ID = P_AA_COUNTRY_ID 
  and SUBMITTED = 0; 
  --validate the values entered by HR 
    for sr in (select upper(T.EMP_EMAIL) EMP_EMAIL 
                    , T.NO_WORK_DAYS_LEAVE 
                    , T.LEAVE_START 
                    , T.LEAVE_END 
                    , T.VACATION_PLAN 
                    , E.EMP_EMAIL EMPLOYEE 
                    , E.AA_COUNTRY_ID EMPLOYEE_COUNTRY  
                    , T.AA_REQUEST_TMP_ID 
                    , E.START_DATE 
               from AA_REQUESTS_TMP T 
               left join AA_EMPLOYEES E ON upper(T.EMP_EMAIL) = upper(E.EMP_EMAIL) 
               where T.AA_COUNTRY_ID = P_AA_COUNTRY_ID 
               and T.SUBMITTED = 0) loop 
                
               v_message := null; 
               --Check that all the fields in the template were filled 
               if (SR.EMP_EMAIL is null or SR.NO_WORK_DAYS_LEAVE is null or SR.LEAVE_START is null  or SR.LEAVE_END is null or SR.VACATION_PLAN is null) then 
                    v_message := v_message||' * All the fields in the template should be filled. '; 
               end if; 
               --check that the employee is in aa_employees table 
               if SR.EMPLOYEE is null then  
                    v_message := v_message||' * The email address is not valid or the employee was not added in the tool. '; 
               end if; 
               --check that the employee belongs to the country selected 
               if SR.EMPLOYEE is not null and SR.EMPLOYEE_COUNTRY <> P_AA_COUNTRY_ID then 
                    v_message := v_message||' * This employee is not part of the country selected. '; 
               end if;      
               --check that the vacation type in the temple is available for the peiod specified 
               begin 
                   select ACVI.AA_COUNTRY_VP_INT_ID 
                   into V_ACVI 
                   from AA_COUNTRY_VP_INT ACVI 
                   where ACVI.AA_COUNTRY_ID = P_AA_COUNTRY_ID 
                   and SR.LEAVE_START between trunc(BEGIN_DATE) and nvl(trunc(END_DATE),SR.LEAVE_START) 
                   and lower(SR.VACATION_PLAN) = lower(ACVI.PLAN_DESC); 
               exception 
                    when NO_DATA_FOUND then V_ACVI:=0; 
               end;                 
                
               if V_ACVI = 0 then  
                    v_message := v_message||' * This vacation plan is not available for the period specified. '; 
               end if; 
               --check that start date is before end date 
               if SR.LEAVE_START > SR.LEAVE_END then 
                    v_message := v_message||' * Leave End must be after Leave Start. '; 
               end if; 
               --check that leave start is after emp's Oracle begin date  
                if SR.LEAVE_START < SR.START_DATE then 
                    v_message := v_message||' * Leave Start must be after employee''s Oracle begin date. '; 
               end if; 
               --check that the period specified is within 1 month 
               if TO_CHAR(SR.LEAVE_START,'mm') != TO_CHAR(SR.LEAVE_END,'mm') then 
                    v_message := v_message||' * First day on leave and Last day of leave must be in the same month. If the leave crosses into another month please submit 2 requests (one for each month) '; 
               end if; 
               --check for another vacation overlapping this one 
               if EXIST_VAC_PERIOD(P_EMP_EMAIL   => SR.EMP_EMAIL 
                                  ,P_LEAVE_START => SR.LEAVE_START 
                                  ,P_LEAVE_END   => SR.LEAVE_END) then 
                   v_message := v_message||' * The employee has already submitted a Vacation Request that is overlapping the same dates as the current one. ';                
               end if;   
               --check negative balance 
               if not ALLOW_NEGATIVE_BALANCE (P_NO_WORK_DAYS_LEAVE   => SR.NO_WORK_DAYS_LEAVE 
                                             ,P_AA_COUNTRY_VP_INT_ID => V_ACVI 
                                             ,P_EMP_EMAIL            => SR.EMP_EMAIL) then 
                  select NEGATIVE_BALANCE 
                  into V_NEGATIVE_BALANCE 
                  from AA_COUNTRY_VP_INT 
                  where AA_COUNTRY_VP_INT_ID = V_ACVI;  
                   
                  if V_NEGATIVE_BALANCE > 0 then          
                        v_message := ' * The employee is entitled to take '|| V_NEGATIVE_BALANCE ||' days from the next Fiscal Year.';          
                  else        
                       v_message := null;        
                   end if;   
                        v_message := v_message || 
                                ' * Employee''s vacation in amount of ' || SR.NO_WORK_DAYS_LEAVE || ' days would lower the balance below '|| V_NEGATIVE_BALANCE; 
              end if; 
                
              update AA_REQUESTS_TMP 
              set ERROR_MESSAGE = v_message 
              where AA_REQUEST_TMP_ID = SR.AA_REQUEST_TMP_ID;           
         
        end loop; 
     
end VALIDATE_BULK_REQUESTS;                 
 
 
--***************************************** 
-- 
-- Name:            PROCESS_REQUESTS 
-- Type:            Procedure 
-- Creation date:   27-Jul-2022 
-- Created by:      Cristina Ursulescu 
-- Description:     Procedure to upload and validate requests submitted from Administration module 
-- 
--***************************************** 
 
procedure PROCESS_REQUESTS  
    (P_AA_COUNTRY_ID         aa_countries.aa_country_id%type 
    ,P_FILE_NAME             varchar2 
    ,P_APPROVED              number) 
    
   is 
    
   begin 
    
   UPLOAD_BULK_REQUESTS  
    (P_AA_COUNTRY_ID        => P_AA_COUNTRY_ID 
    ,P_FILE_NAME            => P_FILE_NAME 
    ,P_APPROVED             => P_APPROVED); 
     
     
   VALIDATE_BULK_REQUESTS  
    (P_AA_COUNTRY_ID       => P_AA_COUNTRY_ID); 
     
end  PROCESS_REQUESTS;    
 
--***************************************** 
-- 
-- Name:            SUBMIT_REQUESTS 
-- Type:            Procedure 
-- Creation date:   27-Jul-2022 
-- Created by:      Cristina Ursulescu 
-- Description:     Procedure to submit requests from Administration module 
-- 
--***************************************** 
 
procedure SUBMIT_REQUESTS  
    (P_AA_COUNTRY_ID         aa_countries.aa_country_id%type 
    ,P_SUBMITTED_BY          varchar2) 
    
   is 
    
   V_CHECK_ERRORS  number; 
   V_ACVI          AA_COUNTRY_VP_INT.AA_COUNTRY_VP_INT_ID%type; 
   V_AA_REQUEST_ID AA_REQUESTS.AA_REQUEST_ID%type;  
    
   E_ERRORS_EXIST       exception; 
   E_NO_REQUEST          exception; 
   E_TOO_MANY_REQUESTS  exception; 
    
   begin 
        
   VALIDATE_BULK_REQUESTS  
    (P_AA_COUNTRY_ID       => P_AA_COUNTRY_ID); 
     
    select count(*) 
      into V_CHECK_ERRORS 
      from AA_REQUESTS_TMP 
     where AA_COUNTRY_ID = P_AA_COUNTRY_ID 
       and SUBMITTED = 0 
       and ERROR_MESSAGE is not null; 
       
    if V_CHECK_ERRORS > 0 then raise E_ERRORS_EXIST; 
    end if; 
     
    for req in (select T.AA_COUNTRY_ID 
                     ,UPPER(T.EMP_EMAIL) EMP_EMAIL 
                     ,T.NO_WORK_DAYS_LEAVE 
                     ,T.LEAVE_START 
                     ,T.LEAVE_END 
                     ,T.VACATION_PLAN 
                     ,T.APPROVED 
                     ,UPPER(E.EMP_MANAGER) MANAGER 
                     ,T.AA_REQUEST_TMP_ID 
                from AA_REQUESTS_TMP T 
                join AA_EMPLOYEES E on UPPER(T.EMP_EMAIL) = UPPER(E.EMP_EMAIL) 
                where t.aa_country_id = P_AA_COUNTRY_ID 
                and t.submitted = 0 
                and ERROR_MESSAGE is null) loop 
                 
            select ACVI.AA_COUNTRY_VP_INT_ID 
                   into V_ACVI 
                   from AA_COUNTRY_VP_INT ACVI 
                   where ACVI.AA_COUNTRY_ID = P_AA_COUNTRY_ID 
                   and req.LEAVE_START between trunc(BEGIN_DATE) and nvl(trunc(END_DATE),req.LEAVE_START) 
                   and lower(req.VACATION_PLAN) = lower(ACVI.PLAN_DESC);      
                 
          if req.APPROVED = 0 then  
            NEW_REQUEST(P_EMAIL_TO              => req.MANAGER 
                       ,P_EMAIL_CC              => IVACATION.GET_EMAIL_CC(req.AA_COUNTRY_ID) 
                       ,P_EMAIL_BCC             => null 
                       ,P_NO_WORK_DAYS_LEAVE    => req.NO_WORK_DAYS_LEAVE 
                       ,P_LEAVE_START           => req.LEAVE_START 
                       ,P_LEAVE_END             => req.LEAVE_END 
                       ,P_AA_COUNTRY_VP_INT_ID  => V_ACVI 
                       ,P_EMP_EMAIL             => req.EMP_EMAIL 
                       ,P_EMP_COMMENTS          => null); 
          else 
            NEW_APPROVED_REQUEST_NO_MAIL( 
                        P_EMAIL_TO              => req.MANAGER 
                       ,P_NO_WORK_DAYS_LEAVE    => req.NO_WORK_DAYS_LEAVE 
                       ,P_LEAVE_START           => req.LEAVE_START 
                       ,P_LEAVE_END             => req.LEAVE_END 
                       ,P_AA_COUNTRY_VP_INT_ID  => V_ACVI 
                       ,P_EMP_EMAIL             => req.EMP_EMAIL 
                      ); 
          end if;  
           
          begin 
              select AR.AA_REQUEST_ID 
              into V_AA_REQUEST_ID 
              from AA_REQUESTS AR 
              where AR.EMP_EMAIL = REQ.EMP_EMAIL 
              and NO_WORK_DAYS_LEAVE = REQ.NO_WORK_DAYS_LEAVE 
              and LEAVE_START = REQ.LEAVE_START 
              and LEAVE_END = REQ.LEAVE_END 
              and CREATED_BY = P_SUBMITTED_BY; 
          exception 
              when NO_DATA_FOUND then raise E_NO_REQUEST; 
              when TOO_MANY_ROWS then raise E_TOO_MANY_REQUESTS; 
          end;    
           
          update AA_REQUESTS_TMP set AA_REQUEST_ID = V_AA_REQUEST_ID where AA_REQUEST_TMP_ID = REQ.AA_REQUEST_TMP_ID; 
    end loop;             
     
    update AA_REQUESTS_TMP 
    set SUBMITTED_BY = P_SUBMITTED_BY, 
        SUBMISSION_DATE = sysdate, 
        SUBMITTED = 1 
    where AA_COUNTRY_ID =  P_AA_COUNTRY_ID 
    and SUBMITTED = 0; 
            
     
  exception 
    when E_ERRORS_EXIST then  
       raise_application_error(-20016,'The records that you are trying to submit contain errors. Please delete the records and upload a new file!');  
    when E_NO_REQUEST then  
       raise_application_error(-20017,'Issue when submitting one of the requests, please contact application administrator!');    
    when E_TOO_MANY_REQUESTS then  
       raise_application_error(-20018,'Issue when submitting one of the requests, please contact application administrator!');        
     
end  SUBMIT_REQUESTS;   

 
--***************************************** 
-- 
-- Name:            get_country_id 
-- Type:            Procedure 
-- Creation date:   10-sep-2024 
-- Created by:      Rohit kumar
-- Description:     Procedure to get country id when role from OIM_INTG_USERS_AND_ROLES_V pass
-- 
--***************************************** 

FUNCTION get_country_id(role_name in VARCHAR2) RETURN NUMBER IS
        country_id NUMBER;
    BEGIN
        -- Get the country ID based on the ROLE_NAME
        SELECT AA_COUNTRY_ID INTO country_id
        FROM AA_COUNTRIES
        WHERE COUNTRY_ISO_CODE = TRIM(SUBSTR(role_name, 1, INSTR(role_name, ' ') - 1));
        
        RETURN country_id;
   
    END get_country_id;

--***************************************** 
-- 
-- Name:            update_AA_USER_CT_ROLE_INT 
-- Type:            Procedure 
-- Creation date:   10-sep-2024 
-- Created by:      Rohit kumar
-- Description:     Procedure to update AA_USER_CT_ROLE_INT from MD_USERS_V and OIM_INTG_USERS_AND_ROLES_V table 
--                  
--***************************************** 

procedure update_AA_USER_CT_ROLE_INT 
is 
    role_id_hr NUMBER;
    role_id_payroll NUMBER;


BEGIN
    -- Get the role ID for 'Country HR' & 'Country Payroll'
    SELECT AA_ROLE_ID INTO role_id_hr FROM AA_ROLES WHERE AA_ROLE = 'Country HR';
    SELECT AA_ROLE_ID INTO role_id_payroll FROM AA_ROLES WHERE AA_ROLE = 'Country Payroll';

    -- Deactivate all roles in AA_USER_CT_ROLE_INT
    UPDATE AA_USER_CT_ROLE_INT SET ACTIVE = 0;

    -- Merge operation
    MERGE INTO AA_USER_CT_ROLE_INT t
    USING (
        SELECT USERNAME, get_country_id(ROLE_NAME) COUNTRY_ID ,role_id_hr role_id FROM OIM_INTG_USERS_AND_ROLES_V WHERE INSTR(UPPER(ROLE_NAME), 'ATT') = 0
           UNION ALL 
           select MD.USERNAME , AA.AA_COUNTRY_ID COUNTRY_ID , role_id_payroll role_id from MD_USERS_V MD, AA_COUNTRIES AA where MD.ROLE_NAME IN ('EMEA APPROVER' , 'EMEA PAYROLL ANALYST') and AA.ACTIVE = 1
        ) s
    ON (t.EMP_EMAIL = s.USERNAME and t.AA_COUNTRY_ID = s.COUNTRY_ID and t.AA_ROLE_ID = s.role_id )
    WHEN MATCHED THEN
        UPDATE SET t.ACTIVE = 1

    WHEN NOT MATCHED THEN 
        INSERT (EMP_EMAIL, AA_COUNTRY_ID, AA_ROLE_ID) 
        VALUES (s.USERNAME, s.COUNTRY_ID , s.role_id);
             


 -- Deactivate all roles in SITT_USER_ROLES
    UPDATE SITT_USER_ROLES SET SUR_ACTIVE = 0;

    -- Merge operation
    MERGE INTO SITT_USER_ROLES t
    USING (SELECT 
    USERNAME,  
    COUNTRY_ID, 
    CASE 
        WHEN COUNTRY_ID IS NOT NULL THEN role_id_hr 
        ELSE role_id_payroll 
    END AS role_id
FROM (SELECT USERNAME, IVACATION.get_country_id(ROLE_NAME) COUNTRY_ID  FROM OIM_INTG_USERS_AND_ROLES_V WHERE INSTR(UPPER(ROLE_NAME), 'ATT') > 0)
         
        ) s
    ON (t.SUR_EMAIL = s.USERNAME and NVL(t.SUR_COUNTRY_ID, 0) = NVL(s.COUNTRY_ID, 0) and t.SUR_ROLE_ID = s.role_id )
    WHEN MATCHED THEN
        UPDATE SET t.SUR_ACTIVE = 1

    WHEN NOT MATCHED THEN 
        INSERT (SUR_EMAIL, SUR_COUNTRY_ID, SUR_ROLE_ID, SUR_ACTIVE) 
        VALUES (s.USERNAME, s.COUNTRY_ID , s.role_id , 1);
             

    COMMIT;  


END update_AA_USER_CT_ROLE_INT;
 

function is_country_allowed(p_emp_email in varchar2)
return boolean
is
l_country_id aa_employees.aa_country_id%type;
begin
if p_emp_email is null then
return false;
end if;

select aa_country_id
into l_country_id
from aa_employees
where upper(emp_email) = upper(p_emp_email);

return l_country_id <> 28;

exception
when no_data_found then
return true;
when too_many_rows then
return false; -- handle per policy if needed
end is_country_allowed;

--***************************************** 
-- 
-- Name:            update_aa_oim_intg_users_and_roles 
-- Type:            Procedure 
-- Creation date:   16-JAN-2026 
-- Created by:      Rohit kumar
-- Description:     Procedure to refresh aa_oim_intg_users_and_roles , which is being use by payroll_prod for audit tool.
--                  
--***************************************** 

PROCEDURE update_aa_oim_intg_users_and_roles
IS
BEGIN
  DELETE FROM aa_oim_intg_users_and_roles;

  INSERT INTO aa_oim_intg_users_and_roles (application_name, username, role_name, last_updated)
    SELECT application_name, username, role_name, SYSDATE
      FROM oim_intg_users_and_roles_v;

  COMMIT;
END update_aa_oim_intg_users_and_roles;

end;
/