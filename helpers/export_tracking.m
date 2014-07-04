function export_tracking(mytracking, fname, opts)

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

  dt = opts.time_interval;
  time_frac = (1/(24*60*60));

  colname = {'Status', 'X_coord_um', 'Y_coord_um', 'sigma_um', 'amplitude_int'};
  rescale_factor = [1 ([1 1 1] * opts.pixel_size) 1];
  ncols = length(colname);
  time_format = 'dd:HH:MM:SS';

  hwait = waitbar(0,'','Name','Cell Tracking', 'Visible', 'off');

  nchannels = length(mytracking.segmentations);
  for i=1:nchannels

    nframes = length(mytracking.segmentations(i).detections);

    set(hwait, 'Visible', 'off');

    paths = reconstruct_tracks(mytracking.segmentations(i).detections);

    set(hwait, 'Visible', 'on');
    waitbar(0, hwait, ['Exporting tracking results...']);

    npaths = length(paths);

    full_mat = NaN(nframes, npaths, ncols);
    path_names = cell(1, npaths+1);
    time_stamp = cell(nframes, 1);

    for j=1:nframes
      tm = (j-1)*dt*time_frac;
      time_stamp{j} = datestr(tm, time_format);
    end
    path_names{1} = ['Time_' time_format];

    for j=1:length(paths)
      curr_path = paths{j}(end:-1:1,:);

      indx_min = min(curr_path(:,end));
      indx_max = max(curr_path(:,end));

      full_mat(indx_min:indx_max,j,:) = bsxfun(@times, curr_path(:,1:ncols), rescale_factor);
      path_names{j+1} = ['Track_' num2str(j)];

%      for k=1:length(colname)
%        curr_name = [fname num2str(i) '_' colname{k} '.csv'];

%        dlmwrite(curr_name, curr_path(:,k), '-append', 'roffset', indx_min-1, 'coffset', j-1);
        %xlswrite(curr_name, curr_path(:,k), k, xls_range);
%      end

      waitbar((j+nchannels*(i-1))/(npaths*nchannels),hwait);
    end

    all_files = write_csv([fname num2str(i)], colname, path_names, time_stamp, full_mat);

    %for k=1:ncols
    %  curr_name = [fname num2str(i) '_' colname{k} '.csv'];

    %  dlmwrite(curr_name, path_names);
    %  dlmwrite(curr_name, full_mat(:,:,k), '-append');
      %xlswrite(curr_name, curr_path(:,k), k, xls_range);
    %end
  end

  zip(fname, [fname '*.csv']);

  close(hwait);

  return;
end

function fname = write_csv(fname, colnames, col_headers, row_headers, matrix)

  [filepath, name, ext] = fileparts(fname);

  if (isempty(filepath))
    filepath = 'export';
  end

  if (~exist(filepath, 'dir'))
    mkdir(filepath);
  end

  fname = fullfile(filepath, name);
  files = cell(ncols, 1);

  [nframes, npaths, ncols] = size(matrix);
  for i=1:ncols
    curr_name = [fname '_' colnames{i} '.csv'];
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

    for j=1:length(col_headers)
      fprintf(fid, '%s,', col_headers{j});
    end
    fprintf(fid, '\n');

    for j=1:nframes
      fprintf(fid, '%s,', row_headers{j});

      fprintf(fid, '%f,', matrix(j,:,i));

      fprintf(fid, '\n');
    end

    fclose(fid);
  end

  return;
end
