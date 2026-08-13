create or replace package body GPAT_pkg as
/* Global Payroll Approval Template (GPAT) package
Created: 2018.01.03
Developer: marek.szwarczewski@oracle.com
Modifications:
2018.01.03 - 1.0 - Marek Szwarczewski - initial version
2018.01.30 - 1.1 - Marek Szwarczewski - added 'send_email_notification' procedure and 'get_names' function
2018.02.21 - 1.2 - Marek Szwarczewski - bug fix
2018.03.23 - 1.3 - Marek Szwarczewski - added function 'check_pay_vs_net'
2018.03.29 - 1.4 - Marek Szwarczewski - adjustments to function 'check_pay_vs_net'
2018.04.11 - 1.5 - Marek Szwarczewski - added function 'my_html_strip'
2018.04.25 - 1.6 - Marek Szwarczewski - updated function 'my_html_strip' - added replacement &#39; => '
2018.05.11 - 1.7 - Marek Szwarczewski - updated function 'my_html_strip' - added replacement &amp; => &
2022.10.26 - 1.8 - Bhuvi Chauhan	  - fix for SR #63738, changes made in send_email_notification
2023.07.27 - 1.9 - Bhuvi Chauhan      - updated send_email_notification procedure added p_gpat_or_gpt,p_gpt_batch_id,p_gpt_batch_source for GPT Enhancement
2023.08.14 - 2.0 - Bhuvi Chauhan      - updated the link creation code for GPAT used the P_PLAI_URL parameter for GPAT also to overcome that javascrip link. SR#84961, Also included versions in the modifications history.
2025.04.22 - 2.1 - Bhuvi Chauhan      - For gpt source manual, corrected the enitiy,country allocation to the variables. 
2025.06.25 - 2.2 - Bhuvi Chauhan - Made changes in the GPT Email body, added pay date, batch amount and batch name.
2026.07.08 - 2.2 - Pragya Kapoor 	  - modify INIT_TAX_CALENDAR to run between from & to month of given year, region and country

*/

c_version constant varchar2(5 char) := '2.2';

procedure send_email_notification( p_gpat_id     number
                                 , p_req_action  varchar2
                                 , p_send_to     varchar2
                                 , p_send_cc     varchar2 default null
                                 , p_send_bcc    varchar2 default 'marek.szwarczewski@oracle.com'
                                 , p_comment     varchar2 default null
                                 , p_gpat_or_gpt varchar2 default 'gpat'
                                 , p_gpt_batch_id number  default null
                                 , p_gpt_batch_source varchar2 default null
                                 ) as
/** It sends email notification.
2018.01.30 - 1.0 - Marek Szwarczewski - create
2025.04.22 - 1.1 - Bhuvi Chauhan - For gpt source manual, corrected the enitiy,country allocation to the variables. 
2025.06.25 - 1.2 - Bhuvi Chauhan - Made changes in the GPT Email body, added pay date, batch amount and batch name.
*/
   c_body_txt       CLOB ;
   c_body_html      CLOB ;
   c_html_template  CLOB ;
   c_boiler_plate   CLOB ;
   c_table          CLOB ;
   v_subject        varchar2(256) ;
   v_entity         varchar2(256) ;
   v_country        varchar2(256) ;
   v_pay_date       varchar2(256) ;
   v_batch_amount   varchar2(100);
   v_batch_name     varchar2(512);
   v_link           varchar2(512) ;

BEGIN

 IF p_gpat_or_gpt = 'gpt' THEN
    
    SELECT headline, TO_CHAR(batch_amount, '999G999G999G999G990D00') into v_batch_name, v_batch_amount from gpt_batch where id = p_gpt_batch_id;
    select to_char(min(pay_date),'DD-MON-YYYY') into v_pay_date from gpt_pay_elements_value where gpt_batch_id = p_gpt_batch_id;

    CASE 
     WHEN p_gpt_batch_source = 'G' THEN

   -- Pay date as text, Country name and Entity name
   SELECT e.COUNTRY , e.ENTITY --, to_char( g.PAY_DATE, 'DD-MON-YYYY' )
     INTO v_country , v_entity --, v_pay_date
     FROM GPAT_MAIN g
        , MD_ENTITIES_V e
       WHERE g.ID_GPAT    = p_gpat_id
       AND e.ID_ENTITY  = g.ENTITY_ID ;

     WHEN p_gpt_batch_source = 'M' THEN

      SELECT mev.entity, mev.country--, to_char(gb.BATCH_PAYMENT_DATE, 'DD-MON-YYYY' )
        INTO v_entity, v_country --, v_pay_date -- made the fix here on 22 april 2025 by bhuvi entity was going into country and vice-versa 
      FROM gpt_batch gb, md_entities_v mev
       WHERE gb.id = p_gpt_batch_id
       AND gb.country_id = mev.country_id
       AND gb.entity_id = mev.id_entity;

    END CASE;

 ELSE

  -- Pay date as text, Country name and Entity name
   SELECT e.COUNTRY , e.ENTITY , to_char( g.PAY_DATE, 'DD-MON-YYYY' )
     INTO v_country , v_entity , v_pay_date
     FROM GPAT_MAIN g
        , MD_ENTITIES_V e
       WHERE g.ID_GPAT    = p_gpat_id
       AND e.ID_ENTITY  = g.ENTITY_ID ; 

 END IF; 

   -- Link 
   -- #63738 - In replace function we corrected it as earlier that javascript thing was not getting replaced by the link f?p which we added later, before there was nothing to replaced with that js thing.
	
 IF p_gpat_or_gpt = 'gpt' THEN    

    CASE 
     WHEN p_gpt_batch_source = 'G' THEN

      v_link := APEX_UTIL.PREPARE_URL(
        p_url => (case when p_gpat_or_gpt = 'gpt' then 'f?p=' || v('APP_ID') || ':320:::NO:RP,320:P320_GPAT_ID,P320_GPT_BATCH_ID,P320_COND_ITEM:'end)|| p_gpat_id||','|| p_gpt_batch_id||','||p_req_action,
        p_checksum_type => 'PUBLIC_BOOKMARK',
		p_plain_url => TRUE) ;

     WHEN p_gpt_batch_source = 'M' THEN

      v_link := APEX_UTIL.PREPARE_URL(
        p_url => (case when p_gpat_or_gpt = 'gpt' then 'f?p=' || v('APP_ID') || ':320:::NO:RP,320:P320_GPT_BATCH_ID,P320_COND_ITEM:'end)||p_gpt_batch_id||','||p_req_action,
        p_checksum_type => 'PUBLIC_BOOKMARK',
		p_plain_url => TRUE) ;

    END CASE;  

  ELSE

     v_link := APEX_UTIL.PREPARE_URL(
        p_url => 'f?p=' || v('APP_ID') || ':40:::NO:RP,40:P40_GPAT_ID:' || p_gpat_id ,
        p_checksum_type => 'PUBLIC_BOOKMARK',
        p_plain_url => TRUE) ; 

  END IF;

   if ( c_Dev_Workspace_Name = c_Workspace_Name and c_Dev_Application_ID = c_Application_ID )
      then 
      bhu_logs(1,'in 1st if','clob1');
      select c_Dev_URL_Base||v_link
	  into v_link
	  from dual ;
      bhu_logs(11,'in 11th if v_link '||v_link,'clob11');
   end if ;
   if ( c_Prod_Workspace_Name = c_Workspace_Name and c_Prod_Application_ID = c_Application_ID )
      then 
      bhu_logs(2,'in 2nd if','clob2');
      select c_Prod_URL_Base||v_link
	  into v_link
	  from dual ;
	--   select replace (v_link, 'javascript:apex.navigation.dialog.close(true,atob(''', c_Prod_URL_Base||'f?p=' || v('APP_ID') ||':40:::NO:RP,40:P40_GPAT_ID:'||p_gpat_id||'&cs=') 
	--   into v_link 
	--   from dual ;
      bhu_logs(22,'in 22nd if v_link '||v_link,'clob22');
   end if ;
      
   select replace (v_link, '''));', '' ) into v_link from dual ;
   if p_gpat_or_gpt = 'gpt' then
   v_link :=  '<a href="' || v_link || '">Click this link to see the GPT</a>' ;
   else 
   v_link :=  '<a href="' || v_link || '">Click this link to see the GPAT</a>' ;
   end if;

   --====================================
   -- Deppending to the performed action
   if p_req_action = 'Submitted'
   then
      -- Subject of the email
      v_subject := (case when p_gpat_or_gpt = 'gpt' then 'GPT for ' else 'GPAT for ' end)|| v_entity || ' is awaiting the reviewal or approval.' ;
   
      -- Creating beginning of the email body in text 
      c_body_txt := (case when p_gpat_or_gpt = 'gpt' then 'There is a new GPT for ' else 'There is a new GPAT for ' end) 
                    || v_entity || ' awaiting your reviewal or approval. ' || utl_tcp.crlf || utl_tcp.crlf ;
   
      -- Standart text to include (boiler plate)
      SELECT (case when p_gpat_or_gpt = 'gpt' then replace(PARAM_TEXT,'GPAT','GPT') else PARAM_TEXT end) INTO c_boiler_plate
        FROM GPAT_PARAMETERS
       WHERE PARAM_NAME  = 'BODY_SUBMIT' ;

--added by bhuvi for status REVIEWED start

   elsif p_req_action = 'Reviewed'
   then
      -- Subject of the email
      v_subject := (case when p_gpat_or_gpt = 'gpt' then 'GPT for ' else 'GPAT for ' end) || v_entity || ' has been reviewed.' ;
   
      -- Creating beginning of the email body in text 
      c_body_txt := (case when p_gpat_or_gpt = 'gpt' then 'The GPT for ' else 'The GPAT for ' end) || v_entity || ' has been reviewed. ' || utl_tcp.crlf || utl_tcp.crlf ;
   
      -- Standart text to include (boiler plate)
      SELECT (case when p_gpat_or_gpt = 'gpt' then replace(PARAM_TEXT,'GPAT','GPT') else PARAM_TEXT end) INTO c_boiler_plate
        FROM GPAT_PARAMETERS
       WHERE PARAM_NAME  = 'BODY_REVIEW' ; 

----added by bhuvi for status REVIEWED end

   elsif p_req_action = 'Approved'
   then
      -- Subject of the email
      v_subject := (case when p_gpat_or_gpt = 'gpt' then 'GPT for ' else 'GPAT for ' end) || v_entity || ' has been approved.' ;
   
      -- Creating beginning of the email body in text 
      c_body_txt := (case when p_gpat_or_gpt = 'gpt' then 'The GPT for ' else 'The GPAT for ' end) || v_entity || ' has been approved. ' || utl_tcp.crlf || utl_tcp.crlf ;
   
      -- Standart text to include (boiler plate)
      SELECT (case when p_gpat_or_gpt = 'gpt' then replace(PARAM_TEXT,'GPAT','GPT') else PARAM_TEXT end) INTO c_boiler_plate
        FROM GPAT_PARAMETERS
       WHERE PARAM_NAME  = 'BODY_APPROVE' ;
   elsif p_req_action = 'Rejected'
   then
      -- Subject of the email
      v_subject := (case when p_gpat_or_gpt = 'gpt' then 'GPT for ' else 'GPAT for ' end) || v_entity || ' has been rejected.' ;
   
      -- Creating beginning of the email body in text 
      c_body_txt := (case when p_gpat_or_gpt = 'gpt' then 'The GPT for ' else 'The GPAT for ' end) || v_entity || ' has been rejected. ' || utl_tcp.crlf || utl_tcp.crlf ;
   
      -- Standart text to include (boiler plate)
      SELECT (case when p_gpat_or_gpt = 'gpt' then replace(PARAM_TEXT,'GPAT','GPT') else PARAM_TEXT end) INTO c_boiler_plate
        FROM GPAT_PARAMETERS
       WHERE PARAM_NAME  = 'BODY_REJECT' ;
   elsif p_req_action = 'Withdrawn'
   then
      -- Subject of the email
      v_subject := (case when p_gpat_or_gpt = 'gpt' then 'GPT approval for ' else 'GPAT approval for ' end) || v_entity || ' has been withdrawn.' ;
   
      -- Creating beginning of the email body in text 
      
      c_body_txt := (case when p_gpat_or_gpt = 'gpt' then 'Manager has withdrawn GPT approval for ' else 'Manager has withdrawn GPAT approval for ' end)
                     || v_entity || ' . '  || utl_tcp.crlf || utl_tcp.crlf ;
   
      -- Standart text to include (boiler plate)
      SELECT (case when p_gpat_or_gpt = 'gpt' then replace(PARAM_TEXT,'GPAT','GPT') else PARAM_TEXT end) INTO c_boiler_plate
        FROM GPAT_PARAMETERS
       WHERE PARAM_NAME  = 'BODY_WITHDRAW' ;
   end if;

   --====================================
   -- Continue creation of the email body in text 
      c_body_txt:=c_body_txt || (case when p_gpat_or_gpt = 'gpt' then 'The GPT has the following details:' else 'The GPAT has the following details:' end)         || utl_tcp.crlf;
      c_body_txt:=c_body_txt || 'Country: '                   || v_country     || utl_tcp.crlf;
      c_body_txt:=c_body_txt || 'Entity: '                    || v_entity      || utl_tcp.crlf;
      c_body_txt:=c_body_txt || 'Pay date: '                  || v_pay_date    || utl_tcp.crlf    || utl_tcp.crlf;
      c_body_txt:=c_body_txt || 'Payroll analysts comments: ' || p_comment     || utl_tcp.crlf    || utl_tcp.crlf;
      c_body_txt:=c_body_txt || 'Link: '                      || v_link        || utl_tcp.crlf    || utl_tcp.crlf;
      c_body_txt:=c_body_txt || 'Kind regards'                || utl_tcp.crlf  || 'APEX GPAT Tool' ;
   
   
   -- Creating email body as HTML
   -- Table with general GPAT informations

    case when p_gpat_or_gpt = 'gpat' then

        c_table:= '<table border="2" cellpadding="2" cellspacing="2" width="98%">' ;
            c_table:=c_table || '<tr><th>Key         </th>    <th>         Value               </th>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Country     </td>    <td><b>'  || v_country   || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Entity      </td>    <td><b>'  || v_entity    || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Pay date    </td>    <td><b>'  || v_pay_date  || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Link        </td>    <td>'     || v_link      ||     '</td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '</table>' ;

         when p_gpat_or_gpt = 'gpt' then 

        c_table:= '<table border="2" cellpadding="2" cellspacing="2" width="98%">' ;
            c_table:=c_table || '<tr><th>Key         </th>    <th>         Value               </th>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Country     </td>    <td><b>'  || v_country   || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Entity      </td>    <td><b>'  || v_entity    || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Pay date    </td>    <td><b>'  || v_pay_date  || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Batch Amount </td>   <td><b>'  || v_batch_amount  || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Batch Name   </td>   <td><b>'  || v_batch_name  || '</b></td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '<tr><td>Link        </td>    <td>'     || v_link      ||     '</td>    </tr>' || utl_tcp.crlf ;
            c_table:=c_table || '</table>' ;   

    end case ;     
   
   -- Compose the html part for inserting into template
   c_body_html := c_boiler_plate || nvl( p_comment, '&nbsp;' ) || c_table ;
   
   -- Get HTML Template
   SELECT PARAM_CLOB INTO c_html_template
     FROM GPAT_PARAMETERS
    WHERE PARAM_NAME  = 'MAIL_TEMPLATE' ;
   
   -- Compose HTML message
   SELECT REPLACE (c_html_template, '<gpat:content_here></gpat:content_here>', c_body_html ) INTO c_body_html
     FROM dual ;
   
   -- Sending email
   apex_mail.send ( p_to        => replace( p_send_to, ':', ',')
                  , p_cc        => replace( p_send_cc, ':', ',')
                  , p_bcc       => replace( p_send_bcc, ':', ',')
                  , p_from      => v('APP_USER')
                  , p_subj      => v_subject
                  , p_body      => c_body_txt
                  , p_body_html => c_body_html ) ;

exception when others then
   raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
END send_email_notification;




-- Function returns true if the package is installed on the test environment.
function custom_test_auth (p_username in varchar2, p_password in varchar2) return boolean as
/** This function returns true if the package is installed on the test environment.
2017.04.28 - 1.0 - András Tóth - create
*/
begin
  return case when ( c_Dev_Workspace_Name = c_Workspace_Name and c_Dev_Application_ID = c_Application_ID ) then true else false end;
end custom_test_auth ;


-- Return First and last name extracted from email address.
function get_names(p_email_address in varchar2) return varchar2 as
begin
   return initcap( replace( replace( UPPER(p_email_address), '@ORACLE.COM', '') , '.', ' ') ) ;

EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
end get_names ;


/** Function strip out the html tags, CR, LF and replace them by space. Then trim consequent spaces.
2018.04.25 - Marek Szwarczewski - added replacement &#39; => '
2018.05.11 - Marek Szwarczewski - added replacement &amp; => &
*/
function my_html_strip(p_input_text in varchar2) return varchar2 as
   v_text    varchar2(4000) ;

begin
   v_text := regexp_replace( p_input_text, '&#39;' , '''') ;
   v_text := regexp_replace( v_text, '&amp;' , '&') ;
   return trim( regexp_replace( regexp_replace( v_text, '<.*?>|&#[0-9]{2,4};|&[a-z]{3,4};|[' || chr(9) || '|' || chr(10) || '|' || chr(11) || '|' || chr(13) || ']+', ' '), ' +' , ' ') ) ;
end my_html_strip ;


-- Function checks if amounts to pay by Bank and Cheques are equal to the Net amount.
function check_pay_vs_net( p_gpat_id         number
                         , p_bank_transfer   number default null
                         , p_paycheck        number default null
                         ) return            varchar2 as
/** This function checks if amount to pay by Bank and Cheques is equal to the calculated Net amount.
2018.03.23 - 1.0 - Marek Szwarczewski - create
2018.03.29 - 1.1 - Marek Szwarczewski - adjustments
*/
   v_to_pay     number ;
   v_net_val    number ;

begin

   IF p_gpat_id IS NULL
   THEN
      return '-' ;
   ELSE
      WITH new_subc_v  AS (SELECT n.id_gpat
                                , ne.category_id AS subcategory_id
                                , c.to_net
                                , SUM(ne.AMOUNT) AS NEW_SUBC_VALUE
                             FROM gpat_main n
                                , gpat_elements_value ne
                                , gpat_category_dictionary c
                            WHERE n.ID_GPAT         = p_gpat_id
                              AND ne.GPAT_ID        = n.ID_GPAT
                              AND c.id_category     = ne.category_id
                            GROUP BY n.id_gpat
                                   , ne.category_id
                                   , c.to_net
                          )
         SELECT new_cat_v.NEW_CAT_VALUE  INTO v_net_val
           FROM (SELECT n.id_gpat
                      , SUM( CASE n.TO_NET WHEN 'Plus'  THEN   n.NEW_SUBC_VALUE
                                           WHEN 'Minus' THEN - n.NEW_SUBC_VALUE END) AS NEW_CAT_VALUE
                   FROM new_subc_v n
                  GROUP BY n.id_gpat
                ) new_cat_v ;

      SELECT nvl( nvl(p_bank_transfer, BANK_TRANSFER), 0) + nvl( nvl(p_paycheck, PAYCHECKS), 0) INTO  v_to_pay
        FROM GPAT_MAIN
       WHERE ID_GPAT = p_gpat_id ;



      IF v_to_pay = v_net_val
      THEN
         return 'OK' ;
      ELSE
         return nvl('Pay - Net = ' || to_char( v_to_pay - v_net_val , '999G999G999G999G990D00') , 'NOT EQUAL!') ;
      END IF;
      
   END IF;
   
   
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         return 'GPAT has no elements' ;

end check_pay_vs_net ;

------------------------------------
PROCEDURE INIT_TAX_CALENDAR(V_YEAR VARCHAR2, V_FROM_MONTH NUMBER, V_TO_MONTH NUMBER, V_REGION VARCHAR2, V_COUNTRY VARCHAR2) IS
--2024.12.03 - 1.0 - Bhvui Chauhan 		-- create
--2026.07.08 - 1.1 - Pragya Kapoor 		-- modify it to run between from & to month of given year, region and country

  v_due_date       DATE;
  v_due_date_2     DATE; -- Second due date for semi-monthly events
  v_base_date      DATE;
  v_gpat_end_month DATE;
  v_next_year      NUMBER := V_YEAR;--EXTRACT(YEAR FROM SYSDATE);
  v_exists         NUMBER;  -- To check for duplicate rows
  v_start_date 	   DATE	:= TO_DATE(V_YEAR || '-' || V_FROM_MONTH ||  '-01', 'YYYY-MM-DD');
  v_end_date 	   DATE := LAST_DAY(TO_DATE(V_YEAR || '-' || V_TO_MONTH ||  '-01', 'YYYY-MM-DD'));
  -- Cursor to iterate over active due date config (GTC_DUEDATE_DICT) joined with GPT_PAY_ELEMENTS_DICTIONARY
  CURSOR due_date_cursor IS
    SELECT d.ID,
           d.DUEDATE_PERIOD,
           d.DATE_RELATED_TO_GPAT_OR_CAL,
           d.GPAT_PERIOD_LAST_MONTH,
           d.MONTH_DELAY,
           d.DAY_RELATION,
           d.MONTH_CONSTANT,
           d.DAY_CONSTANT,
           d.IF_DAY_OFF,
           e.PAYMENT_TYPE_ID,
           e.LEGAL_DUE_DATE_ID,
           e.COUNTRY_ID,
           e.ENTITY_ID,
           e.ID AS PAY_EL_ID 
    FROM GTC_DUEDATE_DICT d
    JOIN GPT_PAY_ELEMENTS_DICTIONARY e
      ON d.ID = e.LEGAL_DUE_DATE_ID
	INNER JOIN MD_COUNTRIES C ON C.id = E.COUNTRY_ID
	WHERE UPPER(region) = DECODE(UPPER(v_region), 'ALL', UPPER(region), UPPER(v_region)) --Filter the regions
    AND E.COUNTRY_ID = DECODE(V_COUNTRY, 'All', E.COUNTRY_ID , V_COUNTRY) --Filter the country
    AND d.STATUS = 'ACTIVE';  -- Only process active configurations
BEGIN
  bhu_logs(100001, 'V_YEAR: ' || V_YEAR || ' V_FROM_MONTH: ' || V_FROM_MONTH || ' V_TO_MONTH: ' || V_TO_MONTH || ' V_REGION: ' || V_REGION || ' V_COUNTRY: ' || V_COUNTRY , 'clob100001');
  FOR due_date_rec IN due_date_cursor LOOP

    ----------------------------------------------------------------------------
    -- GPAT-BASED DUE DATE CALCULATION (DATE_RELATED_TO_GPAT_OR_CAL = 'G')
    ----------------------------------------------------------------------------
    IF due_date_rec.DATE_RELATED_TO_GPAT_OR_CAL = 'G' THEN
      v_gpat_end_month := TO_DATE(v_next_year || '-' || due_date_rec.GPAT_PERIOD_LAST_MONTH || '-01', 'YYYY-MM-DD');
      v_base_date := ADD_MONTHS(v_gpat_end_month, NVL(due_date_rec.MONTH_DELAY, 0));

      -- For semi-monthly, we need two events per month.
      IF due_date_rec.DUEDATE_PERIOD = 0.5 THEN
        -- Iterate once per month (12 months)
        FOR i IN 0 .. 11 LOOP
          -- Calculate first due date: add month offset and any day relation, then set to the 15th.
          v_due_date := ADD_MONTHS(v_base_date, i) + NVL(due_date_rec.DAY_RELATION, 0);
          v_due_date := TRUNC(v_due_date, 'MM') + 14;  -- 15th day of the month
          bhu_logs(1001, 'v_due_date ' || v_due_date, 'clob1001');

          -- Calculate second due date: the last day of that month.
          v_due_date_2 := LAST_DAY(v_due_date);
          bhu_logs(1002, 'v_due_date_2 ' || v_due_date_2, 'clob1002');

		 --if due date is greater than to date then exit
		EXIT WHEN v_due_date > v_end_date;
		 --if due date is less than start date then skip that month
		CONTINUE WHEN v_due_date < v_start_date;
		
          -- Adjust the first due date for holidays/weekends.
          LOOP
            DECLARE
              v_holiday_count INTEGER;
            BEGIN
              SELECT COUNT(*) INTO v_holiday_count 
                FROM GTC_HOLIDAYS_DICT 
               WHERE HOLIDAY_DATE = v_due_date
                 AND COUNTRY_ID = due_date_rec.COUNTRY_ID;
              IF v_holiday_count > 0 OR TO_CHAR(v_due_date, 'D') IN ('7', '1') THEN
                IF due_date_rec.IF_DAY_OFF = 'F' THEN
                  v_due_date := v_due_date + 1;
                ELSE
                  v_due_date := v_due_date - 1;
                END IF;
              ELSE
                EXIT;
              END IF;
            END;
          END LOOP;
		  
		  -- Insert first semi-monthly due date (15th or adjusted) if not already inserted.
		  BEGIN
		  	SELECT COUNT(*) INTO v_exists FROM GTC_PAYMENTS
		  	WHERE PAYEE_ID       = due_date_rec.PAYMENT_TYPE_ID
		  	AND COUNTRY_ID     = due_date_rec.COUNTRY_ID
		  	AND ENTITY_ID      = due_date_rec.ENTITY_ID
		  	AND PAY_ELEMENT_ID = due_date_rec.PAY_EL_ID
		  	AND LEGAL_DUE_DATE = v_due_date
		  	AND LEGAL_DUE_DATE_ID = due_date_rec.ID
		  	AND IS_GPAT_SOURCE = 'Y';
		  	IF v_exists = 0 THEN
		  	INSERT INTO GTC_PAYMENTS (
		  		PAYEE_ID,
		  		COUNTRY_ID,
		  		ENTITY_ID,
		  		PAY_ELEMENT_ID,
		  		LEGAL_DUE_DATE,
		  		LEGAL_DUE_DATE_ID,
		  		IS_GPAT_SOURCE
		  	)
		  	VALUES (
		  		due_date_rec.PAYMENT_TYPE_ID,
		  		due_date_rec.COUNTRY_ID,
		  		due_date_rec.ENTITY_ID,
		  		due_date_rec.PAY_EL_ID,
		  		v_due_date,
		  		due_date_rec.ID,
		  		'Y'
		  	);
		  	END IF;
		  EXCEPTION
		  	WHEN OTHERS THEN
		  	NULL;  -- or log error if needed
		  END;
		  
          -- Adjust the second due date for holidays/weekends.
          LOOP
            DECLARE
              v_holiday_count INTEGER;
            BEGIN
              SELECT COUNT(*) INTO v_holiday_count 
                FROM GTC_HOLIDAYS_DICT 
               WHERE HOLIDAY_DATE = v_due_date_2
                 AND COUNTRY_ID = due_date_rec.COUNTRY_ID;
              IF v_holiday_count > 0 OR TO_CHAR(v_due_date_2, 'D') IN ('7', '1') THEN
                IF due_date_rec.IF_DAY_OFF = 'F' THEN
                  v_due_date_2 := v_due_date_2 + 1;
                ELSE
                  v_due_date_2 := v_due_date_2 - 1;
                END IF;
              ELSE
                EXIT;
              END IF;
            END;
          END LOOP;

		  -- Insert second semi-monthly due date (last day or adjusted) if not already inserted.
		  BEGIN
		  	SELECT COUNT(*) INTO v_exists FROM GTC_PAYMENTS
		  	WHERE PAYEE_ID       = due_date_rec.PAYMENT_TYPE_ID
		  	AND COUNTRY_ID     = due_date_rec.COUNTRY_ID
		  	AND ENTITY_ID      = due_date_rec.ENTITY_ID
		  	AND PAY_ELEMENT_ID = due_date_rec.PAY_EL_ID
		  	AND LEGAL_DUE_DATE = v_due_date_2
		  	AND LEGAL_DUE_DATE_ID = due_date_rec.ID
		  	AND IS_GPAT_SOURCE = 'Y';
		  	IF v_exists = 0 THEN
		  	INSERT INTO GTC_PAYMENTS (
		  		PAYEE_ID,
		  		COUNTRY_ID,
		  		ENTITY_ID,
		  		PAY_ELEMENT_ID,
		  		LEGAL_DUE_DATE,
		  		LEGAL_DUE_DATE_ID,
		  		IS_GPAT_SOURCE
		  	)
		  	VALUES (
		  		due_date_rec.PAYMENT_TYPE_ID,
		  		due_date_rec.COUNTRY_ID,
		  		due_date_rec.ENTITY_ID,
		  		due_date_rec.PAY_EL_ID,
		  		v_due_date_2,
		  		due_date_rec.ID,
		  		'Y'
		  	);
		  	END IF;
		  EXCEPTION
		  	WHEN OTHERS THEN
		  	NULL;  -- or log error if needed
		  END;
        END LOOP;

      ELSE
        -- Non-semi-monthly GPAT-based processing
        FOR i IN 0 .. (12 / due_date_rec.DUEDATE_PERIOD) - 1 LOOP
          v_due_date := ADD_MONTHS(v_base_date, i * due_date_rec.DUEDATE_PERIOD) 
                        + NVL(due_date_rec.DAY_RELATION, 0);
						
		--if due date is greater than to date then exit
		EXIT WHEN v_due_date > v_end_date;
		 --if due date is less than start date then skip that month
		CONTINUE WHEN v_due_date < v_start_date;
		
          LOOP
            DECLARE
              v_holiday_count INTEGER;
            BEGIN
              SELECT COUNT(*) INTO v_holiday_count 
                FROM GTC_HOLIDAYS_DICT 
               WHERE HOLIDAY_DATE = v_due_date
                 AND COUNTRY_ID = due_date_rec.COUNTRY_ID;
              IF v_holiday_count > 0 OR TO_CHAR(v_due_date, 'D') IN ('7', '1') THEN
                IF due_date_rec.IF_DAY_OFF = 'F' THEN
                  v_due_date := v_due_date + 1;
                ELSE
                  v_due_date := v_due_date - 1;
                END IF;
              ELSE
                EXIT;
              END IF;
            END;
          END LOOP;
		  
		  BEGIN
		  	SELECT COUNT(*) INTO v_exists FROM GTC_PAYMENTS
		  	WHERE PAYEE_ID       = due_date_rec.PAYMENT_TYPE_ID
		  	AND COUNTRY_ID     = due_date_rec.COUNTRY_ID
		  	AND ENTITY_ID      = due_date_rec.ENTITY_ID
		  	AND PAY_ELEMENT_ID = due_date_rec.PAY_EL_ID
		  	AND LEGAL_DUE_DATE = v_due_date
		  	AND LEGAL_DUE_DATE_ID = due_date_rec.ID
		  	AND IS_GPAT_SOURCE = 'Y';
		  	IF v_exists = 0 THEN
		  	INSERT INTO GTC_PAYMENTS (
		  		PAYEE_ID,
		  		COUNTRY_ID,
		  		ENTITY_ID,
		  		PAY_ELEMENT_ID,
		  		LEGAL_DUE_DATE,
		  		LEGAL_DUE_DATE_ID,
		  		IS_GPAT_SOURCE
		  	)
		  	VALUES (
		  		due_date_rec.PAYMENT_TYPE_ID,
		  		due_date_rec.COUNTRY_ID,
		  		due_date_rec.ENTITY_ID,
		  		due_date_rec.PAY_EL_ID,
		  		v_due_date,
		  		due_date_rec.ID,
		  		'Y'
		  	);
		  	END IF;
		  EXCEPTION
		  	WHEN OTHERS THEN
		  	NULL;
		  END;
        END LOOP;
      END IF;

    ----------------------------------------------------------------------------
    -- CALENDAR-BASED DUE DATE CALCULATION (DATE_RELATED_TO_GPAT_OR_CAL = 'C')
    ----------------------------------------------------------------------------
    ELSIF due_date_rec.DATE_RELATED_TO_GPAT_OR_CAL = 'C' THEN
      IF due_date_rec.DUEDATE_PERIOD = 0.5 THEN
        FOR i IN 1 .. 12 LOOP
          v_due_date := TO_DATE(v_next_year || '-' || due_date_rec.MONTH_CONSTANT || '-' || due_date_rec.DAY_CONSTANT, 'YYYY-MM-DD');
          v_due_date := ADD_MONTHS(v_due_date, i - 1);  -- shift base month
          v_due_date := TRUNC(v_due_date, 'MM') + 14;      -- 15th day
          v_due_date_2 := LAST_DAY(v_due_date);
          bhu_logs(101, 'v_due_date ' || v_due_date, 'clob101');
          bhu_logs(102, 'v_due_date_2 ' || v_due_date_2, 'clob102');
		  
   		  --if due date is greater than to date then exit
   		  EXIT WHEN v_due_date > v_end_date;
   		  --if due date is less than start date then skip that month
   		  CONTINUE WHEN v_due_date < v_start_date;

          LOOP
            DECLARE
              v_holiday_count INTEGER;
            BEGIN
              SELECT COUNT(*) INTO v_holiday_count 
                FROM GTC_HOLIDAYS_DICT 
               WHERE HOLIDAY_DATE = v_due_date
                 AND COUNTRY_ID = due_date_rec.COUNTRY_ID;
              bhu_logs(103, 'v_holiday_count ' || v_holiday_count, 'clob103');
              IF v_holiday_count > 0 OR TO_CHAR(v_due_date, 'D') IN ('7', '1') THEN
                IF due_date_rec.IF_DAY_OFF = 'F' THEN
                  v_due_date := v_due_date + 1;
                ELSE
                  v_due_date := v_due_date - 1;
                END IF;
              ELSE
                EXIT;
              END IF;
            END;
          END LOOP;

          BEGIN
            SELECT COUNT(*) INTO v_exists FROM GTC_PAYMENTS
             WHERE PAYEE_ID       = due_date_rec.PAYMENT_TYPE_ID
               AND COUNTRY_ID     = due_date_rec.COUNTRY_ID
               AND ENTITY_ID      = due_date_rec.ENTITY_ID
               AND PAY_ELEMENT_ID = due_date_rec.PAY_EL_ID
               AND LEGAL_DUE_DATE = v_due_date
               AND LEGAL_DUE_DATE_ID = due_date_rec.ID;
            IF v_exists = 0 THEN
              INSERT INTO GTC_PAYMENTS (
                PAYEE_ID,
                COUNTRY_ID,
                ENTITY_ID,
                PAY_ELEMENT_ID,
                LEGAL_DUE_DATE,
                LEGAL_DUE_DATE_ID
              )
              VALUES (
                due_date_rec.PAYMENT_TYPE_ID,
                due_date_rec.COUNTRY_ID,
                due_date_rec.ENTITY_ID,
                due_date_rec.PAY_EL_ID,
                v_due_date,
                due_date_rec.ID
              );
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;

          -- Adjust second due date for holidays/weekends.
          LOOP
            DECLARE
              v_holiday_count INTEGER;
            BEGIN
              SELECT COUNT(*) INTO v_holiday_count 
                FROM GTC_HOLIDAYS_DICT 
               WHERE HOLIDAY_DATE = v_due_date_2
                 AND COUNTRY_ID = due_date_rec.COUNTRY_ID;
              bhu_logs(104, 'v_holiday_count ' || v_holiday_count, 'clob104');
              IF v_holiday_count > 0 OR TO_CHAR(v_due_date_2, 'D') IN ('7', '1') THEN
                IF due_date_rec.IF_DAY_OFF = 'F' THEN
                  v_due_date_2 := v_due_date_2 + 1;
                ELSE
                  v_due_date_2 := v_due_date_2 - 1;
                END IF;
              ELSE
                EXIT;
              END IF;
            END;
          END LOOP;

          BEGIN
            SELECT COUNT(*) INTO v_exists FROM GTC_PAYMENTS
             WHERE PAYEE_ID       = due_date_rec.PAYMENT_TYPE_ID
               AND COUNTRY_ID     = due_date_rec.COUNTRY_ID
               AND ENTITY_ID      = due_date_rec.ENTITY_ID
               AND PAY_ELEMENT_ID = due_date_rec.PAY_EL_ID
               AND LEGAL_DUE_DATE = v_due_date_2
               AND LEGAL_DUE_DATE_ID = due_date_rec.ID;
            IF v_exists = 0 THEN
              INSERT INTO GTC_PAYMENTS (
                PAYEE_ID,
                COUNTRY_ID,
                ENTITY_ID,
                PAY_ELEMENT_ID,
                LEGAL_DUE_DATE,
                LEGAL_DUE_DATE_ID
              )
              VALUES (
                due_date_rec.PAYMENT_TYPE_ID,
                due_date_rec.COUNTRY_ID,
                due_date_rec.ENTITY_ID,
                due_date_rec.PAY_EL_ID,
                v_due_date_2,
                due_date_rec.ID
              );
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END LOOP;

      ELSE
        -- Non-semi-monthly Calendar-based processing
        DECLARE
          v_cal_base_date DATE;
        BEGIN
          v_cal_base_date := TO_DATE(v_next_year || '-' || due_date_rec.MONTH_CONSTANT || '-' || due_date_rec.DAY_CONSTANT, 'YYYY-MM-DD');
          FOR i IN 0 .. (12 / due_date_rec.DUEDATE_PERIOD) - 1 LOOP
          bhu_logs(101,'v_cal_base_date '||v_cal_base_date,'clob101');
            v_due_date := ADD_MONTHS(v_cal_base_date, i * due_date_rec.DUEDATE_PERIOD);
            bhu_logs(102,'v_cal_base_date '||v_cal_base_date,'clob102');
            bhu_logs(103,'v_due_date '||v_due_date,'clob103');
			
			
		    --if due date is greater than to date then exit
		    EXIT WHEN v_due_date > v_end_date;
			--if due date is less than start date then skip that month
			CONTINUE WHEN v_due_date < v_start_date;
        
			LOOP
              DECLARE
                v_holiday_count INTEGER;
              BEGIN
                SELECT COUNT(*) INTO v_holiday_count FROM GTC_HOLIDAYS_DICT
                 WHERE HOLIDAY_DATE = v_due_date
                   AND COUNTRY_ID = due_date_rec.COUNTRY_ID;
                IF v_holiday_count > 0 OR TO_CHAR(v_due_date, 'D') IN ('7', '1') THEN
                  IF due_date_rec.IF_DAY_OFF = 'F' THEN
                    v_due_date := v_due_date + 1;
                    bhu_logs(104,'v_due_date '||v_due_date,'clob104');
                  ELSE
                    v_due_date := v_due_date - 1;
                  END IF;
                ELSE
                  EXIT;
                END IF;
              END;
            END LOOP;
            BEGIN
              SELECT COUNT(*) INTO v_exists FROM GTC_PAYMENTS
               WHERE PAYEE_ID       = due_date_rec.PAYMENT_TYPE_ID
                 AND COUNTRY_ID     = due_date_rec.COUNTRY_ID
                 AND ENTITY_ID      = due_date_rec.ENTITY_ID
                 AND PAY_ELEMENT_ID = due_date_rec.PAY_EL_ID
                 AND LEGAL_DUE_DATE = v_due_date
                 AND LEGAL_DUE_DATE_ID = due_date_rec.ID;
              IF v_exists = 0 THEN
              bhu_logs(105,'v_due_date '||v_due_date,'clob105');
                INSERT INTO GTC_PAYMENTS (
                  PAYEE_ID,
                  COUNTRY_ID,
                  ENTITY_ID,
                  PAY_ELEMENT_ID,
                  LEGAL_DUE_DATE,
                  LEGAL_DUE_DATE_ID
                )
                VALUES (
                  due_date_rec.PAYMENT_TYPE_ID,
                  due_date_rec.COUNTRY_ID,
                  due_date_rec.ENTITY_ID,
                  due_date_rec.PAY_EL_ID,
                  v_due_date,
                  due_date_rec.ID
                );
                  bhu_logs(106,'v_due_date '||v_due_date,'clob106');
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
              bhu_logs(108,'v_due_date '||v_due_date,'clob108');
                NULL;
            END;
          END LOOP;
        END;
      END IF;
    END IF;  -- End of Calendar vs. GPAT check

  END LOOP;  -- End of cursor loop

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
  bhu_logs(109,'v_due_date '||v_due_date,'clob109');
    ROLLBACK;
    RAISE;
END INIT_TAX_CALENDAR;


------------------------------------------------

PROCEDURE UPLOAD_MANUAL_PAYMENT(
  p_file_name IN VARCHAR2
)
IS
  l_blob_content  BLOB;
  l_sheet_display_name VARCHAR2(500);
  l_sheet_file_name VARCHAR2(500);
  -- Variables to hold column values from the input sheet.
  -- Adjust these based on your Excel template’s column order.
  v_country_name        VARCHAR2(100);
  v_entity_name         VARCHAR2(100);
  v_payment_name        VARCHAR2(4000);
  v_payment_description VARCHAR2(4000);
  v_legal_due_date      DATE;
  v_pay_period          VARCHAR2(50);
  v_manual_amount       NUMBER;
  v_manual_amount_descr VARCHAR2(4000);
  v_prerequisites_recv    VARCHAR2(1); -- will store 'Y' or 'N'
  v_prerequisites_url   VARCHAR2(4000);
  v_pre_requisites_user VARCHAR2(100);
  v_pre_requisites_date DATE;
  
  -- Variables for lookup IDs
  v_country_id NUMBER;
  v_entity_id  NUMBER;

  --Capture the newly inserted ID from GTC_PAYMENTS
  v_gtc_payment_id NUMBER;

    -- Row counter to skip the first row (header)
  row_counter NUMBER := 0;
  
BEGIN
  -- Retrieve the file blob from the temporary files table.
  SELECT blob_content,sheet_display_name, sheet_file_name
    INTO l_blob_content, l_sheet_display_name, l_sheet_file_name
    FROM apex_application_temp_files f,
    TABLE(apex_data_parser.get_xlsx_worksheets(p_content => f.blob_content)) p
   WHERE name = p_file_name
   and rownum = 1;

bhu_logs(80,'gtc 0','clobgtc80');

  -- Process only the visible sheet, assumed here to be named 'INPUT'.
  -- If your visible sheet has a different name, change the p_xlsx_sheet_name accordingly.
  FOR row_rec IN (
      SELECT *
      FROM TABLE(
        apex_data_parser.parse(
          p_content         => l_blob_content,
          p_add_headers_row => 'Y',
          p_xlsx_sheet_name => l_sheet_file_name,
          p_max_rows        => 10000,
          p_file_name       => p_file_name
        )
      )
  ) LOOP
    -- Increase row counter
    row_counter := row_counter + 1;
  
  -- Skip first row (header) and check if col001 is not NULL
  IF row_counter > 1 AND TRIM(row_rec.col001) IS NOT NULL THEN  
  bhu_logs(801,'gtc 01','clobgtc801');
    -- Extract and trim values.
    v_country_name        := TRIM(row_rec.col001);
    v_entity_name         := TRIM(row_rec.col002);
    v_payment_name        := row_rec.col003;
    v_payment_description := row_rec.col004;
    v_legal_due_date      := TO_DATE(row_rec.col005, 'YYYY-MM-DD');
    v_pay_period          := row_rec.col006;
    v_manual_amount       := to_number(row_rec.col007);
    v_manual_amount_descr := row_rec.col008;
    v_prerequisites_recv  := CASE 
                                WHEN UPPER(TRIM(row_rec.col009)) = 'YES' THEN 'Y'
                                WHEN UPPER(TRIM(row_rec.col009)) = 'NO' THEN 'N'
                                ELSE NULL
                              END;
    v_prerequisites_url   := row_rec.col010;
    -- Determine pre requisites user and date based on v_prerequisites_recv value
        IF  v_prerequisites_recv = 'Y' THEN
            v_pre_requisites_user := v('APP_USER');
            v_pre_requisites_date := SYSTIMESTAMP;
        ELSE
            v_pre_requisites_user := NULL;
            v_pre_requisites_date := NULL;
        END IF;

        -- Look up COUNTRY_ID based on the display value.
    BEGIN
      SELECT id INTO v_country_id 
      FROM MD_COUNTRIES_V 
      WHERE UPPER(COUNTRY_NAME_BRANCH_C) = UPPER(v_country_name);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_country_id := NULL;  -- or handle error/assign default
    END;
    
    -- Look up ENTITY_ID based on the display value.
    BEGIN
      SELECT id_entity INTO v_entity_id 
      FROM MD_ENTITIES 
      WHERE UPPER(entity_name) = UPPER(v_entity_name);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_entity_id := NULL;  -- or handle error/assign default
    END;
    
    bhu_logs(81,'gtc 1','clobgtc81');
    -- Insert the processed row into GTC_PAYMENTS.
    INSERT INTO GTC_PAYMENTS (
      COUNTRY_ID, 
      ENTITY_ID, 
      PAYMENT_NAME, 
      PAYMENT_DESCRIPTION, 
      LEGAL_DUE_DATE, 
      MANUAL_AMOUNT, 
      MANUAL_AMOUNT_DESCRIPTION, 
      PRE_REQUISITIES_RECEIVED, 
      PRE_REQUISITIES_URL,
      PRE_REQUISITIES_USER, 
      PRE_REQUISITIES_DATE
    )
    VALUES (
      v_country_id,
      v_entity_id,
      v_payment_name,
      v_payment_description,
      TO_DATE(v_legal_due_date, 'DD-MON-YY'),  -- adjust format as needed
      TO_NUMBER(v_manual_amount),
      v_manual_amount_descr,
      v_prerequisites_recv,
      v_prerequisites_url,
      v_pre_requisites_user,
      v_pre_requisites_date
    )

     RETURNING ID INTO v_gtc_payment_id;  -- **Capture the ID**

      -- Now insert the pay_period into GTC_PAYMENTS_MAPPING
      IF v_pay_period IS NOT NULL THEN
         INSERT INTO GTC_PAYMENTS_MAPPING (
          --   ID,                -- If your table uses a sequence or auto-increment, adjust accordingly
             GTC_PAYMENT_ID,
             TYPE,
             VALUE
         )
         VALUES (
            -- GTC_PAYMENTS_MAPPING_SEQ.NEXTVAL,  -- or omit if your DB triggers auto-generate the ID
             v_gtc_payment_id,
             'PAY_PERIOD',
             v_pay_period
         );
      END IF;

    END IF; -- row counter check end
  END LOOP;
  
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END UPLOAD_MANUAL_PAYMENT;

-------------------------------------------------------

end GPAT_pkg;
/