create or replace TRIGGER "AA_EXEMPTED_EMP_IU" 
              before insert or update 
              on AA_EXEMPTED_EMP 
              for each row 
              begin 
               
                declare 
                  v_user t.email := ws_tools.get_user; 
                   
                begin 
                 
                  if inserting 
                    then 
                      :new.AA_EXEMPTED_EMP_ID := AA_EXEMPTED_EMP_SEQ.nextval; 
                      :new.created_by := v_user; 
                      :new.created_ON := localtimestamp; 
                      :new.updated_by := v_user; 
                      :new.updated_on := localtimestamp; 
                  elsif updating 
                    then 
                      :new.updated_by := v_user; 
                      :new.updated_on := localtimestamp; 
                  else null; 
                  end if; 
               
                end; 
              end;
/