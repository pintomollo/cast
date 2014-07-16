function links = track_spots(spots, funcs, max_move, max_gap, max_ratio, allow_branching_gap, verbosity)
% TRACK_SPOTS tracks spots over time using a global optimization algorithm [1].
%
%   LINKS = TRACK_SPOTS(SPOTS, FUNCS) LINKS the sets of SPOTS using the provided
%   cost functions FUNCS. SPOTS should be a cell vector, each cell containing a matrix
%   of detected SPOTS at the corresponding time point. Each matrix should contain one
%   spot per row, the organisation of which depends on the expected format for the
%   cost functions FUNCS. The standard functions (see get_struct.m) expect:
%     [X_coord, Y_coord, sigma, amplitude, ..., row_index, frame_index]
%   FUNCS should be a cell array of 4 function handlers, in the following order:
%     {linking_function, bridging_function, joining_function, splitting_function}
%   Providing an empty cell for any of the three last functions disables this function
%   in the tracking algorithm [1].
%   LINKS will be a cell vector with the same size as SPOTS, each cell containing a
%   matrix with one spot-to-spot link per row, connecting a "start" spot from a
%   previous frame, to an "end" spot in the current frame, as follow:
%     [end_spot_index, start_spot_index, start_spot_frame_index]
%
%   PLEASE NOTE that this algorithm works using sparse matrices and thus requires cost
%   matrices in which 0 is the highest cost and -Inf the lowest one. A simple
%   transformation to obtain such a matrix is to utilize -exp(-dist^2). For examples
%   of such cost functions, see linking_cost_sparse_mex.m, bridging_cost_sparse_mex.m,
%   joining_cost_sparse_mex, splitting_cost_sparse_mex.m.
%
%   LINKS = TRACK_SPOTS(SPOTS, FUNCS, MAX_MOVEMENT) defines in addition the maximum
%   number of pixels a spot can travel between two consecutive frames (default: Inf).
%
%   LINKS = TRACK_SPOTS(SPOTS, FUNCS, MAX_MOVEMENT, MAX_GAP_LENGTH) defines the maximum
%   number of frames a spot can be "lost" in a track, while the track gaps over them
%   (default: 5).
%
%   LINKS = TRACK_SPOTS(SPOTS, FUNCS, MAX_MOVEMENT, MAX_GAP_LENGTH, MAX_RATIO) defines
%   an upper bound to the allowed signal ratios as defined in [1] (default: Inf).
%
%   LINKS = TRACK_SPOTS(SPOTS, FUNCS, MAX_MOVEMENT, MAX_GAP_LENGTH, MAX_RATIO, ...
%   ALLOW_BRANCHING_GAP) defines if merging and splitting can occur over MAX_GAP_LENGTH
%   (default: false).
%
%   LINKS = TRACK_SPOTS(..., VERBOSITY) when VERBOSITY > 1, displays a progress bar.
%
%   LINKS = TRACK_SPOTS(SPOTS, OPTS) extracts the corresponding parameter values from
%   OPTS.spot_tracking (see get_struct.m), utilizing OPTS.pixel_size and OPTS.time_interval
%   to compute the per pixel / per frame values. OPTS should have the structure
%   provided by get_struct('options').
%
%   LINKS = TRACK_SPOTS(MYTRACKING, ...) tracks the spots segmented in MYTRACKING.
%
% References:
%   [1] Jaqaman K, Loerke D, Mettlen M, Kuwata H, Grinstein S, et al. Robust
%       single-particle tracking in live-cell time-lapse sequences. Nat Methods 5: 
%       695-702 (2008).
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 04.07.2014

  % Input checking and default values
  if (nargin < 2)
    error('Tracking:track_spots', 'Not enough parameters provided (min=2)');
  elseif (nargin < 3)
    max_move = Inf;
    max_gap = 5;
    max_ratio = Inf;
    allow_branching_gap = false;
    verbosity = 2;
  elseif (nargin < 4)
    max_gap = 5;
    max_ratio = Inf;
    allow_branching_gap = false;
    verbosity = 2;
  elseif (nargin < 5)
    max_ratio = Inf;
    allow_branching_gap = false;
    verbosity = 2;
  elseif (nargin < 6)
    allow_branching_gap = false;
    verbosity = 2;
  elseif (nargin < 7)
    verbosity = 2;
  end

  % Check whether we got the options structure
  if (isstruct(funcs))
    opts = funcs;

    % Get the function handlers
    funcs = {opts.spot_tracking.linking_function, ...
             opts.spot_tracking.bridging_function, ...
             opts.spot_tracking.joining_function, ...
             opts.spot_tracking.splitting_function};

    % And call itself with the proper values
    links = track_spots(spots, funcs, ...
            opts.time_interval*opts.spot_tracking.spot_max_speed/opts.pixel_size, ...
            opts.spot_tracking.bridging_max_gap, ...
            opts.spot_tracking.max_intensity_ratio, ...
            opts.spot_tracking.allow_branching_gap, opts.verbosity);
    return;
  end

  % For conveniance, always work with cell vector
  if (~iscell(funcs))
    funcs = {funcs};
  end

  % Create empty function handlers in case not enough where provided
  weighting_funcs = cell(4, 1);
  weighting_funcs(1:min(length(funcs), end)) = funcs(1:min(4, end));

  % Create a structure to store the one which might be provided
  mystruct = [];
  if (isstruct(spots))

    % We can either get a full experiment, or the detections sub-structure
    if (isfield(spots, 'experiment'))

      % Store the structure
      mystruct = spots;

      % Loop over all channels and call itself recursively
      for i = 1:length(mystruct.channels)
        mystruct.segmentations(i).detections = track_spots( ...
                    mystruct.segmentations(i).detections, funcs, max_move, max_gap, ...
                    max_ratio, allow_branching_gap, verbosity);
      end

      % Save the result and exit
      links = mystruct;

      return;

    % Here we got a detection structure (at least we assume so)
    else

      % Store the structure
      mystruct = spots;

      % Get the number of frames, initialize the spot cell vector
      nframes = length(mystruct);
      spots = cell(nframes, 1);

      % Build the proper matrices
      for i = 1:nframes
        if (~all(isnan(mystruct(i).carth(:))))
          spots{i} = [mystruct(i).carth mystruct(i).properties];
        end
      end
    end
  end

  % Get the number of frames from the spots array
  nframes = length(spots);

  % Initialize the output variable
  links = cell(nframes, 1);

  % Make sure we at elast got this handler !
  frame_linking_weight = weighting_funcs{1};
  if (isempty(frame_linking_weight))
    error('Tracking:track_spots', 'No valid frame to frame weighting function provided');
  end

  % A nice status-bar if possible
  do_display = (verbosity > 1 && nframes > 2);
  if (do_display)
    hwait = waitbar(0,'','Name','Cell Tracking');

    % Update the waitbar
    waitbar(0, hwait, ['Linking spots between consecutive frames...']);
  end

  % Initialize some variables for the frame to frame to operate properly, at frame 1
  % there is nothing before that so both are empty for now on
  pts = [];
  npts = 0;

  % We store all assignments as we need them later to compute the average distance
  all_assign = [];

  % Loop over all frames forward
  for i = 1:nframes

    % Store the previous data
    prev_pts = pts;
    prev_npts = npts;

    % And load the current data
    pts = spots{i};
    npts = size(pts, 1);

    % If one of the two is empty, no linking will happen
    if (prev_npts > 0 && npts > 0)

      % Get the spot-to-spot cost matrix for linking them
      mutual_dist = frame_linking_weight(prev_pts, pts, max_move, max_ratio);

      % Get the data from the resulting sparse matrix
      [indxi, indxj, vals] = get_sparse_data_mex(mutual_dist);

      % Use some default values if no linkin is possible
      if (isempty(vals))
        curr_max = -0.1;
        min_dist = -1;
      else
        curr_max = max(vals);
        min_dist = min(vals);
      end

      % Build the data requried for the no-linking parts of the matrix [1]
      ends_indx = [1:max(npts,prev_npts)].';
      ends = ones(size(ends_indx))*curr_max;

      % No build the full indexes for the final sparse matrix
      indxii = [indxi; ...                         % Linking
                ends_indx(1:prev_npts); ...        % End of a track
                ends_indx(1:npts)+prev_npts; ...   % Start of a track
                indxj+prev_npts];                  % Requried for symmetry

      % Same for the other matrix indexes
      indxj = [indxj; ends_indx(1:prev_npts)+npts; ends_indx(1:npts); indxi+npts];

      % And the corresponding values
      vals = [vals; ends(1:prev_npts); ends(1:npts); ones(size(vals))*min_dist];

      % Now build the full sparse matrix using only the requried number of values
      dist = sparse(indxii, indxj, vals, npts + prev_npts, npts + prev_npts, ...
                    length(vals));

      % And solve this using this alternative implementation of the Hungarian algorithm
      [assign, cost] = lapjv_fast_sparse(dist);

      % Keep only the relevant part of the assignments (others are required for symmetry)
      assign = assign(1:prev_npts);

      % And keep only the ones representing a link
      indxs = 1:length(assign);
      good_indx = (assign <= npts);
      assign = assign(good_indx);
      indxs = indxs(good_indx);

      % Extract the corresponding costs for later use
      assign_dist = dist(sub2ind(size(dist),indxs,assign));
      all_assign = [all_assign; assign_dist(:)];

      % Invert the assignment indexes as we store next -> prev links
      [assign, perms] = sort(assign(:));

      % And store everything
      links{i} = [assign indxs(perms).' (i-ones(length(assign), 1))];
    end

    % Still store something to avoid errors later when accessing columns
    if (isempty(links{i}))
      links{i} = NaN(0, 3);
    end

    % Update the progress bar
    if (do_display)
      waitbar(i/nframes,hwait);
    end
  end

  % Convert the costs back to distances
  dists = (sqrt(-log(-all_assign)));

  % And get the overall average distance
  avg_movement = mean(dists(isfinite(dists)));

  % Get the size of spot matrices to initialize properly the lists for the branching
  ndim = -1;
  for i=1:nframes
    if (~isempty(spots{i}))
      ndim = size(spots{i},2);
      break;
    end
  end

  % No data at all...
  if (ndim < 2)
    if (~isempty(mystruct))
      links = mystruct;
    end

    if (do_display)
      close(hwait);
    end

    return;
  end

  % We need to build several lists for bridging/merging/splitting
  starts = zeros(0, ndim+2);
  ends = zeros(0, ndim+2);
  interm = zeros(0, ndim+2);
  tmp_interm = zeros(0, ndim+2);

  % Because the gap links two frames ...
  branching_gap = max_gap*allow_branching_gap + 1;
  max_gap = max_gap + 1;

  % Get the corresponding cost functions
  closing_weight = weighting_funcs{2};
  joining_weight = weighting_funcs{3};
  splitting_weight = weighting_funcs{4};

  % And check if we need to skip some functionalities
  tracking_options = ~[(isempty(closing_weight) || max_gap==1), ...
                       isempty(joining_weight), ...
                       isempty(splitting_weight)] & (nframes > 2);

  % Decide whether we need to build a list of intermediate spots
  get_interm = any(tracking_options(2:3));

  % Maybe skip the whole assignment part
  if (any(tracking_options))

    % Update the waitbar
    if (do_display)
      waitbar(0, hwait, ['Building a list of tracks for bridging/splitting/merging...']);
    end

    % All the tracks need to end in the last frame
    prev_ends = [1:size(spots{end}, 1)];

    % Loop over all frames, backwards, to follow the previous links
    for i = nframes:-1:2

      % Get the current links
      curr_links = links{i};

      % Intermediate spots cannot be end spots
      indx_interm = setdiff(curr_links(:,1), prev_ends);

      % Start spots do not connect to any previous spot
      nstarts = size(spots{i},1);
      indx_starts = setdiff([1:nstarts], curr_links(:,1));
      nstarts = length(indx_starts);

      % If we have some starting spots, store them, including their indexes
      if (nstarts>0)
        starts(end+1:end+nstarts,:) = [spots{i}(indx_starts,:) indx_starts(:) ...
                                                               ones(nstarts,1)*i];
      end

      % End points are spots in the previous frame, not linked to any spot
      nends = size(spots{i-1},1);
      indx_ends = setdiff([1:nends], curr_links(:,2));
      nends = length(indx_ends);

      % Store them similarly
      if (nends>0)
        ends(end+1:end+nends,:) = [spots{i-1}(indx_ends,:) indx_ends(:) ...
                                                           ones(nends,1)*i-1];
      end

      % If we need to, check whether some of the intermediary spots could be
      % either merging points or splitting points
      if (get_interm)

        % Check if we have some in this frame
        ninterm = length(indx_interm);

        % We utilize an intermediary list so that we can compare to all intermediary
        % spots, including accross gaps if need be.
        if (ninterm>0)
          tmp_interm(end+1:end+ninterm,:) = [spots{i}(indx_interm,:) indx_interm(:) ...
                                                                  ones(ninterm,1)*i];
        end

        % Now we need to decide whether they could be interesting spots, to do so, we
        % call the corresponding cost function and verify wether they pass the
        % max_gap and max_movement thresholds.
        good_interm = false(1, size(tmp_interm, 1));

        % First for the merging part
        if (tracking_options(2))

          % Call the function to check whether they pass the various thresholds
          can_join = joining_weight(ends, tmp_interm, max_move, branching_gap);
          good_interm = good_interm | can_join;
        end

        % Then for the splitting
        if (tracking_options(3))

          % Again using the splitting function itself
          can_split = splitting_weight(starts, tmp_interm, max_move, branching_gap);
          good_interm = good_interm | can_split;
        end

        % Get the subset of potential candidates
        new_interm = tmp_interm(good_interm, :);
        ninterm = size(new_interm, 1);

        % Sotre them in the actual list of intermediary spots
        if (ninterm>0)
          interm(end+1:end+ninterm,:) = new_interm;
        end

        % Update our intermediary list, removing used spots and ones that are too
        % far away over time to gap with the next frame
        tmp_interm = tmp_interm(~good_interm, :);
        tmp_interm = tmp_interm(tmp_interm(:,end)<=i+branching_gap,:);
      end

      % Update the track ends
      prev_ends = indx_ends;

      % And the progress bar
      if (do_display)
        waitbar((nframes-i+1)/nframes,hwait);
      end
    end

    % Update the waitbar
    if (do_display)
      waitbar(0, hwait, ['Assigning bridging/splitting/merging of tracks... (please wait)']);
    end

    % Get the final number of spots
    nstarts = size(starts, 1);
    nends = size(ends, 1);
    ninterm = size(interm, 1);

    % Compute the bridging costs
    if (tracking_options(1))
      mutual_dist = closing_weight(ends, starts, max_move, max_gap, max_ratio);
    else
      mutual_dist = sparse(nends, nstarts);
    end

    if (do_display)
      waitbar(1/6,hwait);
    end

    % The merging costs, we also need an alternative costs vector [1]
    if (tracking_options(2))
      [merge_weight, alt_merge_weight] = joining_weight(ends, interm, max_move, branching_gap, max_ratio, avg_movement, spots, links);
    else
      merge_weight = sparse(nends, ninterm);
      alt_merge_weight = sparse(ninterm);
    end

    if (do_display)
      waitbar(2/6,hwait);
    end

    % And the splitting costs, including the alternative costs vector
    if (tracking_options(3))
      [split_weight, alt_split_weight] = splitting_weight(starts, interm, max_move, branching_gap, max_ratio, avg_movement, spots, links);
    else
      split_weight = sparse(ninterm, nstarts);
      alt_split_weight = sparse(ninterm);
    end

    if (do_display)
      waitbar(3/6,hwait);
    end

    % Now build the full matrix [1]
    % Note that end-end merging and start-start splitting is not allowed by this
    % algorithm, which makes sense...

    % Get the individual indexes and values from the different sparse matrices, and
    % concatenate them into one single list.

    % Bridging is the top left matrix
    [indxi, indxj, vals] = get_sparse_data_mex(mutual_dist);
    all_indxi = indxi;
    all_indxj = indxj;
    all_vals = vals;

    % Merging is shifted on the right, after the bridging one
    [indxi, indxj, vals] = get_sparse_data_mex(merge_weight);
    all_indxi = [all_indxi; indxi];
    all_indxj = [all_indxj; indxj+nstarts];
    all_vals = [all_vals; vals];

    % While splitting it under the bridging one
    [indxi, indxj, vals] = get_sparse_data_mex(split_weight);
    all_indxi = [all_indxi; indxj+nends];
    all_indxj = [all_indxj; indxi];
    all_vals = [all_vals; vals];

    if (do_display)
      waitbar(4/6,hwait);
    end

    % We need to extract the cost for no linking
    if (isempty(all_vals))
      alt_cost = -0.1;
      min_dist = -1;
    else
      alt_cost = prctile(all_vals, 90);
      min_dist = min(all_vals);
    end

    % Build a generic vector for these parts of the matrix
    alt_indx = [1:max(max(nends,nstarts),ninterm)].';
    alt_dist = ones(size(alt_indx))*alt_cost;

    % Now build the full array of indexes
    all_indxii = [all_indxi; ...           % Bridging/Merging/Splitting
                  alt_indx(1:nends); ...   % No gap, "d" in [1]
                  alt_indx(1:nstarts)+nends+ninterm; ... % No gap, "b" in [1]
                  alt_indx(1:ninterm)+nends; ... % No splitting, "d'" in [1]
                  alt_indx(1:ninterm)+nends+nstarts+ninterm; ... % No merging, "b'" [1]
                  all_indxj+nends+ninterm];  % The lower right block, for symmetry

    % Same for the second coordinate
    all_indxj = [all_indxj; alt_indx(1:nends)+nstarts+ninterm; alt_indx(1:nstarts); ...
                 alt_indx(1:ninterm)+nstarts+ninterm+nends; ...
                 alt_indx(1:ninterm)+nstarts; all_indxi+nstarts+ninterm];

    % And the corresponding values
    all_vals = [all_vals; alt_dist(1:nends); alt_dist(1:nstarts); alt_split_weight; ...
                alt_merge_weight; ones(size(all_vals))*min_dist];

    % Finally, build the whole sparse matrix
    dist = sparse(all_indxii, all_indxj, all_vals, nstarts + nends + 2*ninterm, ...
                  nstarts + nends + 2*ninterm, length(all_vals));

    if (do_display)
      waitbar(5/6,hwait);
    end

    % And solve it !
    [assign, cost] = lapjv_fast_sparse(dist);

    % Identify the type of assignment chosen
    for i=1:nends+ninterm

      % Bridging/Splitting
      if (assign(i) <= nstarts)
        target = starts(assign(i), :);

      % Merging
      elseif (assign(i) < nstarts + ninterm)
        target = interm(assign(i) - nstarts, :);
      else
        continue;
      end

      % Bridging
      if (i <= nends)
        reference = ends(i,:);

      % Splitting
      else
        reference = interm(i-nends,:);
      end

      % Update the link list accordingly
      links{target(end)} = [links{target(end)}; [target(end-1), reference(end-1:end)]];
    end
  end

  % Close the progress bar
  if (do_display)
    close(hwait);
  end

  % And store the corresponding information in the structure, if need be
  if (~isempty(mystruct))
    for i=1:nframes
      mystruct(i).cluster = links{i};
    end

    links = mystruct;
  end

  return
end
