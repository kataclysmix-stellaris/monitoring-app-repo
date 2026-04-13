#for this to work python must be installed and 
#have a PATH and Pip(there should be a checkmark call eviromental path or something similar) for it

# for each import open terminal then type "pip install {name}"
import psutil #imports psutil is used to collect telemetry data
import time #used to slow the file down for proper use
import json #creates the file for api to bring to sql
import datetime #time gets the time for the json file so sql can use that to make a compound key or other method
import subprocess
import platform
import os
import requests 

# -------------------- NODE ID --------------------

node_id_path = "C:\\ProgramData\\node_id.txt"#open the node id text file to get node id

try:
    with open(node_id_path, "r") as f:
        node_id = f.read().strip()#gets the node id for machine
except:
    node_id = "UNKNOWN_NODE"#if unkown node assigns unknown node

#------------------------grab full data node------------------------------

psutil.cpu_percent(interval=None) #starts the call then waits so it works the next time
time.sleep(1)#sleeps to make sure it working

#CPU

node_cpu_percent = psutil.cpu_percent(interval=1)#grabs average cpu percent over the course of one second

node_cpu_per_core = psutil.cpu_percent(interval=1, percpu=True)#grabs each cpu cores percent over the course of one second

node_cpu_freq = psutil.cpu_freq()._asdict()#grabs the cpu frequency then converts it to Dict

#RAM

node_ram_used = (psutil.virtual_memory().used)/1073741824#grabs ram used then dived to make it in GB

node_ram_total = (psutil.virtual_memory().total)/1073741824#grabs ram total then dived to make it in GB

node_ram_percent = psutil.virtual_memory().percent#grabs ram percent

node_swap_percent = psutil.swap_memory().percent#grabs swap percent which is the percentage of hard drive space used as virtual memory

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

node_disk_total = sum(d["total"] for d in disk_data)#finds all the total data and sums them to get full total
node_disk_used = sum(d["used"] for d in disk_data)#finds all the used data and sums them to get full used

node_disk_percent = (node_disk_used / node_disk_total) * 100 if node_disk_total > 0 else 0#finds the percent by diveding used by total

node_read_bytes = (psutil.disk_io_counters().read_bytes)/1073741824#grabs the read bytes and converts it to GB

node_write_bytes = (psutil.disk_io_counters().write_bytes)/1073741824#grabs the write bytes and converts it to GB

#Thermal

#set to none incase of failing to get the temp
node_cpu_temp = None#temp of CPU
node_system_temp = None#temp of the motherboard

try:
    temps = psutil.sensors_temperatures()#grabs all the sensors temps
    if not temps:#there is possiblity espicaly on window that temp does not work
        print("Temperature sensors not supported on this system or no data available.")#informs user that the sensore arn't working
    else:#if there is info
        cpu_sensors = temps.get('coretemp', [])#grabs the core temps and grabs the current temp of cpu if it exist 
        node_cpu_temp = cpu_sensors[0].current if cpu_sensors else None

        system_sensors = temps.get('nct6791', [])#grabs the system temps and grabs the current temp of motherboard if it exist 
        node_system_temp = system_sensors[0].current if system_sensors else None

except AttributeError:#checks to see if OS allows grabing tmpetures
    print("psutil.sensors_temperatures() is not supported on this OS.")
except Exception as e:#check to see if there is another problem
    print(f"An error occurred: {e}")



#------------------------grab data from each VM---------------------------

vm_data_list = []

if platform.system() == "Windows":#node with vm run on windows
    try:
        command = [#powershell command to get info on the VM for the computer
            "powershell",
            "-Command",
            "Get-VM | Select-Object Name, State, CPUUsage, MemoryAssigned | ConvertTo-Json"
        ]

        result = subprocess.run(command, capture_output=True, text=True)#run the command

        if result.returncode == 0 and result.stdout.strip():#if gets data
            vms = json.loads(result.stdout)

            # Normalize single VM case
            if isinstance(vms, dict):
                vms = [vms]

            for vm in vms:#go through each VM and inputs appropiate data
                vm_info = {
                    "type": "vm",
                    "vm_id": vm.get("Name"),
                    "vm_name": vm.get("Name"),
                    "status": vm.get("State"),
                    "cpu_percent": vm.get("CPUUsage", 0),
                    "ram_used_gb": (vm.get("MemoryAssigned", 0) / (1024**3))
                }

                vm_data_list.append(vm_info)

    except Exception as e:
        print("VM collection error:", e)

#------------------------get info for Json--------------------------------

#Time
Time = datetime.datetime.now()#grabs full time 
date_log = Time.strftime("%x")#gets Local version of dat ei 12/31/18
time_hour_log = Time.strftime("%I")#grabs hour 00-12
time_minute_log = Time.strftime("%M")#grabs minute 00-59
time_meridiem_log = Time.strftime("%p")#gets wether its AM or PM
time_log = (time_hour_log + ":" + time_minute_log + " " + time_meridiem_log)#combines them all into a understadable time log


final_output = {
    "timestamp": datetime.datetime.now().isoformat(),
    "node": {
        "node_id": node_id,

        # CPU
        "cpu_percent": round(node_cpu_percent, 2),
        "cpu_per_core": node_cpu_per_core,
        "cpu_freq": node_cpu_freq,

        # RAM
        "ram_used": round(node_ram_used, 2),
        "ram_total": round(node_ram_total, 2),
        "ram_percent": round(node_ram_percent, 2),
        "swap_percent": round(node_swap_percent, 2),

        # Disk
        "disk_total": round(node_disk_total, 2),
        "disk_used": round(node_disk_used, 2),
        "disk_percent": round(node_disk_percent, 2),
        "read_bytes": round(node_read_bytes, 2),
        "write_bytes": round(node_write_bytes, 2),

        # Temps
        "cpu_temp": node_cpu_temp,
        "system_temp": node_system_temp
    },
    "vm_count": len(vm_data_list),
    "vms": vm_data_list
}

#------------------------put info on Json---------------------------------

with open('full_data.json', 'w') as file:
    json.dump(final_output, file, indent=4)
print(json.dumps(final_output, indent=4))

#------------------------send the data to API---------------------------------
try:
    API_KEY = os.environ.get("MY_API_KEY")#find API key stored in Eviromental variable(for security)
except:
    print("failed to get key")
headers = {#authorisation to get into the API sent with data  
    "Authorization": f"Bearer {API_KEY}",   
    "Content-Type": "application/json" 
}  
try:
    response = requests.post(URL, json=data, headers=headers)#send data to API
    if response.status_code == 200: #if it sent correctly 
        print("sent successfully")
    else:  #if there was a problem sending
        print(f"Error: {response.status_code} - {response.text}")  
except Exception as e:#if an error accoured in the sender instead of during the data being sent
    print(f"An error occurred: {e}")
