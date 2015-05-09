% README.txt
% A few expanations on how to use CAST
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 20.11.2014
%
% contact: felix.naef@epfl.ch

Hi !

This set of functions (so-called CAST: Cell Automated Segmentation and Tracking platform)
are designed to provide an intuitive user interface for the automated segmentation, tracking
and quantification of time-lapse fluorescence/luminescence data. All functions can
be accessed directly using command-lines, however it is designed to be used through
the main interface function "CAST_GUI".

This program is distributed under the terms of the GNU GPL, please refer to
LICENSE.txt for details.

% Reference:

Blanchoud et al., Methods, 2015

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 0. Basics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - This software has been developped and tested using Matlab 2012b and requires
   both a C/C++ compiler and the Image Processing Toolbox (tested using v. 8.1).

 - For installing this plateform, please follow the instructions in INSTALL.txt.

 - All functions have a corresponding help message that describes its function,
   inputs and outputs. Type "help myfunction" in the command line to read it.

 - A list of all available functions along with a short description of their
   purpose is available in CONTENT.TXT

 - Data are stored within Matlab using structures. This should be completely
   transparent to the user. However, if need be, their respective definitions
   can be found in cast/helpers/get_struct.m.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1. Starting up an experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - Once the install has been successful, call "CAST_GUI" from Matlab.

 - On the opened window, one can either:
   - Load a previous experiment : Upper right button "Load"
   - Create a new experiment    : Upper right button "New Experiment"
   - Load new data              : Upper right button "Load Recording"

 - As an example, let's start by pressing "Load Recording" !

 - And choose the sample recording located in "cast/sample_signal.ome.tif".

 - Note that if the the data you are trying to load is not successfully converted
   by CAST, you should convert it manually to a TIFF stack. To do so, a simple approach
   is to use the LOCI library for ImageJ:
   http://www.openmicroscopy.org/site/support/bio-formats5/users/imagej/

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2. Preprocessing your data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - This step allows you to remove artefacts from your raw data and thus spare some
   computing time during the analysis/quantification step.

 - In this GUI, you can define the following properties of your recording:
   - Experiment Name  : Top text field (used also when saving/exporting data)
   - Channel Type     : Top right drop-down list
   - Colormap         : Middle right "Colormap" button (for visualization)

 - In addition, you can perform the following actions:
   - Add/Remove Channels            : Lower left buttons
   - Navigate through the recording : Lower slider
   - Drag/Zoom the images           : Leave the mouse on "Experiment Name" for a few
                                      seconds to read the corresponding help message

 - The various filters available are listed on the right of the image panels:
   - Detrend      : Removes a trend in the image (e.g. non-uniform illumination)
   - Cosmic rays  : Removes cosmic rays in luminescence data
   - Hot pixels   : Removes hot-pixels (i.e. defective) of the camera sensor
   - Normalize    : Normalizes the image range between 0 and 1

 - A simple way to identify artefacts is by using the "Difference" visualization
   on the right image panel. They will pop-up as white patches.

 - Check then that the filtering does remove these artefacts by comparing them with
   the "Difference" on the left panel, the white patches should be similar to those
   on the right panel.

 - Once you're happy with the current filtering, simply apply it y clicking "OK".

 - If you're following the example, then the type of data you just loaded should be
   changed to "luminescence", and the filtering applied on the sample data should be
   a bit too strong (i.e. more white on the left than on the right panels). So let's
   tune the parameters of the filters !

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2. Editing parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - In all GUIs, you can edit the parameter values by clicking on "Edit parameters"
   (Middle right button). Each GUI gives you access to the parameters specific to the
   corresponding step of the analysis, with an exception for the main GUI showing
   you the general option structure.

 - In addition, you can save/load the current option structure using the
   corresponding buttons (Lower right buttons). You can also manually edit these
   configuration files (located in "cast/Conf"). See example_params.txt
   for an explanation on the syntax of these files.

 - When editing parameters, a help message will pop-up if you leave the mouse cursor
   over the corresponding name for a few seconds.

 - To tune the filtering of the sample data, let's set "cosmic_rays_threshold" to 25.
   Then click "OK" twice (and be patient, that's gonna be only once !).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3. Editing global parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - Once the preprocessing of your data has been performed, the GUI for editing the
   global parameters of your reocrding will open. Because the CAST
   works with um and seconds units, it is important that both the XY and the time
   resolutions of the recording are properly set !
   - XY    : binning * ccd_pixel_size / magnification
   - time  : time_interval

 - You can edit these parameters afterwards by clicking "Edit parameters" from the
   main GUI window.

 - The default parameters are already correct for the sample data.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3. Segmenting your data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - Clicking "Segment Recording" on the main GUI will bring you to the segmentation
   window.

 - In this window, you can perform the following actions:
   - Select the segmentation algorithm (i.e. "Type")      : Top right drop-down list
   - Filter the images (i.e. for the detection step only) : Right checkboxes
   - Compare the resulting filtered and raw images        : Lower left radio buttons
   - Visualize the detections                             : Lower right radio buttons

 - If the type of channel has been selected as "luminescence", the "multiscale_gaussian_spots"
   segmentation type will automatically be selected, otherwise, select it manually.

 - Note that it is generally easier to track data that are over-segmented rather than
   under-segmented.

 - If you are segmenting the sample data, the detection algorithm should be a bit too
   sensitive (i.e. too many red circle). Let's tune the parameters a bit then !
   - Remove larger cells    : Reduce "filter_max_size" to 5
   - Remove empty detections: Increase "filter_min_intensity" to 25

 - Note that these parameters affect the filtering of the detections and NOT the
   actual detection algorithm. To tune the detection algorithm itself, you should
   first remove the filtering step (uncheck "Filter spots" on the right), and then
   play with the following parameters:
   - atrous_max_size  : Size of the detected spots
   - atrous_thresh    : Intensity of the detected spots

 - Confirm using "OK", and wait (a bit less now !).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 4. Tracking cells
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - Clicking "Track Cells" on the main GUI will bring you to the tracking window.

 - In this window, you can visualize the frame-to-frame cell tracking using the two 
   lower radio button groups. Note that it is not possible at this step to visualize
   the gap bridging/merging/splitting steps of the tracking algorithm.

 - The main parameters of the tracking algorithm to be tuned are:
   - spot_max_speed     : Maximal distance between two frames
   - min_section_length : Minimal length of a track for it to be kept
   - bridging_max_gap   : Maximal number of "missing" frames for a gap to bridge over

 - In addition, using an empty field for the "*_function" will remove the corresponding
   step of the tracking algorithm (if needed).

 - If using the sample data, the provided parameter values should be optimal. However,
   when analyzing longer recordings, increasing "min_section_length" should remove
   noisy spurious detections.

 - Confirm using "OK", and wait (almost instantaneous at this stage ;) !).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 5. Filtering tracks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 - Clicking "Filter Paths" on the main GUI will bring you to the filtering window.

 - In this window, you can perform the following actions:
   - Decide whether you want to reestimate the spots : Middle right checkbox
   - Filter short (hence usually wrong) tracks       : "Edit parameters"

 - Confirm using "OK", and some more wait !

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 6. Exporting results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  - You can export the results of your analysis (only when the pull pipeline has
    been run, i.e. after the track filtering) using the top-right button "Export".

  - The exported data will be stored in the "Export" folder.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 7. Adding new features
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  - If you want to add some features to this plateform, the code is fully commented
    and should be quite self-explanatory !

  - In particular, to add another segmenting approach, you should:
    - Add the new function(s) in "cast/modules".
    - Add the corresponding choice in "cast/pipeline/perform_step.m"
    - Add the new segmentation approach to the drop-down list of the segentation GUI
      ("cast/GUI/inspect_segmentation.m", l. 501):

  - Only make sure that the input/ouput variables type and formats stay the same !

  - You can also define new colormaps for your favorite data by modifying the 'colors'
    structure in "cast/helpers/get_struct.m".

  - Good luck and have fun segmenting !

Cheers,
Simon
