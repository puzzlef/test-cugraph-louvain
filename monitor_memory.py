import time
from pynvml import *




# Monitor GPU memory usage
nvmlInit()
handle = nvmlDeviceGetHandleByIndex(0)
while True:
  info = nvmlDeviceGetMemoryInfo(handle)
  print("Total memory: {:.4f} GB".format(info.total/1024**3), flush=True)
  print("Free memory:  {:.4f} GB".format(info.free /1024**3), flush=True)
  print("Used memory:  {:.4f} GB".format(info.used /1024**3), flush=True)
  time.sleep(0.5)
nvmlShutdown()
