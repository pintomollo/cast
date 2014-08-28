function mystruct = get_struct(type, nstruct)
% GET_STRUCT retrieve custom data structures.
%   This function is designed as a centralization for the different 
%   complex structures used throughout the program so that they can
%   be edited consistently.
%
%   MYSTRUCT = GET_STRUCT(TYPE, SIZE) returns a matrix of size SIZE 
%   of the custom data structure of type TYPE. SIZE can be multi-
%   dimensional.
%
%   MYSTRUCT = GET_STRUCT(TYPE) returns one structure (SIZE = 1).
%
% Gonczy and Naef labs, EPFL
% Simon Blanchoud
% 13.05.2014

  % Set the default size
  if (nargin == 1)
    nstruct = 1;
  end

  % Switch between all the different types
  switch type

    % Structure used to parse the original files (reused in mytracking)
    case 'channel'
      mystruct = struct('color', ones(1,3), ...     % Color of the channel (RGB)
                        'compression', 'none', ...  % Compression used for the temporary file
                        'cosmics', true, ...        % Remove the cosmic rays in the image (see imcosmics.m)
                        'detrend', false, ...       % Detrend the image (see imdetrend.m)
                        'file', '', ...             % Path to the original file
                        'fname', '', ...            % Name of the corresponding temporary file
                        'hot_pixels', true, ...     % Remove the hot pixels in the image (see imhotpixels.m)
                        'max', -Inf, ...            % Original maximum value used for rescaling
                        'min', Inf, ...             % Original minimum value used for rescaling
                        'metadata', '', ...         % Recordings metadata
                        'normalize', true, ...      % Normalize the whole stack
                        'type', 'dic');             % Type of channel

    % Structure to store detections from segmentations
    case 'detection'
      mystruct = struct('carth', NaN(1, 2), ...     % Cartesian position of the detections (Nx2)
                        'cluster', [], ...          % Temporal cluster containing the detection paths
                        'properties', []);          % Other properties computed on each detection, depending on the algorithm

    case 'exporting'
      mystruct = struct('file_name', '', ...        % The name of the file to create
                        'low_duplicates', true, ... % Do we use low duplicates paths ?
                        'aligning_type', 'time');   % How do we align the paths ?

    % The few parameters required to filter the image appropriately
    case 'image_filters'
      mystruct = struct('hot_pixels_threshold', 15, ...     % see imhotpixels.m
                        'cosmic_rays_threshold', 15, ...    % see imcosmics.m
                        'cosmic_rays_window_size', 10, ...  % see imcosmics.m
                        'detrend_meshpoints', 32);          % see imdetrend.m

    % Structure containing the different parameters required for tracking spots
    case 'image_segmentation'
      mystruct = struct('filter_max_size', 10, ...          % max radius (in um), see filter_spots.m
                        'filter_min_size', 4, ...        % min radius (in um), see filter_spots.m
                        'filter_min_intensity', 3, ...     % min intensity (x noise variance), see filter_spots.m
                        'filter_overlap', 0.75, ...        % see filter_spots.m
                        'detrend_meshpoints', 32, ...      % see imdetrend.m
                        'denoise_func', @gaussian_mex, ... % see imdenoise.m
                        'denoise_size', -1,          ...   % see imdenoise.m
                        'denoise_remove_bkg', true, ...    % see imdenoise.m
                        'atrous_max_size', 25, ...          % see imatrous.m
                        'atrous_thresh', 10, ...           % see imatrous.m
                        'estimate_thresh', 1, ...          % thresh x noise variance, see estimate_spots.m
                        'estimate_niter', 15, ...          % see estimate_spots.m
                        'estimate_stop', 1e-2, ...         % see estimate_spots.m
                        'estimate_weight', 0.1, ...        % see estimate_spots.m
                        'estimate_fit_position', false);   % see estimate_spots.m


    % Structure used to handle the metadata provided by the microscope
    case 'metadata'
      mystruct = struct('acquisition_time', [], ... % Time of frame acquisition
                        'channels', {{}}, ...       % List of acquired channels
                        'channel_index', [], ...    % Channel <-> frame
                        'exposure_time', [], ...    % Frame exposure time
                        'frame_index', [], ...      % Time point <-> frame
                        'plane_index', [], ...      % Plane <-> frame
                        'raw_data', '', ...         % Raw metadata string
                        'z_position', []);          % Z-position of the frame

    % Global structure of a recording and analysis
    case 'myrecording'
      mychannel = get_struct('channel', 0);
      mysegment = get_struct('segmentation', 0);
      mytracks = get_struct('tracking', 0);
      mystruct = struct('channels', mychannel, ...  % Channels of the recording
                        'segmentations', mysegment, ... % Segmentation data
                        'trackings', mytracks, ...   % Tracking data
                        'experiment', '');          % Name of the experiment

    % Global structure of options/parameters for an analysis
    case 'options'
      myfilt = get_struct('image_filters');
      mysegm = get_struct('image_segmentation');
      mytrac = get_struct('spot_tracking');
      mytrkf = get_struct('tracks_filtering');
      mystruct = struct('config_files', {{}}, ...   % The various configuration files loaded
                        'binning', 1, ...           % Pixel binning used during acquisition
                        'ccd_pixel_size', 16, ... % X-Y size of the pixels in µm (of the CCD camera, without magnification)
                        'magnification', 20, ...    % Magnification of the objective of the microscope
                        'spot_tracking', mytrac, ...% Parameters for tracking the spots
                        'filtering', myfilt, ...    % Parameters for filtering the recordings
                        'tracks_filtering', mytrkf, ... % Parameters for filtering the tracks
                        'pixel_size', -1, ...       % X-Y size of the pixels in um (computed as ccd_pixel_size / magnification)
                        'segmenting', mysegm, ...   % Parameters for segmenting the recordings
                        'time_interval', 300, ...   % Time interval between frames (in seconds)
                        'verbosity', 2);            % Verbosity level of the analysis

    % Structure used to segment a channel
    case 'segmentation'
      mydetection = get_struct('detection',0);
      mystruct = struct('denoise', true, ...        % Denoise the segmentation (see imdenoise) ?
                        'detrend', false, ...       % Detrend the segmentation (see imdetrend.m)
                        'filter_spots', true, ...   % Filter the spots (see filter_spots.m)
                        'detections', mydetection, ... % the structure to store the resulting detections
                        'type', {{}});                 % the type of segmentation

    % Structure containing the different parameters required for tracking spots
    case 'spot_tracking'
      mystruct = struct('spot_max_speed', 0.5, ...    % Maximal speed of displacement of a spot (in um/s)
                        'allow_branching_gap', false, ...     % see track_spots.m
                        'bridging_max_gap', 3, ...            % Considered number of frames for the gap closing algorithm (see track_spots.m)
                        'max_intensity_ratio', Inf, ...       % see track_spots.m
                        'bridging_function', @bridging_cost_sparse_mex, ... % Function used to measure the gap-closing weight
                        'joining_function', @joining_cost_sparse_mex, ... % Same but for the joinging weight
                        'splitting_function', @splitting_cost_sparse_mex, ... % For the splitting weight
                        'linking_function', @linking_cost_sparse_mex); ... % And for the frame-to-frame linking 

    case 'tracking'
      mydetection = get_struct('detection',0);
      mystruct = struct('reestimate_spots', true, ...   % Do we reestimate the newly interpolated spots ?
                        'force_cell_behavior', true, ... % Prevent fusion and appearance of spots
                        'post_processing_funcs', {{}}, ... % Allow to post-process paths
                        'detections', mydetection); % the structure to store the resulting detections

    case 'tracks_filtering'
      mystruct = struct('interpolate', true, ...        % see filter_tracking.m
                        'max_zip_length', 3, ...        % see filter_tracking.m
                        'min_path_length', 10);         % see filter_tracking.m

    % If the required type of structure has not been implemented, return an empty one
    otherwise
      mystruct = struct();
  end

  % Compute the pixel size
  mystruct = set_pixel_size(mystruct);

  % Repeat the structure to fit the size (nstruct can be multi-dimensional)
  mystruct = repmat(mystruct, nstruct);

  return;
end
