#for this to work python must be installed and 
#have a PATH and Pip(there should be a checkmark call eviromental path or something similar) for it

import psutil #imports psutil is used to collect telemetry data
import time #used to slow the file down for proper use
import json #creates the file for api to bring to sql
import datetime #time gets the time for the json file so sql can use that to make a compound key or other method
import requests  
import os  

#if any of these are not recognised do "pip install name"

#------------------------setup--------------------------------------------

URL = "https://"
node_id = "1"
wait_time = 5

#------------------------Main Loop----------------------------------------

psutil.cpu_percent(interval=None) #starts the call then waits so it works the next time
time.sleep(1)#sleeps to make sure it working

while True:

    #------------------------collect data-------------------------------------

    try:
        #CPU
        cpu_percent = psutil.cpu_percent(interval=1)
        cpu_per_core = psutil.cpu_percent(interval=1, percpu=True)
        cpu_freq = psutil.cpu_freq()._asdict()

        #RAM
        ram_used = (psutil.virtual_memory().used)/1073741824
        ram_total = (psutil.virtual_memory().total)/1073741824
        ram_percent = psutil.virtual_memory().percent
        swap_percent = psutil.swap_memory().percent

        #Disk
        disk_data = []
        for part in psutil.disk_partitions():
            usage = psutil.disk_usage(part.mountpoint)
            disk_data.append({
                "mount": part.mountpoint,
                "total": usage.total / 1073741824,
                "used": usage.used / 1073741824,
                "percent": usage.percent
            })

        disk_total = sum(d["total"] for d in disk_data)
        disk_used = sum(d["used"] for d in disk_data)
        disk_percent = (disk_used / disk_total) * 100 if disk_total > 0 else 0
        read_bytes = (psutil.disk_io_counters().read_bytes)/1073741824
        write_bytes = (psutil.disk_io_counters().write_bytes)/1073741824

        print("OK: Hardware data collected")

    except Exception as e:
        print(f"ERROR collecting hardware data: {e}")
        time.sleep(5)
        continue

    #Thermal
    cpu_temp = None
    system_temp = None
    try:
        temps = psutil.sensors_temperatures()
        if not temps:
            print("WARNING: Temperature sensors not available")
        else:
            cpu_sensors = temps.get('coretemp', [])
            cpu_temp = cpu_sensors[0].current if cpu_sensors else None
            system_sensors = temps.get('nct6791', [])
            system_temp = system_sensors[0].current if system_sensors else None
    except AttributeError:
        print("WARNING: sensors_temperatures() not supported on this OS")
    except Exception as e:
        print(f"WARNING: Temp collection error: {e}")

    #Time
    Time = datetime.datetime.now()
    date_log = Time.strftime("%x")
    time_hour_log = Time.strftime("%I")
    time_minute_log = Time.strftime("%M")
    time_meridiem_log = Time.strftime("%p")
    time_log = (time_hour_log + ":" + time_minute_log + " " + time_meridiem_log)

    #------------------------build JSON---------------------------------------

    data = {
        "node_id": node_id,
        "cpu_percent": round(cpu_percent, 2),
        "cpu_per_core": cpu_per_core,
        "cpu_freq": cpu_freq,
        "ram_used": round(ram_used, 2),
        "ram_total": round(ram_total, 2),
        "ram_percent": round(ram_percent, 2),
        "swap_percent": round(swap_percent, 2),
        "disk_total": round(disk_total, 2),
        "disk_used": round(disk_used, 2),
        "disk_percent": round(disk_percent, 2),
        "read_bytes": round(read_bytes, 2),
        "write_bytes": round(write_bytes, 2),
        "cpu_temp": cpu_temp,
        "system_temp": system_temp,
        "date_log": date_log,
        "time_log": time_log
    }

    try:
        json_string = json.dumps(data, indent=4)
        with open('/docker-app/data/data_string.json', 'w') as file:
            file.write(json_string)
        print("OK: JSON file written")
    except Exception as e:
        print(f"ERROR writing JSON file: {e}")


    #------------------------send the data to API-----------------------------

    API_KEY = os.environ.get("MY_API_KEY")
    if not API_KEY:
        print("WARNING: MY_API_KEY environment variable is not set")

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    try:
        response = requests.post(URL, json=data, headers=headers)
        if response.status_code == 200:
            print("OK: Data sent successfully")
        else:
            print(f"ERROR sending data: HTTP {response.status_code} - {response.text}")
    except NameError:
        print("WARNING: URL is not defined yet - skipping send")
    except requests.exceptions.ConnectionError as e:
        print(f"ERROR: Could not connect to API - {e}")
    except Exception as e:
        print(f"ERROR sending data: {e}")

    #------------------------Wait 5 Seconds-----------------------------------
    print(f"Waiting {wait_time} seconds...")
    time.sleep(wait_time)
