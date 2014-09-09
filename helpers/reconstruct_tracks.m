function [paths, track_num] = reconstruct_tracks(spots, links, low_duplicates)
% RECONSTRUCT_TRACKS gathers single plane detections into individual tracks.
%
%   PATHS = RECONSTRUCT_TRACKS(SPOTS, LINKS) create a cell array PATHS which contains
%   in each cell the results of tracking for a single cell, using the detected SPOTS
%   and the tracking results LINKS. Upon merging or splitting of tracks, data are
%   duplicated. Consequently, portions of the different PATHS can be identical. PATHS
%   contains matrices organised per row as follows: [status, spot, frame_index] where
%   status is -1 (merging) 0 (track) 1 (splitting).
%
%   PATHS = RECONSTRUCT_TRACKS(MYTRACKING) extracts the paths from MYTRACKING. PATHS
%   then becomes a cell array of cell arrays (one for each channel).
%
%   PATHS = RECONSTRUCT_TRACKS(..., LOW_DUPLICATES) if true, does not duplicate the
%   entire history of a path at every division/fusion event but creates a new one
%   instead.
%
%   [PATHS, INDEXES] = RECONSTRUCT_TRACKS(...) returns in addition the INDEXES of the
%   first track each spot belongs to. INDEXES is a cell vector with as many cells as
%   there are time points.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 07.07.2014

  % Parse inputs and default values
  if (nargin < 2)
    links = {};
    low_duplicates = false;
  elseif (nargin < 3)
    low_duplicates = true;
  end

  % Maybe no link were given after all
  if (islogical(links))
    low_duplicates = links;
    links = {};
  end

  % We got a structure, so extract from there
  if (isstruct(spots))

    % Copy the structure
    mystruct = spots;

    % Maybe we got a full structure
    if (isfield(spots, 'experiment'))

      % Prepare the output
      paths = cell(length(mystruct.channels), 1);
      track_num = paths;

      % Loop over all channels and call itself recursively
      for i = 1:length(mystruct.channels)
        [paths{i}, track_num{i}] = reconstruct_tracks(mystruct.segmentations(i).detections, low_duplicates);
      end

      return;

    % Or it's only the detections part
    else
      % Get its length
      nframes = length(mystruct);

      % Prepare the required arrays
      spots = cell(nframes, 1);
      links = cell(nframes, 1);
      track_num = cell(nframes, 1);

      % Copy the data to the adecquate format
      for i = 1:nframes
        if (~all(isnan(mystruct(i).carth(:))))
          spots{i} = [mystruct(i).carth mystruct(i).properties];
          links{i} = mystruct(i).cluster;
          track_num{i} = NaN(size(mystruct(i).carth, 1), 1);
        end
      end
    end
  end

  % A nice visual waitbar
  hwait = waitbar(0,'','Name','Cell Tracking');
  waitbar(0, hwait, ['Reconstructing tracks...']);

  % The size of the problem
  nframes = length(spots);

  % Prepare the output
  paths = {};

  % The intermediate index map, used to identify which cell contains which path
  indxs = NaN(0,3);

  % We loop backwards, to follow the links
  for i=nframes:-1:1

    % Get the current spots and links
    curr_spots = spots{i};
    curr_link = links{i};

    % Now loop over each spot
    nspots = size(curr_spots, 1);
    for j = 1:nspots

      % Create a copy of the index table
      curr_indxs = indxs;

      % Check whether we link toward some other spot
      if (isempty(curr_link))
        link = [];
      else
        link = curr_link(curr_link(:,1)==j, 2:end);
      end

      % Let's count the number of outer links
      nlinks = size(link, 1);

      % In that case, we have a fusion on the current spot
      status = -(nlinks > 1);

      % Check whether any path point towards the current spot
      indx = find(curr_indxs(:,1)==j & curr_indxs(:,2)==i);

      % In that case, maybe we have a division
      if (~isempty(indx))

        % Divisions are flagged lower in the code
        division = any(curr_indxs(indx,3));

        % Update the status
        if (division)
          status = division;
        end

        % Copy our data to all paths pointing on us
        for k = 1:length(indx)
          paths{indx(k)} = [paths{indx(k)}; [status curr_spots(j,:) i j]];
        end

        % If there is a division, we need to stop the two incoming paths
        if (low_duplicates & division)
          indxs(indx, 2) = -1;
          indxs(indx, 2) = 0;

          % And create a new fresh one
          paths{end+1} = [status curr_spots(j,:) i j];

          % Get a new index
          indx = length(paths);
        end

      % Otherwise, create a new path
      else
        paths{end+1} = [status curr_spots(j,:) i j];

        % Get a new index
        indx = length(paths);
      end

      % Store the index of the corresponding path
      track_num{i}(j) = indx(1);

      % Finally, update the index table for every path pointing on us
      for l = 1:length(indx)

        % Without a link, we are a starting point
        if (nlinks == 0)
          indxs(indx(l),:) = [j -1 0];

        % Otherwise, maybe a division or nothing special
        else

          % If another path points towards the same spot than us, it must be a
          % division, so flag it !
          found = any(curr_indxs(:,1)==link(1) & curr_indxs(:,2)==link(2));
          indxs(indx(l),:) = [link(1,:) found];

          % Maybe there is a splitting event occuring
          if (low_duplicates & (status < 0))

            % Then we copy only the last position, for continuity
            for k = 1:nlinks
              paths{end+1} = paths{indx(l)}(end, :);
              indxs(end+1,:) = [link(k,:) found];
            end

            % And stop the incoming track
            indxs(indx(l), 2) = -1;
            indxs(indx(l), 2) = 0;

          else
            % In case we have a fusion, we duplicate the history to create two
            % independent tracks
            for k = 2:nlinks
              paths{end+1} = paths{indx(l)};
              indxs(end+1,:) = [link(k,:) found];
            end
          end
        end
      end
    end

    % Update the progress bar
    waitbar((nframes-i+1)/nframes,hwait);
  end

  % And close it
  close(hwait);

  return;
end
