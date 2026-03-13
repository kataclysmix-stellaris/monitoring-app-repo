import psutil
import time
import json
import datetime

psutil.cpu_percent(interval=None) #starts the call then waits so it works the next time
time.sleep(1)

# CPU
cpu_percent = psutil.cpu_percent(interval=1)

cpu_per_core = psutil.cpu_percent(interval=1, percpu=True)

cpu_freq = psutil.cpu_freq()._asdict()

# RAM

ram_used = (psutil.virtual_memory().used)/1073741824

ram_total = (psutil.virtual_memory().total)/1073741824

ram_percent = psutil.virtual_memory().percent

swap_percent = psutil.swap_memory().percent

# Disk
disk_data = {}

for part in psutil.disk_partitions():
    usage = psutil.disk_usage(part.mountpoint)

disk_total = (usage.total)/1073741824

disk_used = (usage.used)/1073741824

disk_percent = usage.percent

read_bytes = (psutil.disk_io_counters().read_bytes)/1073741824

write_bytes = (psutil.disk_io_counters().write_bytes)/1073741824

# Thermal
cpu_temp = None
system_temp = None

try:
    temps = psutil.sensors_temperatures()
    if not temps:
         print("Temperature sensors not supported on this system or no data available.")
    else:
        cpu_temp = temps.coretemp()

        system_temp = temps

except AttributeError:
    print("psutil.sensors_temperatures() is not supported on this OS.")
except Exception as e:
     print(f"An error occurred: {e}")

# Time
time_log = (str)(datetime.datetime.now())

# Converting data into a JSON file
data = {
    "cpu_percent": cpu_percent,
    "cpu_per_core": cpu_per_core,
    "cpu_freq": cpu_freq,
    "ram_used": ram_used,
    "ram_total": ram_total,
    "ram_percent": ram_percent,
    "swap_percent": swap_percent,
    "disk_total": disk_total,
    "disk_used": disk_used,
    "disk_percent": disk_percent,
    "read_bytes": read_bytes,
    "write_bytes": write_bytes,
    "cpu_temp": cpu_temp,
    "system_temp": system_temp,
    "time_log": (str)(datetime.datetime.now())
}
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
print(f"log time: {time_log}")

json_string = json.dumps(data, indent=4)
with open('data_string.json', 'w') as file:
    file.write(json_string)
