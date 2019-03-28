# Rematch_images
Simple tool to match sets of movies within two lists of cryoEM movies (with different names).

The whole process takes a little under an hour (which is obviously super slow), but has already saved me many weeks of re-processing data.

# Assumptions
1. The tool assumes the two lists are duplicates of a single data set, however the names of each file within the two lists are no longer consistent e.g. after renaming movies, you aim to reidentify how the old names relate to the new names. This is useful if (like me) you have accidentally named a set and wish to restrospectively re-identify the original movies.

2. The routine should be executed within a directory that contains two sub-directories; movies_original and movies_query. The originally named movies are placed in movies_original, and the images needing to be re-identified are in movies_query.

3. Movies should be in tiff format. (However this is not mandatory, you will simply need to edit the run.sh routine. It will also work on mrcs movies too.)

# Current dependencies
1. scipion
2. relion (2 or above)
3. python (+these packages, the following are easy to install with pip)
  - mrcfile
  - multiprocess
  - numpy

# Manual execution

If you prefer, match_loop_lst_parallel.py can directly be executed as

    python ./match_loop_lst_parallel.py ./barcode_original/ ./barcode_query/
    
This assumes you have the two directories above, these should each contain "particles" i.e. 100x100 2d-array that have been extracted from the movies you wish to compare. The exact size if the particle is not important: smaller is faster, but too small will not provide enough confidence of an accurate match - like DNA primers. I use a single coordinate file (for each movie I make a copy), it is critical that the same region be extracted from each movie.

These act as barcodes and match_loop_lst_parallel.py will compare them to all other possible images and match identical arrays. Ideally you should create these from the unaltered raw movies, as these won't have small differences due to interpolation, normalisation, etc., as this would prevent correct matchs from occuring.

An output match_lst.txt file will contain the matches images. I use grep to then pull out each group of images according to the FoilHole id that I'm interested in.

# Usage: running with bash script

This script will automatically extract small barcode snippits from the first frame your raw movies (after first making a copy of the first frame) and then launch match_loop_lst_parallel.py.

1. Make a copy of the first frame from the raw movie.
2. Extract a single particle at the same coordinate for each frame in each list - "barcodes". (Currently uses mpi with 16 threads to run relion_preprocess_mpi change this if your workstation has fewer cpus.)
3. Compare the barcodes 
4. Output a match_lst.txt file that contains the matches movies.

Again, first ensure the movies are present in two directorys called movies_original and movies_query. The run.sh, split_stack.py and match_loop_lst_parallel.py files should also be present in the directory. Then execute the run.sh script.

    bash run.sh

This assumes you have modular environment setup on your system. You made need to edit the run.sh script to ensure modules are loaded correctly. I use this to quickly and easily load/swap between relion and scipion.

# CAUTION (!): 
I have hard coded some 'rm' commands into the script to remove unneccessary output directories and files that affect the matching step. I assume this is a huge 'no no', however for my purposes this is a risk I'm willing to live with. Happy for feedback, but you should check through the script before running.

# Contents
- run.sh - script to run the whole protocol automatically
- split_stack.py - edited version of scipion's split_stack.py that only creates a copy of the first frame from each movie in a directory.
- match_loop_lst_parallel.py - parallelised routine to quickly (~15 minutes) match images.
