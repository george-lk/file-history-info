import sqlite3
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--db_path", help="The path of db")
args = parser.parse_args()

DB_PATH = args.db_path

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# CreatedTimestampInt and LastModifiedTimestampInt date is stored in UnixTimestamp
cursor.execute('''
    CREATE TABLE IF NOT EXISTS "FileReadHistory" (
        "Id"	INTEGER,
        "CreatedTimestampInt"	INTEGER,
        "FullFilePath"	TEXT,
        "RelativeFilePath"	TEXT,
        "CurrentWorkingDir"	TEXT,
        "GitTopLevelPath"	TEXT,
        "GitRepoRemoteUrl"	TEXT,
        "LastModifiedTimestampInt"	INTEGER,
        "IsDeleted"	INTEGER,
        PRIMARY KEY("Id" AUTOINCREMENT)
    )
'''
)

print("Process Completed")
