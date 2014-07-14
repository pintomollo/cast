function export_tracking(mytracking, fname, opts)
% EXPORT_TRACKING writes CSV files containing the results of the tracking.
%
%   EXPORT_TRACKING(MYTRACKING, OPTS) writes in CSV files the content of MYTRACKING,
%   utilizing the parameters from OPTS to convert the tracking values to um and s.
%
%   EXPORT_TRACKING(MYTRACKING, FNAME, OPTS) specifies the name of the CSV files to
%   write to. By default, the name contained in MYTRACKING.experiment is used.
%   If no folder is specified in FNAME, files are written in the 'export' folder.
%
% Gonczy and Naef labs, EPFL
% Simon Blanchoud
% 06.07.2014

  % Input checking and default values
  if (nargin == 1)
    fname = mytracking.experiment;
    opts = get_struct('options');
  elseif (nargin == 2)
    if (isstruct(fname))
      opts = fname;
      fname = mytracking.experiment;
    else
      opts = get_struct('options');
    end
  elseif (isstruct(fname))
    tmp = fname;
    fname = opts;
    opts = tmp;
  end

  % Required for the proper conversion from frames to seconds
  dt = opts.time_interval;
  time_frac = (1/(24*60*60));
  time_format = 'dd:HH:MM:SS';

  % The factors for the conversion to um
  rescale_factor = [1 ([1 1 1] * opts.pixel_size) 1];

  % The list of columns to export
  colname = {'status', '', '', 'sigma_um', 'amplitude_int'};
  ncols = length(colname);

  % A hidden waitbar
  hwait = waitbar(0,'','Name','Cell Tracking', 'Visible', 'off');

  % Now we loop over all channels
  nchannels = length(mytracking.segmentations);
  for i=1:nchannels

    % Now check how many frames there are
    nframes = length(mytracking.segmentations(i).detections);

    set(hwait, 'Visible', 'off');

    % Extract the results of the tracking in this channel
    paths = reconstruct_tracks(mytracking.segmentations(i).detections);

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
      indx_min = min(curr_path(:,end));
      indx_max = max(curr_path(:,end));

      % Copy the path
      full_mat(indx_min:indx_max,j,:) = bsxfun(@times, curr_path(:,1:ncols), ...
                                               rescale_factor);

      % Get a name for the current path
      path_names{j+1} = ['Track_' num2str(j)];

      % Update the progress bar
      waitbar((j+nchannels*(i-1))/(npaths*nchannels),hwait);
    end

    % Write the matrix
    folder = write_csv([fname num2str(i)], colname, path_names, time_stamp, full_mat);
  end

  % And zip them together
  zip(fname, fullfile(folder, [fname '*.csv']));

  % Close the waitbar
  close(hwait);

  return;
end

% This function writes a 3D matrix into single CSV files.
function folder = write_csv(fname, colnames, col_headers, row_headers, matrix)

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
