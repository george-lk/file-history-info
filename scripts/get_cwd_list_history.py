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
        grp.Date,
        grp.LatestCreatedTimestampInt,
        grp.LatestOpenTime,
        grp.FileOpenCount,
        grp.CurrentWorkingDir
    FROM
    (
        SELECT
            fh.CreatedTimestamp as Date,
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
    ) grp
    ORDER BY grp.Date DESC, grp.LatestOpenTime DESC'''
)

all_data_list = cursor.fetchall()

data_load = []
for row in all_data_list:
    temp_data = {
        'Date': row[0],
        'LatestCreatedTimestampInt': row[1],
        'LatestOpenTime': row[2],
        'FileOpenCount': row[3],
        'CurrentWorkingDir': row[4],
    }
    data_load.append(temp_data)


note_data = {
    'data': data_load
}

print(json.dumps(note_data))
