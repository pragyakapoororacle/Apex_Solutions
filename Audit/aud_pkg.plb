create or replace package body "AUD_PKG" as

c_pkg_version constant varchar2(5 char) := '1';
c_pkg_name constant varchar2(30 char) := 'AUD_PKG';


procedure send_mail_to_director (
    p_year    in number,
    p_quarter in varchar2
) is

  cursor c0 is
    select a.director_id,
           a.user_name,
           (select type_name from aud_type where type_id = a.type_id) as type_name
      from aud_main a
     where a.financial_year = p_year
       and a.quarter        = p_quarter;

  cursor c1 is
    select distinct
           b.director,
           b.id,
           (select to_char(web_template_html)
              from aud_template
             where template_id = b.mail_template_id) as web_template_html
      from aud_main a
      join aud_director b on a.director_id = b.id
     where a.financial_year = p_year
       and a.quarter        = p_quarter;

begin
  for i in c0 loop
    if i.director_id = -1 then
      raise_application_error(
        -20001,
        'Director not found for some USER at System ' || i.type_name
      );
    end if;
  end loop;

  for i in c1 loop
    begin
      build_email(
        case
          when pcg.is_prod_env = pcg.c_yes
          then i.director || ',' ||
               'anupam.ankesh@oracle.com,milagro.valverde@oracle.com'
          else 'anupam.ankesh@oracle.com'
        end,
        c_application_id,
        case when pcg.is_prod_env = pcg.c_yes then '' else 'TEST ' end || c_application_name,
        p_year,
        p_quarter,
        'QUARTERLY AUDIT - Payroll Accesses',
        i.web_template_html
      );

      update aud_main
         set status = c_sent_to_director
       where financial_year = p_year
         and quarter        = p_quarter
         and director_id    = i.id;

    exception
      when others then
        raise_application_error(
          -20002,
          'Failed to send email to: ' || i.director || '. Error: ' || sqlerrm
        );
    end;
  end loop;

  update aud_year_quarter_tracker
     set status = 'Sent to Director'
   where year    = p_year
     and quarter = p_quarter;

end send_mail_to_director;

procedure send_mail_to_admin (
    p_year in number  , 
    p_quarter in varchar2 ,
    p_director_id in  number 
   
)  is 

p_director varchar2(64) ; 
cursor c1 is
SELECT TO_CHAR(WEB_TEMPLATE_HTML) WEB_TEMPLATE_HTML
     FROM AUD_TEMPLATE
     WHERE TEMPLATE_NAME = 'Admin' ;


begin 

select DIRECTOR into p_director from AUD_DIRECTOR where ID = p_director_id ; 

for i in c1 loop 
begin
    pcg.sendmail(
        -- case when pcg.is_prod_env = pcg.c_Yes then c_admin|| ',' || 'anupam.ankesh@oracle.com,milagro.valverde@oracle.com' else 'anupam.ankesh@oracle.com,milagro.valverde@oracle.com,karthikeyan.madhu@oracle.com' end,
        case when pcg.is_prod_env = pcg.c_Yes then 'anupam.ankesh@oracle.com,milagro.valverde@oracle.com,pragya.kapoor@oracle.com' end ,
        c_Application_ID,
        case when pcg.is_prod_env = pcg.c_Yes then '' else 'TEST ' end || c_Application_Name,
      'QUARTERLY AUDIT - '||p_year||' - '||p_quarter||' - '|| p_director,
      i.WEB_TEMPLATE_HTML
    );


    EXCEPTION
            WHEN OTHERS THEN
               
                RAISE_APPLICATION_ERROR(-20002, 'Failed to send email to Admin');
    END;
   
end loop ;
end send_mail_to_admin; 

procedure update_web_template (
    p_web_template_html IN CLOB,
    p_template_id IN NUMBER
) 
AS
BEGIN
    UPDATE AUD_TEMPLATE
    SET WEB_TEMPLATE_HTML = p_web_template_html
    WHERE TEMPLATE_ID = p_template_id;
END update_web_template;

PROCEDURE upload_user_roles_osvc(
    p_year     IN NUMBER,
    p_quarter  IN VARCHAR2,
    p_type_id  IN NUMBER
) as
    p_type_id_global NUMBER := 0;
    run              NUMBER := 0;
    v_max_file_id    NUMBER;

    -- Define a record type for user roles
    TYPE user_role_rec IS RECORD (
        id          NUMBER,
        username    VARCHAR2(256),
        role_name   VARCHAR2(256)
    );
    
    -- Define a collection type for bulk collect
    TYPE user_role_tab IS TABLE OF user_role_rec;
    v_user_roles user_role_tab;

    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(100 char) := 'upload_user_roles_osvc';
    v_ln varchar2(4000 char);

BEGIN
    v_ln := 0;
    -- Get the latest FILE_ID once to avoid repetitive subqueries
    SELECT MAX(FILE_ID)
    INTO v_max_file_id
    FROM AUD_OSVC_MAIL;

    pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'v_max_file_id='||to_char(v_max_file_id),null,'DEBUG');
    v_ln := 1;
    -- Check if records exist for the given parameters
    SELECT COUNT(*)
    INTO run
    FROM AUD_MAIN 
    WHERE FINANCIAL_YEAR = p_year 
      AND QUARTER = p_quarter 
      AND TYPE_ID = p_type_id;

    pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'run='||to_char(run),null,'DEBUG');
    -- Proceed only if no records exist
    IF run = 0 THEN
        v_ln := 2;
        -- Bulk Collect 
        SELECT ID, 
               TRIM(UPPER(LOGIN)) AS USERNAME, 
               TRIM(PROFILE) AS ROLE_NAME
        BULK COLLECT INTO v_user_roles
        FROM AUD_OSVC_MAIL
        WHERE FILE_ID = v_max_file_id 
          AND STATUS = 'TRUE';

        -- Update STATUS in bulk
        -- FORALL i IN v_user_roles.FIRST .. v_user_roles.LAST
        --     UPDATE AUD_OSVC_MAIL 
        --     SET STATUS = 'FALSE' 
        --     WHERE ID = v_user_roles(i).id;

        -- Insert new records in bulk
        FORALL i IN v_user_roles.FIRST .. v_user_roles.LAST
            INSERT INTO AUD_MAIN (FINANCIAL_YEAR, QUARTER, USER_NAME, ROLE, TYPE_ID)
            VALUES (p_year, p_quarter, 
                    v_user_roles(i).username, 
                    v_user_roles(i).role_name, 
                    p_type_id);

        -- Commit the changes
        COMMIT;
    END IF;
    v_ln := 3;
    -- Call the external procedure
    AUD_PKG.map_new_user_update_director_all(p_year, p_quarter, p_type_id, p_type_id_global);
    pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'p_year='||TO_CHAR(p_year)||'p_quarter='||p_quarter,null,'DEBUG');

EXCEPTION
WHEN OTHERS THEN
  ROLLBACK;
  pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'['||v_ln||'] -'||SQLERRM,SQLCODE,'ERROR');
  raise;

END upload_user_roles_osvc;



PROCEDURE upload_user_roles_ivacation( p_year in number  , 
    p_quarter in varchar2 , 
    p_type_id in number ) AS

    p_type_id_global number := 0 ; 
    run number := 0 ;
    CURSOR cur_users_roles IS
        SELECT APPLICATION_NAME,USERNAME,ROLE_NAME
        FROM AA_OIM_INTG_USERS_AND_ROLES;

   
  
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(100 char) := 'upload_user_roles_ivacation';
    v_ln varchar2(4000 char);

BEGIN
    v_ln := 0;
    select count(*) into run from AUD_MAIN where FINANCIAL_YEAR = p_year and QUARTER = p_quarter and TYPE_ID = p_type_id ; 
    pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'run='||to_char(run),null,'DEBUG');
    IF RUN = 0 THEN 
    FOR rec IN cur_users_roles LOOP
       
        INSERT INTO AUD_MAIN (FINANCIAL_YEAR, QUARTER, USER_NAME, APPLICATION_NAME, ROLE, TYPE_ID)
        VALUES (p_year, p_quarter, rec.USERNAME, rec.APPLICATION_NAME, rec.ROLE_NAME, p_type_id);

    END LOOP;

    COMMIT;
    END IF ; 
v_ln := 1;
AUD_PKG.map_new_user_update_director_all(p_year ,p_quarter,p_type_id, p_type_id_global  ) ;
pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'p_year='||TO_CHAR(p_year)||'p_quarter='||p_quarter,null,'DEBUG');


EXCEPTION
WHEN OTHERS THEN
  ROLLBACK;
  pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'['||v_ln||'] -'||SQLERRM,SQLCODE,'ERROR');
  raise;

END upload_user_roles_ivacation;

--- as per new config design 
FUNCTION get_director_id(p_emp_email VARCHAR2) 
RETURN Number 
IS
    v_director_id number;
BEGIN
    FOR rec IN (
        SELECT 
            UPPER(M.MANAGER_01_EMAIL_ADDRESS) AS MANAGER_01_EMAIL_ADDRESS,
            UPPER(M.MANAGER_02_EMAIL_ADDRESS) AS MANAGER_02_EMAIL_ADDRESS,
            UPPER(M.MANAGER_03_EMAIL_ADDRESS) AS MANAGER_03_EMAIL_ADDRESS,
            UPPER(M.MANAGER_04_EMAIL_ADDRESS) AS MANAGER_04_EMAIL_ADDRESS,
            UPPER(M.MANAGER_05_EMAIL_ADDRESS) AS MANAGER_05_EMAIL_ADDRESS,
            UPPER(M.MANAGER_06_EMAIL_ADDRESS) AS MANAGER_06_EMAIL_ADDRESS,
            UPPER(M.MANAGER_07_EMAIL_ADDRESS) AS MANAGER_07_EMAIL_ADDRESS,
            UPPER(M.MANAGER_08_EMAIL_ADDRESS) AS MANAGER_08_EMAIL_ADDRESS,
            UPPER(M.MANAGER_09_EMAIL_ADDRESS) AS MANAGER_09_EMAIL_ADDRESS,
            UPPER(M.MANAGER_10_EMAIL_ADDRESS) AS MANAGER_10_EMAIL_ADDRESS
        FROM MD_EMPLOYEES M
        WHERE UPPER(M.EMP_EMAIL_ADDRESS) = UPPER(p_emp_email)
    ) LOOP
        FOR i IN 1..10 LOOP
            BEGIN
                
                v_director_id := NULL;

                
                EXECUTE IMMEDIATE 
                    'SELECT ID 
                     FROM AUD_DIRECTOR  
                    
                    WHERE 
                       UPPER(:manager_email) = UPPER(DIRECTOR)' 
                INTO v_director_id
                USING CASE i 
                       WHEN 1 THEN rec.MANAGER_01_EMAIL_ADDRESS
                       WHEN 2 THEN rec.MANAGER_02_EMAIL_ADDRESS
                       WHEN 3 THEN rec.MANAGER_03_EMAIL_ADDRESS
                       WHEN 4 THEN rec.MANAGER_04_EMAIL_ADDRESS
                       WHEN 5 THEN rec.MANAGER_05_EMAIL_ADDRESS
                       WHEN 6 THEN rec.MANAGER_06_EMAIL_ADDRESS
                       WHEN 7 THEN rec.MANAGER_07_EMAIL_ADDRESS
                       WHEN 8 THEN rec.MANAGER_08_EMAIL_ADDRESS
                       WHEN 9 THEN rec.MANAGER_09_EMAIL_ADDRESS
                       WHEN 10 THEN rec.MANAGER_10_EMAIL_ADDRESS
                     END;

                
                IF v_director_id IS NOT NULL THEN
                    RETURN v_director_id;
                END IF;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;  
                WHEN OTHERS THEN
                    dbms_output.put_line('Error for manager ' || i || ': ' || SQLERRM);
            END;
        END LOOP;
    END LOOP;

    -- If no director is found, return -1
    RETURN -1;
END get_director_id;







PROCEDURE upload_user_roles_apex( p_year in number  , 
    p_quarter in varchar2 , 
    p_type_id in number ) AS

    p_type_id_global number := 0 ; 
    run number := 0 ;
    CURSOR cur_users_roles IS
        SELECT USERNAME, APPLICATION_NAME, ROLE_NAME 
        FROM APS_INTG_USERS_AND_ROLES_V;

   
  
    c_proc_version constant varchar2(5 char) := '1.0';
    c_proc_name constant varchar2(100 char) := 'upload_user_roles_apex';
    v_ln varchar2(4000 char);

BEGIN
    v_ln := 0;
    select count(*) into run from AUD_MAIN where FINANCIAL_YEAR = p_year and QUARTER = p_quarter and TYPE_ID = p_type_id ; 
    pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'run='||to_char(run),null,'DEBUG');
    IF RUN = 0 THEN 
    FOR rec IN cur_users_roles LOOP
       
        INSERT INTO AUD_MAIN (FINANCIAL_YEAR, QUARTER, USER_NAME, APPLICATION_NAME, ROLE, TYPE_ID)
        VALUES (p_year, p_quarter, rec.USERNAME, rec.APPLICATION_NAME, rec.ROLE_NAME, p_type_id);

    END LOOP;

    COMMIT;
    END IF ; 
v_ln := 1;
AUD_PKG.map_new_user_update_director_all(p_year ,p_quarter,p_type_id, p_type_id_global  ) ;
pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'p_year='||TO_CHAR(p_year)||'p_quarter='||p_quarter,null,'DEBUG');


EXCEPTION
WHEN OTHERS THEN
  ROLLBACK;
  pcg.log(c_pkg_name||'.'||c_proc_name,c_pkg_version,c_proc_version,'['||v_ln||'] -'||SQLERRM,SQLCODE,'ERROR');
  raise;

END upload_user_roles_apex;


procedure read_mails is 
  v_file_name varchar2(4000);
  v_file clob;
  v_file_decoded clob;
  v_file_blob blob;
  v_emails_response CLOB;
  v_attachments_response CLOB;
  v_marking_response CLOB;
  v_cnt number;
  v_msg_id varchar2(4000 char);
  v_rowcount number;
   v_subject varchar2(4000 char);
  v_file_type varchar2(4000 char);
  v_file_id number ; 


  c_proc_name constant varchar2(61 char) := c_pkg_name||'.'||'read_mails';
  c_proc_version constant varchar2(5 char) := '1';
  v_ln clob;

  function clob2blob(AClob CLOB) return BLOB is
    Result BLOB; o1 integer; o2 integer; c integer; w integer;
  begin
    o1 := 1; o2 := 1; c := 0; w := 0;
    DBMS_LOB.CreateTemporary(Result, true);
    DBMS_LOB.ConvertToBlob(Result, AClob, length(AClob), o1, o2, 0, c, w);
    return(Result);
  end clob2blob;

begin
  v_ln := '1';
  wwv_flow_api.set_security_group_id;

  v_ln := '2';
  v_emails_response := apex_web_service.make_rest_request
  (
      p_proxy_override       => 'appoci-proxy01-vip.oraclevcn.com:80',
      p_url                  => replace('https://graph.microsoft.com/v1.0/users/'||c_user||'/messages?$count=true&$select=subject,from,isRead,id,bodyPreview&$filter=((receivedDateTime ge 2024-08-08T00:00:00Z) and (isRead eq false) and (startswith(subject,''AUDIT CX USERS'')))&$orderby=receivedDateTime asc', ' ', c_space),
      p_http_method          => 'GET',
      p_token_url            => 'https://login.microsoftonline.com/'||c_tenant||'/oauth2/v2.0/token',
      p_credential_static_id => 'payroll_exchange'
    );


   v_ln := '3 - '||to_char(v_emails_response);
  v_cnt := json_value(v_emails_response,'$."@odata.count"' returning number);
     v_ln := '4 - '||to_char(v_emails_response);
    pcg.log(c_proc_name, c_pkg_version, c_proc_version, 'v_emails_response:'||to_char(v_emails_response), null, 'D');
  for i in 0..v_cnt-1 loop
    begin
     v_ln := '6 - '||to_char(v_emails_response);
    v_msg_id := json_value (v_emails_response,'$.value['||to_char(i)||'].id' returning varchar2);
    v_ln := '7 - '||to_char(v_msg_id);
    v_subject := json_value (v_emails_response,'$.value['||to_char(i)||'].subject' returning varchar2);
    dbms_output.put_line(v_subject );
      v_attachments_response := apex_web_service.make_rest_request(
          p_proxy_override       => 'appoci-proxy01-vip.oraclevcn.com:80',
          p_url                  => replace('https://graph.microsoft.com/v1.0/users/'||c_user||'/messages/'||v_msg_id||'/attachments', ' ', c_space),
          p_http_method          => 'GET',
          p_token_url            => 'https://login.microsoftonline.com/'||c_tenant||'/oauth2/v2.0/token',
          p_credential_static_id => 'payroll_exchange'
        );

      
    v_ln := '8 - '||to_char(v_attachments_response);
      v_file_name := json_value(v_attachments_response,'$."value"[0]."name"' returning varchar2);
v_ln := '9 - '||to_char(v_attachments_response);
    
      v_file := json_value(v_attachments_response,'$."value"[0]."contentBytes"' returning clob);

   v_ln := '9b - '||to_char(v_attachments_response);
      v_file_type := json_value(v_attachments_response,'$."value"[0]."@odata.mediaContentType"' returning varchar2);


         v_ln := '10 - '||v_file_name||' - '||to_char(v_file)/*UTL_RAW.CAST_TO_VARCHAR2(v_file)*/;
      v_file_decoded := UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(v_file)));
  v_ln := '10b - '||to_char(v_file_decoded);
      v_file_blob := clob2blob(v_file_decoded);
    -- dbms_output.put_line(v_file_name || ' ' ||v_file|| ' ' ||v_file_type|| ' ' ||v_msg_id);
v_ln := '10d';
     select "AUD_OSVC_MAIL_SEQ1".nextval into v_file_id from sys.dual ;
    
      v_rowcount := 0;
      for k in (
        
          select line_number, col001, col002, col003, col004, col005, col006, col007 from table(apex_data_parser.parse(
            p_content => v_file_blob,
            p_file_name => v_file_name,
            p_csv_col_delimiter => ','
          )) where line_number > 1   --- FETCH DATA FROM 2RD ROW OF EXCEL FILE IN MAIL
        ) 
       loop
       v_ln := '11a';
        begin
          v_rowcount := v_rowcount + 1;
        
        v_ln := '11b - '||to_char(v_rowcount)||'-'||k.col001 ;
    --    dbms_output.put_line(v_subject||' ' || k.col001|| ' ' || k.col002|| ' ' || k.col003|| ' ' || k.col004|| ' ' ||k.col005|| ' ' || k.col006|| ' ' || k.col007 );

        INSERT INTO AUD_OSVC_MAIL (FILE_ID, PROFILE, ACCOUNT_ID, LAST_NAME,  FIRST_NAME, LOGIN, GROUP_NAME, COMMENTS , STATUS) VALUES
        ( v_file_id, k.col001, to_number(k.col002),  k.col003,  k.col004,  k.col005,  k.col006,  k.col007 , 'TRUE' ) ; 
      COMMIT ; 
       v_ln := '12';
      exception when others then
          pcg.log(c_proc_name, c_pkg_version, c_proc_version, to_char(v_rowcount)||' ['||to_char(v_ln)||'] ('||k.col005||'-'||k.col001||')'||SQLERRM, SQLCODE);
          raise;
        end;
      end loop;
        -- After the loop:
        IF v_rowcount > 0 THEN
          UPDATE AUD_OSVC_MAIL
          SET STATUS = 'FALSE'
          WHERE FILE_ID != v_file_id
            AND STATUS = 'TRUE';
        END IF;
v_ln := '13';
    ----mark mail as read 
    if pcg.is_prod_env='Y'
      then
     v_ln := '14';
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json; charset=utf-8';
        v_ln := '15 - '||v_msg_id;
        v_marking_response := apex_web_service.make_rest_request
            (
             p_proxy_override       => 'appoci-proxy01-vip.oraclevcn.com:80',
             p_url                  => 'https://graph.microsoft.com/v1.0/users/'||c_user||'/messages/'||v_msg_id,
             p_http_method          => 'PATCH',
             p_token_url            => 'https://login.microsoftonline.com/'||c_tenant||'/oauth2/v2.0/token',
             p_credential_static_id => 'payroll_exchange',
             p_body                 => '{"isRead":"true"}'
             );
        v_ln := '16 - '||to_char(v_marking_response);
      end if;
   
    end;
   
  end loop;
 
  commit;
  exception when others then
  pcg.log(c_proc_name, c_pkg_version, c_proc_version, '['||to_char(v_ln)||'] '||SQLERRM, SQLCODE);
  raise;
end ;




function is_admin_access(p_user in varchar2 default v('APP_USER')) return char deterministic is
  l_tmp number;
begin
  select max(1) into l_tmp from MD_USERS_V
  where upper(USERNAME) = upper(p_user) AND (ROLE = 'ADMINISTRATOR' OR USERNAME = 'MILAGRO.VALVERDE@ORACLE.COM' ) ;
  return case l_tmp when 1 then 'Y' else 'N' end;
end is_admin_access;

function is_admin_access(
    p_year    in number,
    p_quarter in varchar2,
    p_user    in varchar2 default v('APP_USER')
) return char deterministic
is
  l_tmp   number;
  p_status varchar2(32);
begin
  select max(1)
    into l_tmp
    from MD_USERS_V
   where upper(USERNAME) = upper(p_user)
     and (ROLE = 'ADMINISTRATOR'
          or USERNAME = 'MILAGRO.VALVERDE@ORACLE.COM');

  select status
    into p_status
    from AUD_YEAR_QUARTER_TRACKER
   where year = p_year
     and quarter = p_quarter;

  return case when l_tmp = 1 and p_status = 'WIP' then 'Y' else 'N' end;
end is_admin_access;

FUNCTION columns_access(p_type_id IN NUMBER, p_column in varchar2)
RETURN BOOLEAN
IS
    v_system VARCHAR2(64);
BEGIN
    SELECT TYPE_NAME
    INTO v_system
    FROM AUD_TYPE
    WHERE TYPE_ID = p_type_id;

if p_column = 'USER_NAME' and UPPER(v_system) IN ('APEX', 'BANK', 'GENERIC EMAILS', 'HCM', 'OSVC','SPM-ADP','HR PAYROLL RESP','APEX IVACATION','AOR PAYROLL HCM','FTL','INT SP-RECDOCS','EXT SP-SECURESITES','AOR FTL','INT SPOINT','EXT SPOINT') THEN
    RETURN true; 
elsif p_column = 'APPLICATION_NAME' and UPPER(v_system) IN ('APEX','APEX IVACATION','INT SP-RECDOCS','EXT SP-SECURESITES','INT SPOINT','EXT SPOINT') THEN
    RETURN true;
elsif p_column = 'ROLE' and UPPER(v_system) IN ('APEX', 'BANK','HCM', 'OSVC','SPM-ADP','HR PAYROLL RESP','APEX IVACATION','AOR PAYROLL HCM','FTL','INT SP-RECDOCS','EXT SP-SECURESITES','AOR FTL','INT SPOINT','EXT SPOINT') THEN
    RETURN true;
elsif p_column IN ('BANK')  and UPPER(v_system) IN ('BANK') THEN
    RETURN true;
elsif p_column = 'NAME' and UPPER(v_system) IN ('BANK') THEN
    RETURN true;
elsif p_column = 'REGION' and UPPER(v_system) IN ('GENERIC EMAILS','INT SP-RECDOCS','EXT SP-SECURESITES','INT SPOINT','EXT SPOINT') THEN
    RETURN true;   
elsif p_column = 'GENERIC_EMAIL' and UPPER(v_system) IN ('GENERIC EMAILS') THEN
    RETURN true;    
elsif p_column = 'COUNTRY' and UPPER(v_system) IN ('SPM-ADP','AOR PAYROLL HCM','AOR FTL') THEN
    RETURN true;       
elsif p_column = 'SCOPENAME' and UPPER(v_system) IN ('SPM-ADP') THEN
    RETURN true;  
elsif p_column = 'DETAILDATA' and UPPER(v_system) IN ('AOR PAYROLL HCM','AOR FTL') THEN
    RETURN true;     
ELSE
    RETURN false;
END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
  
END columns_access;

function is_director_access(p_user in varchar2 default v('APP_USER')) return char deterministic is
  l_tmp number;
begin
  SELECT max(1) into l_tmp FROM AUD_DIRECTOR WHERE upper(DIRECTOR) = upper(p_user) ;
  return case l_tmp when 1 then 'Y' else 'N' end;
end is_director_access;


function is_user_access(p_user in varchar2 default v('APP_USER')) return char deterministic is
  l_tmp number;
begin
select max(tmp) into l_tmp from (
  select max(1) tmp from MD_USERS_V
  where upper(USERNAME) = upper(p_user) AND (ROLE = 'ADMINISTRATOR' OR USERNAME = 'MILAGRO.VALVERDE@ORACLE.COM' ) 
  union all
  SELECT max(1) tmp FROM AUD_DIRECTOR WHERE upper(DIRECTOR) = upper(p_user) );
  return case l_tmp when 1 then 'Y' else 'N' end;
end is_user_access;

 function report(
    p_year in number  , 
    p_quarter in varchar2,
    p_type number ,
    p_user in varchar2
    ) return varchar2  
is 

    v_query VARCHAR2(4000);
BEGIN
     v_query := ' SELECT MAIN_ID,
                           TYPE_ID,
                           FINANCIAL_YEAR,
                           QUARTER,
                           USER_NAME,
                           APPLICATION_NAME,
                           ROLE_ID,
                           DIRECTOR_ID,
                           USER_VALIDATION,
                           JUSTIFICATION,
                           CREATED_BY,
                           UPDATED_BY
                    FROM AUD_MAIN ';
    IF AUD_PKG.is_admin_access(p_user) = 'Y' THEN
        v_query := v_query || ' WHERE FINANCIAL_YEAR = ' || p_year || ' AND QUARTER = ' ||p_quarter ||' AND TYPE_ID = ' || p_type ;

    ELSIF AUD_PKG.is_director_access(p_user) = 'Y' THEN
        v_query := v_query || ' WHERE FINANCIAL_YEAR = ' || p_year || ' AND QUARTER = ' ||p_quarter ||' AND TYPE_ID = ' || p_type||  ' AND DIRECTOR_ID IN (SELECT id FROM AUD_DIRECTOR WHERE UPPER(DIRECTOR) = UPPER( ' ||p_user|| '))';

    ELSE
        v_query := v_query || ' WHERE 1 = 2';  -- Returns no data
    END IF;

    RETURN v_query;
END report ;

FUNCTION get_or_create_id_for_director(p_email IN VARCHAR2) RETURN NUMBER IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      p_id NUMBER;
BEGIN

    SELECT id 
    INTO p_id
    FROM AUD_DIRECTOR
    WHERE DIRECTOR = upper(p_email)
    FETCH FIRST 1 ROWS ONLY;  -- Ensures only one row is selected (for safety)

    RETURN p_id;  

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- If email does not exist, insert it and get the new ID
        INSERT INTO AUD_DIRECTOR (DIRECTOR) 
        VALUES (upper(p_email)) 
        RETURNING id INTO p_id;  
        commit ; 
        RETURN p_id;  

    WHEN OTHERS THEN
        rollback ; 
        RAISE;
END get_or_create_id_for_director;


PROCEDURE update_director_all (
    p_year IN NUMBER,
    p_quarter IN VARCHAR2,
    p_type_id IN NUMBER,
    p_type_id_global IN NUMBER
)
AS

    -- Result flag
    res NUMBER;

    -- Define a record type for region-director pairs
    TYPE region_director_rec IS RECORD (
        region       VARCHAR2(100),
        director_id  NUMBER
    );

    -- Define an index-by associative array for user-level director mappings
    TYPE region_director_arr IS TABLE OF region_director_rec INDEX BY PLS_INTEGER;

    -- Cursor taking only user_name as input
    CURSOR c1(p_user_name VARCHAR2) IS
           SELECT 
       
        COALESCE(
            d1_reg.DIRECTOR_ID,
            d1_global.DIRECTOR_ID,
            d2_reg.DIRECTOR_ID,
            d2_global.DIRECTOR_ID
        ) AS DIRECTOR_ID,
        COALESCE(
            d1_reg.LOC,
            d1_global.LOC,
            d2_reg.LOC,
            d2_global.LOC
        ) AS DIRECTOR_REGION
    FROM (
        SELECT DISTINCT 
            USER_NAME, 
            NVL(REGION, 'GLOBAL') AS REGION
        FROM AUD_MAIN
        WHERE FINANCIAL_YEAR = P_year
          AND QUARTER = P_quarter
          AND TYPE_ID = P_type_id
          and USER_NAME = p_user_name
    ) u
    LEFT JOIN AUD_DIRECTOR_MAP d1_reg
        ON u.USER_NAME = d1_reg.USER_NAME
       AND d1_reg.TYPE_ID = P_type_id
       AND d1_reg.LOC = u.REGION
    LEFT JOIN AUD_DIRECTOR_MAP d1_global
        ON u.USER_NAME = d1_global.USER_NAME
       AND d1_global.TYPE_ID = P_type_id
       AND d1_global.LOC = 'GLOBAL'
    LEFT JOIN AUD_DIRECTOR_MAP d2_reg
        ON u.USER_NAME = d2_reg.USER_NAME
       AND d2_reg.TYPE_ID = P_type_id_global
       AND d2_reg.LOC = u.REGION
    LEFT JOIN AUD_DIRECTOR_MAP d2_global
        ON u.USER_NAME = d2_global.USER_NAME
       AND d2_global.TYPE_ID = P_type_id_global
       AND d2_global.LOC = 'GLOBAL' ;

BEGIN
    -- Check if relevant rows exist
    SELECT MAX(1)
    INTO res
    FROM AUD_MAIN
    WHERE FINANCIAL_YEAR = p_year
      AND QUARTER = p_quarter
      AND TYPE_ID = p_type_id;

    IF res = 1 THEN
        -- Outer loop for each record in AUD_MAIN
        FOR i IN (
            SELECT MAIN_ID, USER_NAME, NVL(REGION, 'GLOBAL') AS REGION 
            FROM AUD_MAIN 
            WHERE FINANCIAL_YEAR = p_year
              AND QUARTER = p_quarter
              AND TYPE_ID = p_type_id
                
        ) LOOP
            -- Create an associative array for j output
            DECLARE
                directors region_director_arr;
                idx PLS_INTEGER := 0;
                matched BOOLEAN := FALSE;
            BEGIN
                -- Collect all region-director pairs into the array
                FOR j IN c1(i.USER_NAME) LOOP
                    idx := idx + 1;
                    directors(idx).region := NVL(j.DIRECTOR_REGION, 'GLOBAL');
                    directors(idx).director_id := j.DIRECTOR_ID;
                END LOOP;

                -- Loop through array to match region exactly
                FOR i2 IN directors.FIRST .. directors.LAST LOOP
                    IF directors(i2).region = i.REGION THEN
                        UPDATE AUD_MAIN
                        SET DIRECTOR_ID = directors(i2).director_id
                        WHERE MAIN_ID = i.MAIN_ID;
                        matched := TRUE;
                        EXIT;
                    END IF;
                END LOOP;

                -- If not matched by region, try GLOBAL fallback
                IF NOT matched THEN
                    FOR i2 IN directors.FIRST .. directors.LAST LOOP
                        IF directors(i2).region = 'GLOBAL' THEN
                            UPDATE AUD_MAIN
                            SET DIRECTOR_ID = directors(i2).director_id
                            WHERE MAIN_ID = i.MAIN_ID;
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;

            END;
        END LOOP;

        COMMIT;
    END IF;
END update_director_all ;

PROCEDURE update_director_all (
    p_year IN NUMBER,
    p_quarter IN VARCHAR2,
    p_type_id IN NUMBER,
    p_type_id_global IN NUMBER,
    p_user_name IN VARCHAR2
)
AS

    -- Result flag
    res NUMBER;

    -- Define a record type for region-director pairs
    TYPE region_director_rec IS RECORD (
        region       VARCHAR2(100),
        director_id  NUMBER
    );

    -- Define an index-by associative array for user-level director mappings
    TYPE region_director_arr IS TABLE OF region_director_rec INDEX BY PLS_INTEGER;

    -- Cursor taking only user_name as input
    CURSOR c1(p_user_name VARCHAR2) IS
           SELECT 
       
        COALESCE(
            d1_reg.DIRECTOR_ID,
            d1_global.DIRECTOR_ID,
            d2_reg.DIRECTOR_ID,
            d2_global.DIRECTOR_ID
        ) AS DIRECTOR_ID,
        COALESCE(
            d1_reg.LOC,
            d1_global.LOC,
            d2_reg.LOC,
            d2_global.LOC
        ) AS DIRECTOR_REGION
    FROM (
        SELECT DISTINCT 
            USER_NAME, 
            NVL(REGION, 'GLOBAL') AS REGION
        FROM AUD_MAIN
        WHERE FINANCIAL_YEAR = P_year
          AND QUARTER = P_quarter
          AND TYPE_ID = P_type_id
          and USER_NAME = p_user_name
    ) u
    LEFT JOIN AUD_DIRECTOR_MAP d1_reg
        ON u.USER_NAME = d1_reg.USER_NAME
       AND d1_reg.TYPE_ID = P_type_id
       AND d1_reg.LOC = u.REGION
    LEFT JOIN AUD_DIRECTOR_MAP d1_global
        ON u.USER_NAME = d1_global.USER_NAME
       AND d1_global.TYPE_ID = P_type_id
       AND d1_global.LOC = 'GLOBAL'
    LEFT JOIN AUD_DIRECTOR_MAP d2_reg
        ON u.USER_NAME = d2_reg.USER_NAME
       AND d2_reg.TYPE_ID = P_type_id_global
       AND d2_reg.LOC = u.REGION
    LEFT JOIN AUD_DIRECTOR_MAP d2_global
        ON u.USER_NAME = d2_global.USER_NAME
       AND d2_global.TYPE_ID = P_type_id_global
       AND d2_global.LOC = 'GLOBAL' ;

BEGIN
    -- Check if relevant rows exist
    SELECT MAX(1)
    INTO res
    FROM AUD_MAIN
    WHERE FINANCIAL_YEAR = p_year
      AND QUARTER = p_quarter
      AND TYPE_ID = p_type_id;

    IF res = 1 THEN
        -- Outer loop for each record in AUD_MAIN
        FOR i IN (
            SELECT MAIN_ID, USER_NAME, NVL(REGION, 'GLOBAL') AS REGION 
            FROM AUD_MAIN 
            WHERE FINANCIAL_YEAR = p_year
              AND QUARTER = p_quarter
              AND TYPE_ID = p_type_id
              and USER_NAME = p_user_name
        ) LOOP
            -- Create an associative array for j output
            DECLARE
                directors region_director_arr;
                idx PLS_INTEGER := 0;
                matched BOOLEAN := FALSE;
            BEGIN
                -- Collect all region-director pairs into the array
                FOR j IN c1(i.USER_NAME) LOOP
                    idx := idx + 1;
                    directors(idx).region := NVL(j.DIRECTOR_REGION, 'GLOBAL');
                    directors(idx).director_id := j.DIRECTOR_ID;
                END LOOP;

                -- Loop through array to match region exactly
                FOR i2 IN directors.FIRST .. directors.LAST LOOP
                    IF directors(i2).region = i.REGION THEN
                        UPDATE AUD_MAIN
                        SET DIRECTOR_ID = directors(i2).director_id
                        WHERE MAIN_ID = i.MAIN_ID;
                        matched := TRUE;
                        EXIT;
                    END IF;
                END LOOP;

                -- If not matched by region, try GLOBAL fallback
                IF NOT matched THEN
                    FOR i2 IN directors.FIRST .. directors.LAST LOOP
                        IF directors(i2).region = 'GLOBAL' THEN
                            UPDATE AUD_MAIN
                            SET DIRECTOR_ID = directors(i2).director_id
                            WHERE MAIN_ID = i.MAIN_ID;
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;

            END;
        END LOOP;

        COMMIT;
    END IF;
END update_director_all ;

-- procedure update_director_all (
--     p_year in number  , 
--     p_quarter in varchar2,
--     p_type_id in number ,
--     p_type_id_global in number 
-- ) 
-- as

-- res number ; 
-- BEGIN
-- select max(1) into res from AUD_MAIN where
--     FINANCIAL_YEAR = p_year
--     AND QUARTER = p_quarter
--     AND TYPE_ID = p_type_id;

-- if res = 1 then 

-- MERGE INTO AUD_MAIN am
-- USING (
--     SELECT 
--         u.USER_NAME,
--         COALESCE(
--             d1_reg.DIRECTOR_ID,
--             d1_global.DIRECTOR_ID,
--             d2_reg.DIRECTOR_ID,
--             d2_global.DIRECTOR_ID
--         ) AS DIRECTOR_ID,
--         COALESCE(
--             d1_reg.LOC,
--             d1_global.LOC,
--             d2_reg.LOC,
--             d2_global.LOC
--         ) AS DIRECTOR_REGION
--     FROM (
--         SELECT DISTINCT 
--             USER_NAME, 
--             NVL(REGION, 'GLOBAL') AS REGION
--         FROM AUD_MAIN
--         WHERE FINANCIAL_YEAR = P_year
--           AND QUARTER = P_quarter
--           AND TYPE_ID = P_type_id
--     ) u
--     LEFT JOIN AUD_DIRECTOR_MAP d1_reg
--         ON u.USER_NAME = d1_reg.USER_NAME
--        AND d1_reg.TYPE_ID = P_type_id
--        AND d1_reg.LOC = u.REGION
--     LEFT JOIN AUD_DIRECTOR_MAP d1_global
--         ON u.USER_NAME = d1_global.USER_NAME
--        AND d1_global.TYPE_ID = P_type_id
--        AND d1_global.LOC = 'GLOBAL'
--     LEFT JOIN AUD_DIRECTOR_MAP d2_reg
--         ON u.USER_NAME = d2_reg.USER_NAME
--        AND d2_reg.TYPE_ID = P_type_id_global
--        AND d2_reg.LOC = u.REGION
--     LEFT JOIN AUD_DIRECTOR_MAP d2_global
--         ON u.USER_NAME = d2_global.USER_NAME
--        AND d2_global.TYPE_ID = P_type_id_global
--        AND d2_global.LOC = 'GLOBAL'
-- ) dm
-- ON (
--     am.USER_NAME = dm.USER_NAME
--     AND am.FINANCIAL_YEAR = P_year
--     AND am.QUARTER = P_quarter
--     AND am.TYPE_ID = P_type_id
--     AND NVL(am.REGION, 'GLOBAL') = dm.DIRECTOR_REGION
-- )
-- WHEN MATCHED THEN
--     UPDATE SET 
--         am.DIRECTOR_ID = dm.DIRECTOR_ID;


-- COMMIT;
-- end if ; 

-- END update_director_all;

procedure map_new_user_update_director_all (
    p_year in number  , 
    p_quarter in varchar2,
    p_type_id in number ,
    p_type_id_global in number 
) 
as
    TYPE user_table IS TABLE OF AUD_MAIN.USER_NAME%TYPE;
    l_user_names user_table;
BEGIN
    
    SELECT DISTINCT am.USER_NAME
    BULK COLLECT INTO l_user_names
    FROM AUD_MAIN am
    WHERE NOT EXISTS (
        SELECT 1 
        FROM AUD_DIRECTOR_MAP a 
        WHERE a.TYPE_ID = p_type_id_global 
          AND a.USER_NAME = am.USER_NAME
    )
    AND am.FINANCIAL_YEAR = p_year
    AND am.QUARTER = p_quarter
    AND am.TYPE_ID = p_type_id;
    
   
    
    IF l_user_names.COUNT > 0 THEN
       
        FOR i IN l_user_names.FIRST .. l_user_names.LAST LOOP
           
            INSERT INTO AUD_DIRECTOR_MAP (USER_NAME, DIRECTOR_ID, DIRECTOR_AUTOMATION_ID)
            VALUES (
            l_user_names(i), 
            -1, 
            AUD_PKG.get_director_id(l_user_names(i))
            );
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No users found.');
    END IF;

AUD_PKG.update_director_all(  p_year  , 
    p_quarter,
    p_type_id  ,
    p_type_id_global  );

END map_new_user_update_director_all;

function is_reset_director (
    p_year in number  , 
    p_quarter in varchar2 , 
    p_type_id in number
) return char is

res number;

begin 
if p_year is null or p_quarter is null or p_type_id is null then 
return 'N' ; 
end if ; 
select max(1) into res from AUD_MAIN where
    FINANCIAL_YEAR = p_year
    AND QUARTER = p_quarter
    AND TYPE_ID = p_type_id;
return case res when 1 then 'Y' else 'N' end;    

end is_reset_director ;


PROCEDURE AUD_INSERT(
  p_file_name IN VARCHAR2
)
IS
    
    p_type_id   NUMBER;
    p_year      NUMBER;
    p_quarter   VARCHAR2(32);
    is_quarter number := 0 ; 
    p_status VARCHAR2(32); 
    p_system varchar2(32); 

    l_sheet_json   JSON_OBJECT_T;
    l_row_json     JSON_OBJECT_T;
    l_data_array   JSON_ARRAY_T;

    p_count number ; 
    
    CURSOR c_para IS
        SELECT 
            p.col001, p.col002, p.col003, p.col004,
            p.col005, p.col006, p.col007, p.col008
        FROM apex_application_temp_files f,
             TABLE(apex_data_parser.parse(
                 p_content      => f.blob_content,
                 p_file_name    => f.filename,
                 p_file_profile => apex_data_loading.get_file_profile(p_static_id => 'Load_Data'),
                 p_max_rows     => 1
             )) p
        WHERE f.name = p_file_name AND p.line_number = 1;

    CURSOR c_data IS
        SELECT 
            p.col001, p.col002, p.col003,p.col004,p.col005,p.col006,p.col007,p.col008
        FROM apex_application_temp_files f,
             TABLE(apex_data_parser.parse(
                 p_content      => f.blob_content,
                 p_file_name    => f.filename,
                 p_file_profile => apex_data_loading.get_file_profile(p_static_id => 'Load_Data'),
                 p_max_rows     => 21000
             )) p
        WHERE f.name = p_file_name AND p.line_number > 3;
---1048576 excel limit (need test)
BEGIN
    -- Extract metadata from header row
    FOR i IN c_para LOOP
        p_system := upper(i.col008) ; 
        -- Validate required fields
        IF i.col002 IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Year cannot be NULL.');
        END IF;
        p_year    := trim(i.col002);

        IF i.col005 IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Quarter cannot be NULL.');
        END IF;
        IF i.col008 IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'System cannot be NULL.');
        END IF;

        
        -- Validate quarter (Q1, Q2, Q3, Q4)
    p_quarter := TRIM(i.col005);
    SELECT COUNT(*)
    INTO is_quarter
    FROM AUD_YEAR_QUARTER_TRACKER
    WHERE QUARTER = p_quarter AND YEAR = i.col002;

  IF is_quarter = 0 THEN
    RAISE_APPLICATION_ERROR(-20005, 'Quarter not available.');
  END IF;

        select status into p_status from AUD_YEAR_QUARTER_TRACKER where year = p_year and upper(quarter) = upper(p_quarter); 
        if p_status != 'WIP' then 
                        RAISE_APPLICATION_ERROR(-20005, 'Status of Year: '||p_year||'and Quarter: '||p_quarter||'is not WIP');
        end if ; 
        -- Validate type name
        BEGIN
            SELECT type_id
            INTO p_type_id
            FROM aud_type
            WHERE type_name = TRIM(i.col008);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20006, 'Invalid System : ' || i.col008);
        END;
    END LOOP;

    -- Clean up existing data (Removing this as at a time user can upload max 20k row and adding one restore button to report screen for admin to delete complete data for selected system and quarter)

    -- DELETE FROM aud_main
    -- WHERE quarter = p_quarter
    --   AND financial_year = p_year
    --   AND type_id = p_type_id;

    -- Insert data rows
    if p_system = 'BANK' then 
      



FOR row_rec IN (SELECT *
        FROM apex_application_temp_files f,
             TABLE(apex_data_parser.parse(
                 p_content      => f.blob_content,
                 p_file_name    => f.filename,
                 p_file_profile => apex_data_loading.get_file_profile(p_static_id => 'Load_Data'),
                 p_max_rows     => 21000
             )) p
        WHERE f.name = p_file_name AND p.line_number > 3) LOOP
            


           
             l_row_json := new JSON_OBJECT_T;
           

             l_row_json.put('BNP PAYROLL / FRORACLE02', row_rec.col003); 
             l_row_json.put('B1_Status', row_rec.col004); 
             l_row_json.put('BofA / Payroll', row_rec.col005); 
             l_row_json.put('B2_Status', row_rec.col006); 
             l_row_json.put('JPM / ORACLEPAY', row_rec.col007); 
             l_row_json.put('B3_Status', row_rec.col008); 
             l_row_json.put('Citi / Payroll', row_rec.col009); 
             l_row_json.put('B4_Status', row_rec.col010); 
            
           
            
            -- Convert JSON to CLOB
    DECLARE
        l_bank_clob CLOB;
    BEGIN
        l_bank_clob := l_row_json.to_clob();

        INSERT INTO aud_main (
            type_id, financial_year, quarter, 
            user_name, role, bank, director_id
        )
        VALUES (
            p_type_id, p_year, p_quarter, 
            UPPER(trim(row_rec.col001)), trim(row_rec.col002), l_bank_clob, -1
        );
    END;
         
            
        END LOOP;

 

      
       
    

    
 
    else 
        FOR i IN c_data LOOP
            INSERT INTO aud_main (
                type_id, financial_year, quarter,
                user_name, application_name, role,COUNTRY,GENERIC_EMAIL,REGION,DETAILDATA,SCOPENAME,director_id
            )
            VALUES (
                p_type_id, p_year, p_quarter,
                UPPER(trim(i.col001)), trim(i.col002), trim(i.col003),trim(i.col004),trim(i.col005),trim(i.col006),trim(i.col007),trim(i.col008), -1
            );

         

        END LOOP; 
    end if ; 
    -- Update director if data is valid
    IF p_year IS NOT NULL AND p_quarter IS NOT NULL AND p_type_id IS NOT NULL THEN
        aud_pkg.map_new_user_update_director_all(
            p_year, p_quarter, p_type_id, 0
        );
    END IF;
END AUD_INSERT;

procedure BUILD_EMAIL(p_to in varchar2,
  p_app_id in varchar2,
  p_app_name in varchar2,
  p_year in number,
  p_quarter in varchar2,
  p_title in varchar2,
  p_text in varchar2
  )
is 
 
v_mail_template varchar2(32767 char);
v_out_body_html varchar2(32767 char);
v_app_url varchar2(32767 char);
begin 
 wwv_flow_api.set_security_group_id;
-- Get the correct template 
select text into v_mail_template from PT_TEXTS_V where TEXT_TYPE = 'EMAIL_TEMPLATE' and LANG = 'en';




      
v_app_url :=  apex_util.prepare_url(
      pcg.app_url(c_application_id)||':'||2||':'||v('APP_SESSION')||'::::P2_YEAR,P2_QUARTER:'|| p_year || ',' || p_quarter
    , p_checksum_type =>'SESSION'
    );
  v_out_body_html:= replace(replace(replace(replace(replace(replace(replace(v_mail_template
    ,'#NAME#',  p_app_name)
    ,'#TITLE#', p_title)
    ,'#YEAR#', to_char(sysdate,'YYYY'))
    ,'#TEXT#', p_text)
    ,'#APP_URL#', v_app_url)
    ,'#BUTTON_START#', case when trim(p_app_id) is null then ' <!-- ' else ' ' end)
    ,'#BUTTON_END#', case when trim(p_app_id) is null then ' --> ' else ' ' end);

 APEX_MAIL.SEND(lower(p_to),'noreply@oracle.com',null/*v_out_body_txt*/,v_out_body_html, p_app_name||' - '||p_title);
end BUILD_EMAIL; 

end "AUD_PKG";
/