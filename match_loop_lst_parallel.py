import numpy as np
import mrcfile
import sys
import os
import subprocess
import multiprocessing

outF=open("unmatch_lst.txt","w")
outM=open("match_lst.txt","w")
orig_dir=sys.argv[1]
new_dir=sys.argv[2]

query_lst=[f for f in os.listdir(orig_dir) if os.path.isfile(os.path.join(orig_dir,f))]
imgs_lst=[f for f in os.listdir(new_dir) if os.path.isfile(os.path.join(new_dir,f))]

# Write matched lists
def match(process_name, tasks):
	img = tasks.get()
	print('Launching subprocess [ %s ]: evaluation of image [ %s ]' % (process_name, img))
	img_01 = mrcfile.open(os.path.join(orig_dir,img))
	final_images = [i for i in imgs_lst if i not in exclude]
	for filename2 in final_images:
		img_02 = mrcfile.open(os.path.join(new_dir,filename2))
		if int(np.array_equal(img_01.data,img_02.data)):
			outM.write("%s %s\n" % (img, filename2))
			img_02.close()
			exclude.append(filename2)
			outM.close()
			break
	img_01.close()

if __name__ == "__main__":
    # Define IPC manager
    manager = multiprocessing.Manager()
    exclude = manager.list()

    # Define a list (queue) for tasks and computation results
    tasks = manager.Queue()
    results = manager.Queue()

# Create process pool with four processes
num_processes = 8
pool = multiprocessing.Pool(processes=num_processes)
processes = []

# Fill task queue
for single_task in query_lst:
    tasks.put(single_task)

# Determine number of repeat launches
iter = (len(query_lst) // num_processes) + (len(query_lst) % num_processes > 0)

pids=[]
for n, c in enumerate(range(iter)):
	if (c+1) < iter:
		_np = num_processes
	else:
		_np = (len(query_lst) % num_processes)
	# Initiate the worker processes
	for i in range(_np):
           # Set process name
 	   process_name = 'P%i' % i

 	   # Create the process, and connect it to the worker function
	   new_process = multiprocessing.Process(target=match, args=(process_name,tasks))

	   # Add new process to the list of processes
	   processes.append(new_process)

	   # Start the process
	   new_process.start()

	   # Wait for process to finish
	   pids.insert(0,new_process)

	for i in range(0,_np):
        	pids[i].join()

unmatched = [i for i in imgs_lst if i not in exclude]
for line in unmatched:
	outF.write("%s\n" % (i))
outM.close()
