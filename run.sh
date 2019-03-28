#!/bin/bash

# This first line is source the appropriate file on your system to initiate modular environments
# If you do not use modular environments, give the absolute path to the appropriate program in the following script or indvidually execute the commands.

source /usr/local/Modules/3.2.9/init/bash

#------------------------------ Define working directory and global variables -------------------------------#
WD=$(pwd)
echo Working directory is $WD

#-------------- Check the directory structure is appropriate and make the temporary output directories-------#

# Generates output directories if they do not already exist
if [ ! -d barcodes_original ]; then
        #Make directory structure
        mkdir $WD/barcodes_original
        echo 'Making "barcodes_original" directory. This is where small arrays of the original unaltered images (i.e. FoilHole_[...]*.mrc etc) will be stored for direct comparision. These should contain the beam tilt grouping ID'
fi

if [ ! -d barcodes_query ]; then
        #Make directory structure
        mkdir $WD/barcodes_query
        echo 'Making "barcodes_query" directory. This is where small arrays of the renamed unaltered images will be stored for direct comparision to the originals.'
fi

if [ ! -d single_frame_original ]; then
        #Make directory structure
        mkdir $WD/single_frame_original
        echo 'Making "single_frame_original" directory. This is where the first frame of the original unaltered images (i.e. FoilHole_[...]*.mrc etc) will be stored for direct comparision. These should contain the beam tilt grouping ID'
fi

if [ ! -d single_frame_query ]; then
        #Make directory structure
        mkdir $WD/single_frame_query
        echo 'Making "single_frame_query" directory. This is where small arrays of the renamed unaltered images will be stored for direct comparision to the originals.'
fi

# Checks the input directories are present
if [ ! -d movies_original ]; then
        #Make directory structure
        mkdir $WD/movies_original
        echo "Couldn't find 'movies_original' directory, it has been made. This is where the original movies, with no alterations to their name should be present. Recommended symbolic links to save disk space"
	exit 1;
fi

if [ ! -d movies_query ]; then
        #Make directory structure
        mkdir $WD/movies_query
        echo "Couldn't find 'movies_query' directory, it has been made. This is where the renamed movies, with erroneous alterations to their name should be present. Recommended symbolic links to save disk space"
	exit 1;
fi

# Check the number of images in each directory.
count_orig=0;
count_query=0;
for i in $WD/movies_original/*.tiff; do ((count_orig++)); done
for i in $WD/movies_query/*.tiff; do ((count_query++)); done
if [ $count_orig -ne $count_query ]; then
	echo "Warning, there are different numbers of movies in both the query and original directories. This will result in unmatched movies. Continuing anyway..."
fi

#------------------------------------------------ run routine -----------------------------------------------#

# Run scipion's split_stack.py script, only make copy of the first frame from each image
module load scipion
cd $WD/movies_original/
scipion python $WD/split_stacks.py --files "*.tiff" --ext mrc -n 1
mv *.mrc $WD/single_frame_original/

cd $WD/movies_query
scipion python $WD/split_stacks.py --files "*.tiff" --ext mrc -n 1
mv *.mrc $WD/single_frame_query/

#rename output from scipion
cd $WD/single_frame_original/
rename 's/_001//' *.mrc

cd $WD/single_frame_query/
rename 's/_001//' *.mrc

# Generate dummy coordinate and the star files for barcode array extraction
cd $WD
module load relion cuda
relion_star_loopheader rlnMicrographName >> images_original.star
cp images_original.star images_query.star

# Populate the star files
ls single_frame_original/*.mrc >> images_original.star
ls single_frame_query/*.mrc >> images_query.star

cd $WD
touch coord.star
echo "data_" >> coord.star
echo "loop_"  >> coord.star
echo "_rlnCoordinateX #1" >> coord.star
echo "_rlnCoordinateY #2" >> coord.star
echo "1885.000000  1790.00000" >> coord.star

cd $WD/single_frame_original/
for i in *.mrc; do n=$(echo $i | sed -e 's/.mrc/_coord.star/'); cp $WD/coord.star ./$n; done
cd $WD/single_frame_query/
for i in *.mrc; do n=$(echo $i | sed -e 's/.mrc/_coord.star/'); cp $WD/coord.star ./$n; done

cd $WD
# Run relion_preprocess and output the barcodes for comparsion.
echo "Extracting the bar code from the original unaltered image"
#relion_preprocess --i images_original.star --coord_suffix _coord.star --coord_dir ./ --part_dir barcodes_original/ --part_star original.star --set_angpix 1 --extract --extract_size 100
mpirun --np 16 relion_preprocess_mpi --i $WD/images_original.star --coord_suffix _coord.star --coord_dir ./ --part_dir barcodes_original/ --part_star original.star --set_angpix 1 --extract --extract_size 100

echo "Extracting the bar code from the query image"
mpirun --np 16 relion_preprocess_mpi --i $WD/images_query.star --coord_suffix _coord.star --coord_dir ./ --part_dir barcodes_query/ --part_star query.star --set_angpix 1 --extract --extract_size 100

cd $WD
mv $WD/barcodes_original/single_frame_original/*.mrcs barcodes_original/
cd $WD/barcodes_original
rm -rf single_frame_original/
rename 's/.mrcs/.mrc/' *.mrcs

cd $WD
mv $WD/barcodes_query/single_frame_query/*.mrcs barcodes_query/
cd $WD/barcodes_query
rm -rf single_frame_query/
rename 's/.mrcs/.mrc/' *.mrcs

# Launch the match.py routine and generate list of image matchs.
echo "Now launch the matching routine. This can take ~10-15 minutes to check all combinations."
module purge;
cd $WD
python $WD/match_loop_lst_parallel.py $WD/barcodes_original/ $WD/barcodes_query/
