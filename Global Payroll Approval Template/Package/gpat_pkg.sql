create or replace package GPAT_pkg as
/*===================================================================================================================  
HISTORY     
------- 
            03-JAN-2018    (Initial Version)
			30-JAN-2018    added 'send_email_notification' procedure and 'get_names' function
            21-FEB-2018    bug fix
            23-MAR-2018    added function 'check_pay_vs_net'
            29-MAR-2018    adjustments to function 'check_pay_vs_net'
            11-APR-2018    added function 'my_html_strip'
            25-APR-2018    updated function 'my_html_strip' - added replacement &#39; => '
            11-MAY-2018    updated function 'my_html_strip' - added replacement &amp; => &
            27-JUL-2023    updated send_email_notification procedure added p_gpat_or_gpt,p_gpt_batch_id,p_gpt_batch_source for GPT Enhancement 10781
===================================================================================================================== */ 
--== Constants ==--
c_Prod_URL_Base constant varchar2(128):= 'https://apex.oraclecorp.com/pls/apex/' ;
c_Prod_Workspace_Name constant varchar2(30):= 'PAYROLL_PROD' ;
c_Prod_Application_ID constant varchar2(10) := 10463 ;

c_Dev_URL_Base constant varchar2(128):= 'https://apex-dev.oraclecorp.com/pls/apex/' ; -- bhuvi changes this from apex-stage to apex-dev on 12 june 2024
c_Dev_Workspace_Name constant varchar2(30):= 'PAYROLL_DEV' ;
c_Dev_Application_ID constant varchar2(10) :=  10781;

c_Workspace_Name constant varchar2(30) := APEX_UTIL.FIND_WORKSPACE(v('WORKSPACE_ID')) ;
c_Application_ID constant varchar2(10) := v('APP_ID') ;

--== PROCEDURES ==--
-- It updates task parameters.
procedure send_email_notification( p_gpat_id     number
                                 , p_req_action  varchar2
                                 , p_send_to     varchar2
                                 , p_send_cc     varchar2 default null
                                 , p_send_bcc    varchar2 default 'marek.szwarczewski@oracle.com'
                                 , p_comment     varchar2 default null
                                 , p_gpat_or_gpt varchar2 default 'gpat'
                                 , p_gpt_batch_id number  default null
                                 , p_gpt_batch_source varchar2 default null
                                 ) ;


--== FUNCTIONS ==--
-- Function returns true if the package is installed on the test environment.
function custom_test_auth( p_username in varchar2
                         , p_password in varchar2
                         ) return boolean ;

-- Function returns First and Last name extracted from the email address.
function get_names(p_email_address in varchar2) return varchar2 deterministic ;

-- Function strip out the html tags, CR, LF and replace them by space. Then trim consequent spaces.
function my_html_strip(p_input_text in varchar2) return varchar2 deterministic ;

-- Function compare if total amount to pay (by Bank and Cheques) is equal to the calculated Net amount.
function check_pay_vs_net( p_gpat_id         number
                         , p_bank_transfer   number default null
                         , p_paycheck        number default null
                         ) return varchar2 deterministic ;

PROCEDURE INIT_TAX_CALENDAR;

PROCEDURE UPLOAD_MANUAL_PAYMENT(
  p_file_name IN VARCHAR2
);


end GPAT_pkg;
/