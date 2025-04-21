import json
import sqlite3
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--db_path", help="The path of db")
parser.add_argument("--offset_hour", type=int, help="The path of db")
args = parser.parse_args()

DB_PATH = args.db_path
OFFSET_HOUR = args.offset_hour

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

cursor.execute(f'''
    SELECT
        row_number() OVER () AS id,
        case grp.DayName
            when 0 then 'Sunday'
            when 1 then 'Monday'
            when 2 then 'Tuesday'
            when 3 then 'Wednesday'
            when 4 then 'Thursday'
            when 5 then 'Friday'
            else 'Saturday'
        end as DayName,
        grp.Date,
        grp.LatestCreatedTimestampInt,
        grp.LatestOpenTime,
        grp.FileOpenCount,
        grp.CurrentWorkingDir
    FROM
    (
        SELECT
            fh.CreatedTimestamp as Date,
            cast(strftime("%w", max(fh.CreatedTimestampInt) + ({OFFSET_HOUR} * 3600), 'unixepoch') as integer) as DayName,
            max(fh.CreatedTimestampInt) as LatestCreatedTimestampInt,
            strftime("%Y-%m-%d %H:%M:%S", max(fh.CreatedTimestampInt) + ({OFFSET_HOUR} * 3600), 'unixepoch') as LatestOpenTime,
            count(fh.CreatedTimestampInt) as FileOpenCount,
            fh.CurrentWorkingDir
        FROM
        (
            SELECT
                strftime("%Y-%m-%d", CreatedTimestampInt + ({OFFSET_HOUR} * 3600), 'unixepoch') as CreatedTimestamp,
                CreatedTimestampInt,
                CurrentWorkingDir
            FROM FileReadHistory
        ) fh
        GROUP BY fh.CreatedTimestamp, fh.CurrentWorkingDir
        ORDER BY fh.CreatedTimestamp DESC, fh.CreatedTimestampInt DESC
    ) grp
'''
)

all_data_list = cursor.fetchall()

data_load = []
for row in all_data_list:
    temp_data = {
        'Id': row[0],
        'DayName': row[1],
        'Date': row[2],
        'LatestCreatedTimestampInt': row[3],
        'LatestOpenTime': row[4],
        'FileOpenCount': row[5],
        'CurrentWorkingDir': row[6],
    }
    data_load.append(temp_data)


note_data = {
    'data': data_load
}

print(json.dumps(note_data))
