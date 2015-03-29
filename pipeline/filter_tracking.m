function [spots, links] = filter_tracking(spots, links, min_path_length, max_zip_length, interpolate)
% FILTER_TRACKING corrects for potential confusions of the tracking algorithm by
% removing short tracks, fusing duplicated spots and interpolating missing detections.
%
%   [SPOTS, LINKS] = FILTER_TRACKING(SPOTS, LINKS) filters the SPOTS as well as the
%   LINKS connecting the SPOTS using the default values for each three operations
%   (see below).
%
%   [MYRECORDING] = FILTER_TRACKING(MYRECORDING) filters the segmentations of MYRECORDING.
%
%   [MYRECORDING] = FILTER_TRACKING(MYRECORDING, OPTS) uses OPTS to set up the default
%   values for each operation (see below).
%
%   [...] = FILTER_TRACKING(..., MIN_PATH_LENGTH) defines the minimal durations of a
%   track (in frames) for this track to be kept after filtering (default: 5).
%
%   [...] = FILTER_TRACKING(..., MIN_PATH_LENGTH, MAX_ZIP_LENGTH) defines in addition
%   the maximum number of frames to be "zipped" (default: 3). A track is defined as an
%   open "zipper" when a spot splits and these same tracks fuse back together. On short
%   time scales, this is characteristical of over-detections of the true signal.
%
%   [...] = FILTER_TRACKING(..., MIN_PATH_LENGTH, MAX_ZIP_LENGTH, INTERPOLATE) when
%   true, interpolates the position of missing detections (default: true). However,
%   the parameters of the corresponding interpolated spot are NOT interpolated. One
%   should reestimate them (see estimate_spots.m)
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 08.07.2014

  % Input checking
  if (nargin < 1)
    error('CAST:filter_tracking', 'Not enough parameters provided (min=1)');
  elseif (nargin < 2)
    links = {};
    min_path_length = 5;
    max_zip_length = 3;
    interpolate = true;
  elseif (nargin < 3)
    min_path_length = 5;
    max_zip_length = 3;
    interpolate = true;
  elseif (nargin < 4)
    max_zip_length = 3;
    interpolate = true;
  elseif (nargin < 5)
    interpolate = true;
  end

  % Handle the different inputs
  opts = [];
  if (isnumeric(links))

    if (islogical(min_path_length))
      interpolate = min_path_length;
    elseif (islogical(max_zip_length))
      interpolate = max_zip_length;
      max_zip_length = min_path_length;
    end

    min_path_length = links;
  elseif (isstruct(links))
    opts = links;
    min_path_length = opts.tracks_filtering.min_path_length;
    max_zip_length = opts.tracks_filtering.max_zip_length;
    interpolate = opts.tracks_filtering.interpolate;
  end

  % Convert spots and links to cell arrays if need be
  mystruct = [];
  if (isstruct(spots))
    mystruct = spots;

    nframes = length(mystruct);
    spots = cell(nframes, 1);
    links = cell(nframes, 1);

    for i=1:nframes
      if (~all(isnan(mystruct(i).carth(:))))
        spots{i} = [mystruct(i).carth mystruct(i).properties];
        links{i} = mystruct(i).cluster;
      end
    end
  end

  % Get size and the number of properties used by the spots
  nframes = length(spots);
  for i=1:nframes
    if (~isempty(spots{i}))
      nprops = size(spots{i},2)-2;
      %break;
    end

    % And add a flag for interpolated points
    curr_spots = spots{i};
    if (~isempty(curr_spots))
      spots{i} = [curr_spots zeros(size(curr_spots, 1), 1)];
    end
  end

  % Filter out the paths that are too short
  if (min_path_length > 0)

    % To do this, we need to measure the length of every single path, so we create
    % an index that will contain this length that has the same structure as spots
    path_length = cell(nframes, 1);

    % First we loop "forward" through the paths and count the number of spots in each path
    for i = 1:nframes

      % Get the current links
      curr_links = links{i};

      % We need as many lengths as there are spots
      path_length{i} = zeros(size(spots{i}, 1), 1);

      % For each link, we update the length of the corresponding next spot by adding to
      % the previous length the difference in frames (in case the link was over several of them).
      for j=1:size(curr_links, 1)
        path_length{i}(curr_links(j,1)) = path_length{curr_links(j,3)}(curr_links(j,2)) + i - curr_links(j,3);
      end
    end

    % Now we need to do two things: first propagate "backwards" the length of the path, such
    % that the first spots in each path get the total length of the path; second we need
    % to build an translation index that will allow us to remove safely some unwanted spots
    % (as their position index is used by the links to identify them)
    diff_indxs = cell(nframes, 1);

    % So we loop backward
    for i = nframes:-1:1
      curr_links = links{i};

      % Propagate the total length to the "previous" spots pointed at by the current links
      curr_length = path_length{i};
      if (~isempty(curr_links))
        for j = 1:size(curr_links, 1)
          path_length{curr_links(j,3)}(curr_links(j,2)) = curr_length(curr_links(j,1));
        end
      end

      % Identify the paths long enough
      long = (curr_length > min_path_length);
      good_indx = find(long);

      % If we got some paths to keep
      if any(good_indx)
        % Extract the corresponding links
        new_links = curr_links(ismember(curr_links(:,1), good_indx), :);

        % Re-map the links with the new indexes where the short tracks have been removed
        mapping = [1:length(long)].' - cumsum(~long);

        % Flag the deleted ones with NaN
        mapping(~long) = NaN;

        % Update the indexes in the new links
        new_links(:,1) = mapping(new_links(:,1));

        % Keep only the correct spots
        spots{i} = spots{i}(long, :);

        % And store the links and mapping
        links{i} = new_links;
        diff_indxs{i} = mapping;

      % If we do not have anything, empty structures will do !
      else
        spots{i} = NaN(0,nprops+2);
        links{i} = NaN(0,3);
        diff_indxs{i} = NaN(length(long), 1);
      end
    end

    % We still need to parse the structure one last time to update the
    % indexes "end" of each link (we updated the "start" before) as it may
    % have pointed to frames in which we had not updated the indexes yet
    for i = 1:nframes
      curr_links = links{i};

      % Simply pull out the mapping form the array
      for j = 1:size(curr_links, 1)
        curr_links(j, 2) = diff_indxs{curr_links(j,3)}(curr_links(j,2));
      end

      % And remove all NaNs
      links{i} = curr_links(all(isfinite(curr_links),2), :);
    end
  end

  % "Zip" the splitting-merging events
  if (max_zip_length > 0)

    % This is quite similar conceptually to the length part, except that
    % we need to build an index for the length of all possible paths upon
    % splitting/merging events and thus cannot keep the simple array we used
    % previously. Instead we have a lookup table that we will need to update
    % constantly, along with an array of indexes storing the actual paths
    index_map = NaN(0,4);
    index_full = cell(0,1);

    % Here we'll store the zips to close, as we'll first go through the whole
    % structure and close all of them afterwards
    zips = cell(0,1);

    % We loop "backwards" as the links are easier handled that way
    for i = nframes:-1:1

      % Get the current links
      curr_links = links{i};
      nlinks = size(curr_links, 1);

      % An index to determine which portions of index_full is updated
      new_refs = false(length(index_full), 1);

      % Run through all links
      for j = 1:nlinks
        link = curr_links(j,:);

        % Is there a splitting event (two links from the same spot) ?
        eqs = (curr_links(:,1) == link(1));
        does_split = any(eqs(j+1:end,1));

        % Is there a merging event (using the lookup, two links pointing 
        % at the same spot) ?
        refs = (index_map(:,3) == link(1,1) & index_map(:,4) == i);
        does_link = any(refs);

        % Handle the splitting first
        if (does_split)

          % Get the corresponding links
          splits = curr_links(eqs(:,1),:);
          % And store in addition the current frame index
          splits = [splits(:,1) i*ones(size(splits,1),1) splits(:,2:3)];

          % If, in addition, there is merging, it gets a bit more complicated
          % as we need to loop twice over each list
          if (does_link)

            % Get the links and loop over them
            indxs = find(refs);
            for k = 1:length(indxs)

              % Get the corresponding full path
              tmp_path = index_full{indxs(k)};

              % Create new full paths that include all the splitting
              for l = 1:size(splits, 1)
                index_full{end+1} = [tmp_path;[tmp_path(end,1:2) splits(l,3:4)]];
              end
            end

            % Now we need to get rid of the duplicated paths by storing which ones
            % were updated
            tmp_refs = false(length(index_full), 1);
            tmp_refs(1:length(refs)) = refs;
            tmp_refs(1:length(new_refs)) = (tmp_refs(1:length(new_refs)) | new_refs);
            new_refs = tmp_refs;

          % Otherwise, we simply create new "empty" paths that start with the splits
          else
            for k=1:size(splits, 1)
              index_full{end+1} = splits(k,:);
            end
          end

        % Maybe we have only merging
        elseif (does_link)

          % Get the corresponding indexes
          indxs = find(refs);

          % Update the end point of the given paths
          for k = 1:length(indxs)
            tmp_path = index_full{indxs(k)};
            index_full{indxs(k)} = [tmp_path;[tmp_path(end,1:2) link(1,2:3)]];
          end
        end
      end

      % Update the "updated" flags
      tmp_refs = false(length(index_full), 1);
      tmp_refs(1:length(new_refs)) = new_refs;

      % And keep only the new ones
      index_full = index_full(~tmp_refs);

      % Create the map dynamically using the full paths, stacking their last row together
      index_map = cellfun(@(x)(x(end,:)), index_full, 'UniformOutput', false);
      index_map = cat(1, NaN(0,4), index_map{:});

      % Remove all the paths that are not valid anymore (too long or ended)
      valid_maps = (index_map(:,2) <= i+max_zip_length & index_map(:,end) < i);
      index_map = index_map(valid_maps, :);
      index_full = index_full(valid_maps);

      % Check whether we got a valid "zip"
      [unique_map, indx1, indx2] = unique(index_map, 'rows');
      if (numel(unique_map) ~= numel(index_map))

        % Find the actual zipping paths, and store them
        for k = 1:length(indx1)
          if (sum(indx2 == k) > 1)
            zips{end+1} = [index_full(indx2==k)];
          end
        end

        % Update the path list accordingly
        index_map = unique_map;
        index_full = index_full(indx1);
      end
    end

    % We will need these variables to replace the spots inside the zips
    % as we cannot work directly on the spots/links structure as some zips
    % could be interconnected
    tmp_props = NaN(1, nprops);
    del_spots = cell(nframes, 1);

    % Now we loop over the zips
    for i = 1:length(zips)

      % Get the current group of paths to zip together
      paths = zips{i};
      npaths = length(paths);

      % Their start/end/length properties
      max_frame = paths{1}(1,2);
      min_frame =  paths{1}(end, 4);
      frame_range = max_frame - min_frame + 1;

      % The matrix of all paths together
      all_pos = NaN([frame_range, 3, npaths]);

      % Loop over paths
      for j = 1:npaths
        curr_path = paths{j};

        % Get the corresponding first X-Y-T positions, which has to be the same for all of them
        all_pos(1,:,j) = [spots{curr_path(1,2)}(curr_path(1,1), 1:2) curr_path(1,2)];

        % And get all the intermediate positions afterwards
        for k = 1:size(curr_path,1)
          all_pos(max_frame - curr_path(k,end)+1,:,j) = [spots{curr_path(k,4)}(curr_path(k,3), 1:2) curr_path(k, 4)];

          % Store the index of the spots that will be removed
          if (curr_path(k,4) > min_frame)
            del_spots{curr_path(k,4)}(end+1) = curr_path(k,3);
          end
        end

        % Maybe we are missing some data (gaps)
        nans = isnan(all_pos(:,:,j));

        % If so, we'll interpolate as this will simplify our zipping procedure
        if (any(nans(:)))
          valids = ~any(nans, 2);
          frames = [max_frame:-1:min_frame].';
          all_pos(:,1:2,j) = interp1(all_pos(valids,3,j), all_pos(valids,1:2,j), frames);
          all_pos(:,3,j) = frames;
        end
      end

      % Get the average zipped path
      avg_pos = mean(all_pos, 3);
      prev_indx = curr_path(1,1);

      % And add the new averaged spots to the whole list, linking them at the same time
      for j = 2:frame_range-1
        curr_frame = avg_pos(j, 3);
        spots{curr_frame}(end+1,:) = [avg_pos(j,1:2) tmp_props];
        new_indx = size(spots{curr_frame}, 1);

        links{curr_frame+1}(end+1,:) = [prev_indx new_indx curr_frame];
        prev_indx = new_indx;
      end
      links{min_frame+1}(end+1,:) = [prev_indx curr_path(end,3:4)];
    end

    % Now it's basically the same as for the length part as we have identified
    % the spots to remove (in del_spots) and we want to get rid of them. So we again
    % need to store the mapping to the new indexes
    diff_indxs = cell(nframes, 1);

    % Loop backward
    for i = nframes:-1:1

      % Identify the spots to remove
      curr_spots = [1:size(spots{i},1)].';
      rem_spots = ismember(curr_spots, del_spots{i});

      % Re-map the links with the new indexes where the short tracks have been removed
      mapping = curr_spots - cumsum(rem_spots);
      mapping(rem_spots) = NaN;

      % Keep only the correct spots
      spots{i} = spots{i}(~rem_spots, :);
      diff_indxs{i} = mapping;
    end

    % Now fix the indexes of the links
    for i = 1:nframes

      % Get the current links
      curr_links = links{i};

      % Handle them individually
      for j = 1:size(curr_links, 1)

        % Simply use the stored mapping to update them
        curr_links(j, 1) = diff_indxs{i}(curr_links(j,1));
        curr_links(j, 2) = diff_indxs{curr_links(j,3)}(curr_links(j,2));
      end

      % And remove all NaNs
      links{i} = curr_links(all(isfinite(curr_links),2), :);
    end
  end

  % Interpolate the missing positions for the spots, if need be
  if (interpolate)

    % Go through the entire recording
    for i = nframes:-1:1

      % Get the current links
      curr_links = links{i};

      % And the subset that points to the "next" frame
      good_links = (curr_links(:,end)==i-1);
      links{i} = curr_links(good_links,:);

      % Do we have any gap to fill ?
      curr_links = curr_links(~good_links,:);
      if (~isempty(curr_links))

        % Loop over the gaps
        for j=1:size(curr_links, 1)

          % Get the current one, its start and end positions
          curr_indxs = curr_links(j,:);
          target = spots{i}(curr_indxs(1),:);
          reference = spots{curr_indxs(3)}(curr_indxs(2),:);

          % Manually interpolate linearly over the gap
          ninterp = i - curr_indxs(3);
          new_pts = bsxfun(@plus, bsxfun(@times, (reference - target) / ninterp, [1:ninterp-1].'), target);

          % Store these new points and their corresponding links in the usual structure
          curr_pos = curr_indxs(1);
          for k = 1:ninterp-1

            % The new indexes corresponding to the spot
            curr_indx = i-k;
            nprev = size(spots{curr_indx}, 1) + 1;

            % Flag these interpolated spots using a NaN at the end of their properties
            spots{curr_indx} = [spots{curr_indx}; [new_pts(k,1:end-1) true]];
            links{curr_indx+1} = [links{curr_indx+1}; [curr_pos nprev curr_indx]];
            curr_pos = nprev;
          end

          % Store the "first" link in addition
          links{curr_indx} = [links{curr_indx}; [curr_pos, curr_indxs(2), curr_indx-1]];
        end
      end
    end
  end

  % Fill back the data to the original structure, if a structure was originally provided
  if (~isempty(mystruct))
    for i=1:nframes
      mystruct(i).carth = spots{i}(:,1:2);
      mystruct(i).properties = spots{i}(:,3:end);
      mystruct(i).cluster = links{i};
    end

    spots = mystruct;
    links = [];
  end

  return;
end
