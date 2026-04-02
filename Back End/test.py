#for this to work python must be installed and 
#have a PATH and Pip(there should be a checkmark call eviromental path or something similar) for it

import psutil #imports psutil is used to collect telemetry data
import time #used to slow the file down for proper use
import json #creates the file for api to bring to sql
import datetime #time gets the time for the json file so sql can use that to make a compound key or other method

#if any of these are not recognised do "pip install name"
#This will open a file with the node identification number to recognize which node the data is coming from
with open("/home/truenas_admin/projects/'Back End'/node_id.txt", "r") as id:
    node_id = id.read().strip()

psutil.cpu_percent(interval=None) #starts the call then waits so it works the next time
time.sleep(1)#sleeps to make sure it working

#CPU

cpu_percent = psutil.cpu_percent(interval=1)#grabs average cpu percent over the course of one second

cpu_per_core = psutil.cpu_percent(interval=1, percpu=True)#grabs each cpu cores percent over the course of one second

cpu_freq = psutil.cpu_freq()._asdict()#grabs the cpu frequency then converts it to Dict

#RAM

ram_used = (psutil.virtual_memory().used)/1073741824#grabs ram used then dived to make it in GB

ram_total = (psutil.virtual_memory().total)/1073741824#grabs ram total then dived to make it in GB

ram_percent = psutil.virtual_memory().percent#grabs ram percent

swap_percent = psutil.swap_memory().percent#grabs swap percent which is the percentage of hard drive space used as virtual memory

#Disk

disk_data = []#holds all the data

for part in psutil.disk_partitions():#provides details of all mounted disk partitions as a list of named tuples
    usage = psutil.disk_usage(part.mountpoint)#goes through the named tuples and access the mountpoint attribute of each
    disk_data.append({#for each tuple adds the data needed to disk data
        "mount": part.mountpoint,#gets the mountpont
        "total": usage.total / 1073741824,#total disk converted to GB
        "used": usage.used / 1073741824,#total disk used converted to GB
        "percent": usage.percent#disk percent
    })

disk_total = sum(d["total"] for d in disk_data)#finds all the total data and sums them to get full total
disk_used = sum(d["used"] for d in disk_data)#finds all the used data and sums them to get full used

disk_percent = (disk_used / disk_total) * 100 if disk_total > 0 else 0#finds the percent by diveding used by total

read_bytes = (psutil.disk_io_counters().read_bytes)/1073741824#grabs the read bytes and converts it to GB

write_bytes = (psutil.disk_io_counters().write_bytes)/1073741824#grabs the write bytes and converts it to GB

#Thermal

#set to none incase of failing to get the temp
cpu_temp = None#temp of CPU
system_temp = None#temp of the motherboard

try:
    temps = psutil.sensors_temperatures()#grabs all the sensors temps
    if not temps:#there is possiblity espicaly on window that temp does not work
        print("Temperature sensors not supported on this system or no data available.")#informs user that the sensore arn't working
    else:#if there is info
        cpu_sensors = temps.get('coretemp', [])#grabs the core temps and grabs the current temp of cpu if it exist 
        cpu_temp = cpu_sensors[0].current if cpu_sensors else None

        system_sensors = temps.get('nct6791', [])#grabs the system temps and grabs the current temp of motherboard if it exist 
        system_temp = system_sensors[0].current if system_sensors else None

except AttributeError:#checks to see if OS allows grabing tmpetures
    print("psutil.sensors_temperatures() is not supported on this OS.")
except Exception as e:#check to see if there is another problem
    print(f"An error occurred: {e}")

#Time

Time = datetime.datetime.now()#grabs full time 
date_log = Time.strftime("%x")#gets Local version of dat ei 12/31/18
time_hour_log = Time.strftime("%I")#grabs hour 00-12
time_minute_log = Time.strftime("%M")#grabs minute 00-59
time_meridiem_log = Time.strftime("%p")#gets wether its AM or PM
time_log = (time_hour_log + ":" + time_minute_log + " " + time_meridiem_log)#combines them all into a understadable time log

#Converting data into JSON

data = {#uses all the data collected and converts it into a json file
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

#For testing and easier to compare to the JSON file to see if everything is working how it should
#this will be deleted when code is fully done
print(f"node_id: {node_id}")
print(f"CPU percent: {cpu_percent}%")
print(f"CPU core percent: {cpu_per_core}%")
print(f"CPU freq: {cpu_freq}")
print(f"ram_used: {ram_used:.2f} GB")
print(f"ram_total: {ram_total:.2f} GB")
print(f"ram_percent: {ram_percent}%")
print(f"swap_percent: {swap_percent}%")
print(f"disk_total: {disk_total:.2f} GB")
print(f"disk_used: {disk_used:.2f} GB")
print(f"disk_percent: {disk_percent}%")
print(f"read_bytes: {read_bytes:.2f} GB")
print(f"write_bytes: {write_bytes:.2f} GB")
print(f"cpu_temp: {cpu_temp}%")
print(f"system_temp: {system_temp}%")
print(f"date_log: {date_log}")
print(f"time_log: {time_log}")

#The actual JSON file and where the data will be placed
#uses the data to fill the json
json_string = json.dumps(data, indent=4)
with open('data_string.json', 'w') as file:#put in w mode so it can write and will make the file if missing
    file.write(json_string)
