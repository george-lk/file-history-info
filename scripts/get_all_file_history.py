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
        id,
        strftime("%m-%d-%Y %H:%M:%S", CreatedTimestampInt + ({OFFSET_HOUR} * 3600), 'unixepoch') as CreatedTimestamp,
        FullFilePath,
        RelativeFilePath,
        CurrentWorkingDir,
        GitTopLevelPath,
        GitRepoRemoteUrl,
        strftime("%m-%d-%Y %H:%M:%S", LastModifiedTimestampInt, 'unixepoch') as LastModifiedTimestamp
    FROM FileReadHistory
    WHERE IsDeleted = 0
    ORDER BY CreatedTimestamp DESC;
'''
)

all_data_list = cursor.fetchall()

data_load = []
for row in all_data_list:
    temp_data = {
        'Id': row[0],
        'CreatedTimestamp': row[1],
        'FullFilePath': row[2],
        'RelativeFilePath': row[3],
        'CurrentWorkingDir': row[4],
        'GitTopLevelPath': row[5],
        'GitRepoRemoteUrl': row[6],
        'LastModifiedTimestamp': row[7],
    }
    data_load.append(temp_data)


note_data = {
    'data': data_load
}

print(json.dumps(note_data))
