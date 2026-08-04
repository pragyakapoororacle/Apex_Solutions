declare
v_job clob;
v_sql clob;
begin
v_sql := '  BEGIN
               UPDATE AUD_DIRECTOR_MAP a
               SET DIRECTOR_AUTOMATION_ID = AUD_PKG.get_director_id(a.USER_NAME) ,
               AUTOMATION_LAST_RUN = SYSDATE;
               COMMIT;
            END; ';

  DBMS_SCHEDULER.CREATE_JOB (
    job_name   => 'AUD_UPDATE_DIRECTORS_JOB',
    job_type   => 'PLSQL_BLOCK',
    job_action => v_Sql,
    start_date => SYSTIMESTAMP,
    enabled    => FALSE,
    repeat_interval => 'FREQ=WEEKLY;BYDAY=SUN;BYHOUR=2;BYMINUTE=0;BYSECOND=0'
      );
END;