#to have this code run correctly you need to:
#in terminal run: pip install json
#in terminal run: pip install time
#in terminal run: pip install watchdog
#then open file explorer go to the bar(the one with home on it)
#then put in \\192.168.30.128\Apps
#        username:better
#        password:j

import json
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

file_path = r"\\192.168.30.128\Apps\data_string.json"

class JSONHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith("data_string.json"):
            try:
                time.sleep(0.5)  
                with open(file_path, 'r') as file:
                    data = json.load(file)

                print(f"--- {data['date_log']} {data['time_log']} ---")
                print(f"CPU percent: {data['cpu_percent']}%")
                print(f"CPU core percent: {data['cpu_per_core']}%")
                print(f"CPU freq: {data['cpu_freq']}")
                print(f"RAM used: {data['ram_used']:.2f} GB")
                print(f"RAM total: {data['ram_total']:.2f} GB")
                print(f"RAM percent: {data['ram_percent']}%")
                print(f"Swap percent: {data['swap_percent']}%")
                print(f"Disk total: {data['disk_total']:.2f} GB")
                print(f"Disk used: {data['disk_used']:.2f} GB")
                print(f"Disk percent: {data['disk_percent']:.2f}%")
                print(f"Read bytes: {data['read_bytes']:.2f} GB")
                print(f"Write bytes: {data['write_bytes']:.2f} GB")
                print(f"CPU temp: {data['cpu_temp']}")
                print(f"System temp: {data['system_temp']}")
                print("-----------------------------------")

            except Exception as e:
                print(f"Error reading file: {e}")

    time.sleep(1)

if __name__ == "__main__":
    watch_path = r"\\192.168.30.128\Apps"
    event_handler = JSONHandler()
    observer = Observer()
    observer.schedule(event_handler, path=watch_path, recursive=False)
    observer.start()
    print(f"Watching for changes to data_string.json...")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
