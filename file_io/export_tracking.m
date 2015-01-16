function export_tracking(mytracking, props, opts)
% EXPORT_TRACKING writes CSV files containing the results of the tracking.
%
%   EXPORT_TRACKING(MYTRACKING, OPTS) writes in CSV files the content of MYTRACKING,
%   utilizing the parameters from OPTS to convert the tracking values to um and s.
%
%   EXPORT_TRACKING(MYTRACKING, FNAME, OPTS) specifies the name of the CSV files to
%   write to. By default, the name contained in MYTRACKING.experiment is used.
%   If no folder is specified in FNAME, files are written in the 'export' folder.
%
%   EXPORT_TRACKING(..., LOW_DUPLICATES) when true, does not repeat the information from
%   the mother cell in the track of the daughter cell.
%
%   EXPORT_TRACKING(..., ALIGNING) defines how the cell tracks are align with one
%   another. Available alignments are 'time', 'start' and 'end'.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 06.07.2014

  % Input checking and default values
  if (nargin < 1)
    return;
  elseif (nargin < 2)
    props = get_struct('exporting');
    opts = get_struct('options');
  elseif (nargin < 3)
    if (isfield(props, 'file_name'))
      opts = get_struct('options');
    else
      opts = props;
      props = get_struct('exporting');
    end
  end

  % Assign the properties locally
  fname = props.file_name;
  low_duplicates = props.low_duplicates;
  cycles_only = props.full_cycles_only;
  aligning_type = props.data_aligning_type;
  include_noise = props.export_noise;
  folder = '';

  % Do we have a filename ?
  if (isempty(fname))
    fname = mytracking.experiment;
  end

  % Force to have low duplicates if we want full cycles
  low_duplicates = (low_duplicates || cycles_only);

  % Required for the proper conversion from frames to seconds
  dt = opts.time_interval;
  time_frac = (1/(24*60*60));
  time_format = 'dd:HH:MM:SS';

  % The factors for the conversion to um
  rescale_factor = [1 ([1 1 1] * opts.pixel_size) 1];

  % The list of columns to export
  colname = {'status', 'x_coord_um', 'y_coord_um', 'sigma_um', 'amplitude_int'};
  ncols = length(colname);

  % A hidden waitbar
  hwait = waitbar(0,'','Name','Cell Tracking', 'Visible', 'off');

  % Now we loop over all channels
  nchannels = length(mytracking.trackings);

  % Switch to segmentations instead, as there seems to be data in it
  if (nchannels==0 && length(mytracking.segmentations)>0)
    mytracking.trackings = mytracking.segmentations;
    nchannels = length(mytracking.trackings);
  end

  % Loop over all channels
  for i=1:nchannels

    % Now check how many frames there are
    nframes = length(mytracking.trackings(i).filtered);

    set(hwait, 'Visible', 'off');

    % Extract the results of the tracking in this channel
    paths = reconstruct_tracks(mytracking.trackings(i).filtered, low_duplicates);
    noises = gather_noises(mytracking.trackings(i).filtered);

    % If it's empty, switch to the detections
    if (isempty(paths))
      disp(['No filtered data to be exported in channel ' num2str(i) ', switching to the detections']);

      % Now check how many frames there are
      nframes = length(mytracking.trackings(i).detections);

      % Extract the results of the tracking in this channel
      paths = reconstruct_tracks(mytracking.trackings(i).detections, low_duplicates);
      noises = gather_noises(mytracking.trackings(i).detections);
    end

    % Still nothing, giving up
    if (isempty(paths))
      disp(['Nothing to be exported in channel ' num2str(i)]);
      continue;
    end

    % Update the status bar
    set(hwait, 'Visible', 'on');
    waitbar(0, hwait, ['Exporting tracking results...']);

    % Get the number of paths
    npaths = length(paths);

    % Build a full matrix for all paths
    full_mat = NaN(nframes, npaths, ncols);
    path_names = cell(1, npaths+1);
    time_stamp = cell(nframes, 1);

    % Create the proper time stamps
    for j=1:nframes
      tm = (j-1)*dt*time_frac;
      time_stamp{j} = datestr(tm, time_format);
    end
    path_names{1} = ['Time_' time_format];

    % Copy every path into the full matrix
    for j=1:length(paths)
      curr_path = paths{j}(end:-1:1,:);

      % The indexes to copy the path
      indxs = curr_path(:,end-1);

      % Copy the path
      switch aligning_type
        case 'time'
          full_mat(indxs,j,:) = bsxfun(@times, curr_path(:,1:ncols), ...
                                                   rescale_factor);
        case 'start'
          full_mat(indxs-min(indxs)+1,j,:) = bsxfun(@times, curr_path(:,1:ncols), ...
                                                   rescale_factor);
        case 'end'
          full_mat(end-(max(indxs)-indxs),j,:) = bsxfun(@times, curr_path(:,1:ncols), ...
                                                   rescale_factor);
        otherwise
          close(hwait);
          error('Tracking:BadAligning', ['Alignment type "' aligning_type '" does not exist']);
      end

      % Get a name for the current path
      path_names{j+1} = ['Track_' num2str(j)];

      % Update the progress bar
      waitbar((j+nchannels*(i-1))/(npaths*nchannels),hwait);
    end

    % In case we do not align them using their frame index, cut the useless portions of the matrix
    if (strncmp(aligning_type, 'start', 5) || strncmp(aligning_type, 'end', 3))

      % Get the sub-matrx
      goods = ~all(isnan(full_mat(:,:,1)),2);
      tmp_mat = full_mat(find(goods, 1, 'first'):find(goods, 1, 'last'),:,:);
      noises = noises(find(goods, 1, 'first'):find(goods, 1, 'last'),:);

      % Write the matrix
      folder = write_csv([fname num2str(i)], colname, path_names, time_stamp(1:size(tmp_mat,1)), tmp_mat, cycles_only, noises, include_noise);
    else
      % Write the matrix
      folder = write_csv([fname num2str(i)], colname, path_names, time_stamp, full_mat, cycles_only, noises, include_noise);
    end
  end

  % Close the waitbar
  close(hwait);

  return;
end

% Get all the noises together
function noises = gather_noises(detections)

  nframes = length(detections);
  noises = NaN(nframes, 4);

  for i = 1:nframes
    noises(i, :) = detections(i).noise;
  end

  return;
end

% This function writes a 3D matrix into single CSV files.
function folder = write_csv(fname, colnames, col_headers, row_headers, matrix, cycles_only, noises, include_noise)

  % Check if there is a folder name in the name itself
  [filepath, name, ext] = fileparts(fname);

  % Otherwise, put them into the export directory
  if (isempty(filepath))
    filepath = 'export';
  end

  % Create the directory
  if (~exist(filepath, 'dir'))
    mkdir(filepath);
  end

  % Build the full name
  fname = fullfile(filepath, name);

  keep_cols = ~cellfun('isempty', colnames);

  colnames = colnames(keep_cols);

  matrix = matrix(:,:,keep_cols);

  % The noise names if need be
  noise_names = {'background', 'standard_deviation', 'poisson', 'quadratic'};

  % Maybe filter out the non-cycles paths
  if (cycles_only)
    valids = (sum(matrix(:,:,1)==1, 1)==2);
    matrix = matrix(:,valids,:);
    col_headers = col_headers([true valids]);
  end

  % Get the dimensions of the matrix
  [nframes, npaths, ncols] = size(matrix);

  full_mat = NaN(nframes, npaths*ncols);
  full_headers = cell(1,npaths*ncols+1);
  full_cols = cell(1,npaths*ncols+1);

  % Loop over the columns
  full_headers(1,1) = col_headers(1);
  for i=1:ncols
    full_mat(:,i:ncols:end) = matrix(:,:,i);
    full_headers(1+i:ncols:end) = col_headers(2:end);
    full_cols(1+i:ncols:end) = colnames(i);
  end

  % Include the noise data in the output if need be
  if (include_noise)
    full_mat = [noises full_mat];
    full_headers = [full_headers(1) noise_names full_headers(2:end)];
    full_cols = [full_cols(1) repmat(1, 4, {'Noise'}) full_cols(2:end)];
  end

  % Open the specified CSV file
  curr_name = [fname '.csv'];
  fid = fopen(curr_name, 'wt');

  % If there is an error, maybe we don't have the absolute path
  if (fid<0)
    curr_name = fullfile(pwd, curr_name);
    fname = fullfile(pwd, fname);

    % And if it still does not work, then we skip this file
    fid = fopen(curr_name,'wt');
    if (fid<0)
      return;
    end
  end

  % Write the headers first
  fprintf(fid, '%s,', full_headers{:});
  fprintf(fid, '\n');
  fprintf(fid, '%s,', full_cols{:});
  fprintf(fid, '\n');

  % Then the rows of the matrix
  for j=1:nframes
    fprintf(fid, '%s,', row_headers{j});

    fprintf(fid, '%f,', full_mat(j,:));

    fprintf(fid, '\n');
  end

  % And close the file
  fclose(fid);

  % Get the actual folder
  [folder, name, ext] = fileparts(fname);

  return;
end
