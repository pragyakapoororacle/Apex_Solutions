create or replace function get_cal_key (
    p_ui_month   in varchar2,   -- e.g. February
    p_ui_year    in varchar2,   -- e.g. 2026
    p_app_user   in varchar2,
    p_set_val    in varchar2,   -- colon-separated country IDs
    p_country_id in number,
    p_subreg     in varchar2,
    p_hub        in varchar2,
    p_paytask    in varchar2    -- colon-separated short names
) return clob
is
    c_grid_size constant pls_integer := 42;

    v_first_day     date;
    v_first_dow     pls_integer;
    v_days_in_month pls_integer;
    v_cell_day      pls_integer;

    type t_vc_tab is table of varchar2(50) index by pls_integer;
    type t_clob_tab is table of clob index by pls_integer;
    type t_event_by_date is table of clob index by varchar2(8);

    l_day_txt        t_vc_tab;
    l_event_txt      t_clob_tab;
    l_events_by_date t_event_by_date;

    l_out clob;

    function chunk_count(p_txt in clob) return pls_integer is
        l_separator constant varchar2(2) := chr(10) || chr(10);
        l_position  pls_integer := 1;
        l_next      pls_integer;
        l_count     pls_integer := 0;
    begin
        if p_txt is null or dbms_lob.getlength(p_txt) = 0 then
            return 1;
        end if;

        loop
            l_next  := dbms_lob.instr(p_txt, l_separator, l_position);
            l_count := l_count + 1;

            exit when l_next = 0;

            l_position := l_next + length(l_separator);
        end loop;

        return greatest(l_count, 1);
    end chunk_count;

    function get_chunk(
        p_txt in clob,
        p_n   in pls_integer
    ) return clob is
        l_separator constant varchar2(2) := chr(10) || chr(10);
        l_position  pls_integer := 1;
        l_next      pls_integer;
        l_index     pls_integer := 1;
        l_length    pls_integer;
    begin
        if p_txt is null or dbms_lob.getlength(p_txt) = 0 then
            return '';
        end if;

        loop
            l_next := dbms_lob.instr(p_txt, l_separator, l_position);

            if l_next = 0 then
            -- last chunk
                if l_index = p_n then
                    l_length := dbms_lob.getlength(p_txt) - l_position + 1;
                    return trim(dbms_lob.substr(p_txt, l_length, l_position));
                end if;

                return '';
            end if;
            -- chunk ends before separator
            if l_index = p_n then
                l_length := l_next - l_position;
                return trim(dbms_lob.substr(p_txt, l_length, l_position));
            end if;

            l_position := l_next + length(l_separator);
            l_index    := l_index + 1;
        end loop;
    end get_chunk;

begin
    v_first_day := to_date('01-' || trim(p_ui_month) || '-' || trim(p_ui_year), 'DD-Month-YYYY', 'NLS_DATE_LANGUAGE=ENGLISH');

    v_days_in_month := to_number(to_char(last_day(v_first_day), 'DD')); --Sunday = 1 through Saturday = 7.
    v_first_dow := 1 + mod(v_first_day - trunc(v_first_day, 'IW') + 1, 7);
    

    -- Optimization: one query for all events in the month, rather than one XMLAGG query for each of 42 calendar cells.
        for rec in (
            select trunc(c.start_date) as event_date,
                   rtrim(
                       xmlagg(
                           xmlelement(
                               e,
                               'Country: ' || c.country_name || chr(10) ||
                            --    'Start: ' || to_char(c.start_date, 'MM/DD/YYYY') ||
                            --    ' End: ' || to_char(c.end_date, 'MM/DD/YYYY') || chr(10) ||
                               c.country_code2 || ' - ' || c.short_name || chr(10) ||
                               c.full_name || chr(10) ||
                               c.the_year || ' - ' || c.the_month || ' - ' ||
                               c.pay_type || chr(10) || chr(10)
                           )
                           order by c.start_date,
                                    c.country_name,
                                    c.short_name
                       ).extract('//text()').getclobval(),
                       chr(10)
                   ) as event_text
              from cal_pay_calendar_event_v c
              join md_countries f
                on f.id = c.country_id
             where c.start_date >= v_first_day
               and c.start_date < add_months(v_first_day, 1)
               and (
                    p_set_val is null
                    or instr(
                        ':' || p_set_val || ':',
                        ':' || to_char(c.country_id) || ':'
                    ) > 0
               )
               and (p_country_id is null or c.country_id = p_country_id)
               and (p_subreg is null or f.sub_region = p_subreg)
               and (p_hub is null or f.hub = p_hub)
               and exists (
                     select 1
                       from md_users_v u
                      where upper(u.username) = upper(p_app_user)
                        and (u.region is null or u.region = f.region)
                 )               
                 and (
                    p_paytask is null
                    or instr(
                        ':' || p_paytask || ':',
                        ':' || c.short_name || ':'
                    ) > 0
               )
             group by trunc(c.start_date)
        ) loop
            l_events_by_date(
                to_char(rec.event_date, 'YYYYMMDD')
            ) := rec.event_text;
        end loop;

    /*
      Populate the 42 visual grid cells from the in-memory event map.
    */
    v_cell_day := 1 - (v_first_dow - 1);

    for i in 1 .. c_grid_size loop
        if v_cell_day between 1 and v_days_in_month then
            l_day_txt(i) := to_char(v_cell_day);

            declare
                l_date_key varchar2(8);
            begin
                l_date_key := to_char(
                    v_first_day + v_cell_day - 1,
                    'YYYYMMDD'
                );

                if l_events_by_date.exists(l_date_key) then
                    l_event_txt(i) := l_events_by_date(l_date_key);
                else
                    l_event_txt(i) := '';
                end if;
            end;
        else
            l_day_txt(i)   := '';
            l_event_txt(i) := '';
        end if;

        v_cell_day := v_cell_day + 1;
    end loop;

    apex_json.initialize_clob_output;
    apex_json.open_object;

    apex_json.write('month', p_ui_month);
    apex_json.write('year', p_ui_year);

    for i in 1 .. c_grid_size loop
        apex_json.write('day' || i, nvl(l_day_txt(i), ''));
    end loop;

    for wk in 1 .. 6 loop
        declare
            l_start    pls_integer := (wk - 1) * 7 + 1;
            l_end      pls_integer := (wk - 1) * 7 + 7;
            l_max_rows pls_integer := 1;
        begin
            for d in l_start .. l_end loop
                l_max_rows := greatest(
                    l_max_rows,
                    chunk_count(l_event_txt(d))
                );
            end loop;

            apex_json.open_array('l' || wk);

            for r in 1 .. l_max_rows loop
                apex_json.open_object;

                for d in l_start .. l_end loop
                    apex_json.write(
                        'event' || d,
                        get_chunk(l_event_txt(d), r)
                    );
                end loop;

                apex_json.close_object;
            end loop;

            apex_json.close_array;
        end;
    end loop;

    apex_json.close_object;

    l_out := apex_json.get_clob_output;
    apex_json.free_output;

    return l_out;

exception
    when others then
        begin
            apex_json.free_output;
        exception
            when others then
                null;
        end;

        raise_application_error(
            -20002,
            'Invalid calendar JSON for month ' ||
            nvl(p_ui_month, '[null]') || ': ' || sqlerrm
        );
end get_cal_key;
/