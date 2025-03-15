import sqlite3
import time
import argparse
from datetime import datetime

parser = argparse.ArgumentParser()
parser.add_argument("--db_path", help="The path of db")
parser.add_argument("--full_file_path", type=str, help="Data to store")
parser.add_argument("--relative_file_path", type=str, help="Data to store")
parser.add_argument("--current_working_dir", type=str, help="Data to store")
parser.add_argument("--git_top_level_path", type=str, help="Data to store")
parser.add_argument("--git_repo_remote_url", type=str, help="Data to store")
args = parser.parse_args()

DB_PATH = args.db_path
full_file_path = args.full_file_path.strip()
relative_file_path = args.relative_file_path.strip()
current_working_dir = args.current_working_dir.strip()
git_top_level_path = args.git_top_level_path.strip()
git_repo_remote_url = args.git_repo_remote_url.strip()

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

timestamp_epoch = int(datetime.now().timestamp())
lastModified = int(datetime.now().timestamp())
isDeleted = 0

cursor.execute('INSERT INTO FileReadHistory (CreatedTimestampInt,FullFilePath,RelativeFilePath,CurrentWorkingDir,GitTopLevelPath,GitRepoRemoteUrl,LastModifiedTimestampInt, IsDeleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (timestamp_epoch, full_file_path, relative_file_path, current_working_dir, git_top_level_path, git_repo_remote_url, lastModified, isDeleted,))

conn.commit()
conn.close()

print("File content has been stored in the database.")

