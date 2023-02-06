WITH member_access_info AS (
    SELECT
        c_member_id
        , last_access_time
    FROM(
        SELECT
            split(user_id, ':') [2] as c_member_id
           , max(custom_dimension11) as last_access_time
        FROM heaven_ga_sessions
        WHERE TD_TIME_RANGE(time, TD_TIME_FORMAT(TD_TIME_ADD(CAST(TO_UNIXTIME(NOW()) as BIGINT),'-365d'),'yyyy-MM-dd','JST'), NULL, 'JST')
        AND strpos(user_id, ':') > 0
       GROUP BY split(user_id, ':') [2]
    )
    -- '54579-07-28 21:10:21'の様な20桁のデータがあったため
    WHERE length(last_access_time) < 20
)
, mamber_login_cnt as (
    SELECT
        c_member_id
        ,count(login_day) as login_month_cnt
    FROM (
        SELECT
            TD_TIME_FORMAT(time, 'yyyyMMdd','JST') as login_day
            , split(user_id, ':') [2] as c_member_id
        FROM heaven_ga_sessions
        WHERE TD_TIME_RANGE(time, TD_TIME_FORMAT(TD_TIME_ADD(CAST(TO_UNIXTIME(NOW()) as BIGINT),'-30d'),'yyyy-MM-dd','JST'), NULL, 'JST')
        AND strpos(user_id, ':') > 0
        AND user_id is not null
        AND user_id != ''
        GROUP BY TD_TIME_FORMAT(time, 'yyyyMMdd','JST') , split(user_id, ':') [2]
    )
    GROUP BY c_member_id
)
, member_info as (
    SELECT
        cm.c_member_id
        , cm.nickname_text as nickname
        , CASE
            WHEN cm.birth_year is not null AND cm.birth_month is not null AND cm.birth_year <> '0' AND cm.birth_month <> '0'
            THEN DATE_DIFF('year', CAST((cm.birth_year ||'-'|| lpad(cm.birth_month,2,'0') ||'-'|| '01') as DATE), NOW())
            ELSE NULL
        END as age
        , cm.birth_year
        , cm.birth_month
    --    , SUBSTR(cm.area_id,3,2) as osumi_pref_id
        , cpp.pref as osumai_pref
    FROM h_c_member cm
    INNER JOIN c_profile_pref cpp
    ON SUBSTR(cm.area_id,3,2) = cpp.pref_id
    -- 女の子を除外し会員のみ
    WHERE cm.member_attribute = '01'
)
SELECT
    bm.c_member_id as "会員ID"
    , cm.nickname as "ニックネーム"
    , CASE
        WHEN lm.login_month_cnt >= 20 THEN 'ヘビー'
        WHEN lm.login_month_cnt > 0 THEN 'ミドル' 
        ELSE 'ライト'
    END as "ランク"
    , CAST(TO_UNIXTIME(date_parse(bm.last_access_time, '%Y-%m-%d %H:%i:%s')) as BIGINT) as "最終ログイン日時(Unixtime)"
FROM member_access_info bm
INNER JOIN member_info cm
ON bm.c_member_id = cm.c_member_id
LEFT JOIN mamber_login_cnt lm
ON bm.c_member_id = lm.c_member_id